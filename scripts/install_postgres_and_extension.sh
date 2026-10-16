#!/bin/bash
set -euo pipefail

# ==============================================================================
# PostgreSQL (latest stable) + TimescaleDB installation for a clean Debian.
# Requires root or sudo.
#
# This script only installs the software and tunes the server. Database
# creation and per-database extensions are handled by separate scripts:
#   create_simple_db.sh     -> simple_db    (PostgreSQL + pg_stat_statements)
#   create_timescale_db.sh  -> timescale_db (TimescaleDB + pg_stat_statements)
# ==============================================================================

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

# ==============================================================================
# ШАГ 1: Подготовка системы
# ==============================================================================
log "Updating the system and installing dependencies..."
apt update 
apt install -y curl ca-certificates gnupg lsb-release wget sudo

# ==============================================================================
# ШАГ 2: Подключение официального репозитория PostgreSQL (PGDG)
# Это гарантирует установку последней стабильной версии PostgreSQL.
# ==============================================================================
log "Adding the PostgreSQL (PGDG) repository..."

# Импорт GPG-ключа PostgreSQL
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg

# Определение кодового имени Debian (bookworm, trixie и т.д.)
CODENAME=$(lsb_release -cs)

# Добавление репозитория PGDG
echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt ${CODENAME}-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list

apt update

# ==============================================================================
# ШАГ 3: Установка PostgreSQL (последняя версия)
# Без указания версии — apt выберет самую свежую из репозитория.
# ==============================================================================
log "Installing PostgreSQL (latest from PGDG)..."
apt install -y postgresql postgresql-contrib

# Автоматическое определение установленной мажорной версии
PG_VERSION=$(pg_config --version | awk '{print $2}' | cut -d. -f1)
log "Installed PostgreSQL version: ${PG_VERSION}"

# ==============================================================================
# ШАГ 4: Подключение репозитория TimescaleDB
# ==============================================================================
log "Adding the TimescaleDB repository..."

# Импорт GPG-ключа TimescaleDB
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey \
    | gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg

# Добавление репозитория TimescaleDB
echo "deb https://packagecloud.io/timescale/timescaledb/debian/ ${CODENAME} main" \
    > /etc/apt/sources.list.d/timescaledb.list

apt update

# ==============================================================================
# ШАГ 5: Установка TimescaleDB
# Пакет имеет вид: timescaledb-2-postgresql-<версия>
# ==============================================================================
log "Installing TimescaleDB for PostgreSQL ${PG_VERSION}..."
apt install -y "timescaledb-2-postgresql-${PG_VERSION}"

# ==============================================================================
# ШАГ 6: Настройка PostgreSQL и TimescaleDB
# ==============================================================================

# timescaledb-tune: автоматическая оптимизация postgresql.conf
log "Running timescaledb-tune (automatic tuning)..."
if command -v timescaledb-tune &> /dev/null; then
    timescaledb-tune --quiet --yes
else
    warn "timescaledb-tune not found. Check the TimescaleDB installation."
fi

# ------------------------------------------------------------------------------
# Настройка shared_preload_libraries (timescaledb + pg_stat_statements)
# Важно: не перезаписываем существующие значения, а добавляем к ним.
# ------------------------------------------------------------------------------
log "Configuring shared_preload_libraries..."

PG_CONF="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"
if [[ -f "$PG_CONF" ]]; then
    # Извлекаем текущее значение shared_preload_libraries
    CURRENT_LIBS=$(grep -E "^shared_preload_libraries" "$PG_CONF" \
        | sed -E "s/.*=\s*'([^']*)'.*/\1/" || echo "")

    # Собираем новый список без дублей
    NEW_LIBS=""
    for lib in timescaledb pg_stat_statements; do
        if [[ ",$CURRENT_LIBS," != *",$lib,"* ]]; then
            NEW_LIBS="${NEW_LIBS:+$NEW_LIBS,}$lib"
        fi
    done
    # Добавляем то, что уже было
    if [[ -n "$CURRENT_LIBS" ]]; then
        NEW_LIBS="${NEW_LIBS:+$NEW_LIBS,}$CURRENT_LIBS"
    fi
    # Убираем возможные дубли
    NEW_LIBS=$(echo "$NEW_LIBS" | tr ',' '\n' | sort -u | paste -sd, -)

    if grep -q "^shared_preload_libraries" "$PG_CONF"; then
        sed -i "s|^shared_preload_libraries.*|shared_preload_libraries = '${NEW_LIBS}'|" "$PG_CONF"
    else
        echo "shared_preload_libraries = '${NEW_LIBS}'" >> "$PG_CONF"
    fi
    log "shared_preload_libraries = '${NEW_LIBS}'"
else
    warn "Could not find postgresql.conf."
fi

# ------------------------------------------------------------------------------
# Перезапуск PostgreSQL для применения всех настроек
# ------------------------------------------------------------------------------
log "Restarting PostgreSQL..."
systemctl restart postgresql
systemctl enable postgresql

# ==============================================================================
# ШАГ 7: Установка пароля роли postgres (нужен для TCP-подключений)
# ==============================================================================
DB_PASSWORD="12345678"
log "Setting the 'postgres' role password..."
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '${DB_PASSWORD}';"

# ==============================================================================
# ПРОВЕРКА
# ==============================================================================
log "=== INSTALLATION CHECK ==="
echo ""
echo "PostgreSQL version:"
sudo -u postgres psql -tAc "SELECT version();"

echo ""
echo "shared_preload_libraries:"
sudo -u postgres psql -tAc "SHOW shared_preload_libraries;"

echo ""
echo "PostgreSQL service status:"
systemctl is-active postgresql && echo "running" || echo "not running"

echo ""
log "=== INSTALLATION COMPLETE ==="
echo ""
echo "Next step - create the databases:"
echo "  sudo ./create_simple_db.sh"
echo "  sudo ./create_timescale_db.sh"
echo ""
echo "Then connect with:"
echo "  psql -h localhost -U postgres -d <database>"