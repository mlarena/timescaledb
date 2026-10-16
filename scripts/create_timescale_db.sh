#!/bin/bash
set -euo pipefail

# ==============================================================================
# Creates the TimescaleDB-enabled database "timescale_db" and enables the
# timescaledb and pg_stat_statements extensions in it.
#
# Prerequisites: run install_postges_and_extension.sh first (it installs
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
    error "psql not found. Run install_postges_and_extension.sh first."
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
log "Database '${DB_NAME}' is ready."
echo "Connect with:  psql -h localhost -U postgres -d ${DB_NAME}"
