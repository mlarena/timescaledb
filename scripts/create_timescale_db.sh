#!/bin/bash
set -euo pipefail

# ==============================================================================
# Creates the TimescaleDB-enabled database "timescale_db", enables the
# timescaledb and pg_stat_statements extensions, applies the schema and
# installs the data generator function.
#
# Prerequisites: run install_postgres_and_extension.sh first (it installs
# PostgreSQL and TimescaleDB, and preloads both libraries).
# Requires root or sudo.
# ==============================================================================

DB_NAME="timescale_db"

# Colored output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

# Root check
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (sudo)."
fi

if ! command -v psql &> /dev/null; then
    error "psql not found. Run install_postgres_and_extension.sh first."
fi

# ------------------------------------------------------------------------------
# Create the database (idempotent)
# ------------------------------------------------------------------------------
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -q 1; then
    warn "Database '${DB_NAME}' already exists."
else
    log "Creating database '${DB_NAME}'..."
    sudo -u postgres createdb "${DB_NAME}"
fi

# ------------------------------------------------------------------------------
# Enable TimescaleDB
# ------------------------------------------------------------------------------
log "Enabling timescaledb in '${DB_NAME}'..."
sudo -u postgres psql -d "${DB_NAME}" -v ON_ERROR_STOP=1 \
    -c "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;"

# ------------------------------------------------------------------------------
# Enable pg_stat_statements
# ------------------------------------------------------------------------------
log "Enabling pg_stat_statements in '${DB_NAME}'..."
sudo -u postgres psql -d "${DB_NAME}" -v ON_ERROR_STOP=1 \
    -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

# ------------------------------------------------------------------------------
# Locate the bundled files.
# In the flat app.zip layout they sit next to this script; in the repository
# layout they live in timescale_db/ and data_generation/.
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

find_file() {
    local name="$1"; shift
    local candidate
    for candidate in "$@"; do
        if [[ -f "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

SCHEMA_FILE="$(find_file sensor_timescale_db.sql \
    "${SCRIPT_DIR}/sensor_timescale_db.sql" \
    "${SCRIPT_DIR}/../timescale_db/sensor_timescale_db.sql")" \
    || error "sensor_timescale_db.sql not found (looked next to the script and in ../timescale_db)."

GEN_FILE="$(find_file generate_sensor_data.sql \
    "${SCRIPT_DIR}/generate_sensor_data.sql" \
    "${SCRIPT_DIR}/../data_generation/generate_sensor_data.sql")" || true

# ------------------------------------------------------------------------------
# Apply the schema (skipped if it is already present)
# ------------------------------------------------------------------------------
if sudo -u postgres psql -d "${DB_NAME}" -tAc "SELECT to_regclass('public.\"Sensor\"') IS NOT NULL;" | grep -q t; then
    warn "Schema already present in '${DB_NAME}', skipping."
else
    log "Applying schema from '${SCHEMA_FILE}'..."
    sudo -u postgres psql -d "${DB_NAME}" -v ON_ERROR_STOP=1 -f "${SCHEMA_FILE}"
fi

# ------------------------------------------------------------------------------
# Install the data generator function (CREATE OR REPLACE, safe to re-run)
# ------------------------------------------------------------------------------
if [[ -n "$GEN_FILE" ]]; then
    log "Installing the data generator function from '${GEN_FILE}'..."
    sudo -u postgres psql -d "${DB_NAME}" -v ON_ERROR_STOP=1 -f "${GEN_FILE}"
else
    warn "generate_sensor_data.sql not found, skipping the generator function."
fi

# ------------------------------------------------------------------------------
# Verification
# ------------------------------------------------------------------------------
log "=== VERIFICATION ==="
echo ""
echo "Extensions in '${DB_NAME}':"
sudo -u postgres psql -d "${DB_NAME}" -c "\dx"

echo ""
echo "TimescaleDB version:"
sudo -u postgres psql -d "${DB_NAME}" -tAc \
    "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';"

echo ""
echo "Hypertables in '${DB_NAME}':"
sudo -u postgres psql -d "${DB_NAME}" \
    -c "SELECT hypertable_name FROM timescaledb_information.hypertables ORDER BY hypertable_name;"

echo ""
log "Database '${DB_NAME}' is ready."
echo "Connect with:  psql -h localhost -U postgres -d ${DB_NAME}"
echo "Fill test data:  SELECT public.generate_sensor_data(100000);"
