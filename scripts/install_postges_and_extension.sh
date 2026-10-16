#!/bin/bash
set -euo pipefail

# ==============================================================================
# Установка PostgreSQL (последняя версия) + TimescaleDB + pg_stat_statements
# Для чистого Debian. Требуется root или sudo.
# ==============================================================================

# Цветной вывод
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# Проверка root
if [[ $EUID -ne 0 ]]; then
   error "Скрипт должен выполняться от root (sudo)."
fi

# ==============================================================================
# ШАГ 1: Подготовка системы
# ==============================================================================
log "Обновление системы и установка зависимостей..."
apt update 
apt install -y curl ca-certificates gnupg lsb-release wget sudo

# ==============================================================================
# ШАГ 2: Подключение официального репозитория PostgreSQL (PGDG)
# Это гарантирует установку последней стабильной версии PostgreSQL.
# ==============================================================================
log "Подключение репозитория PostgreSQL (PGDG)..."

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
log "Установка PostgreSQL (последняя версия из PGDG)..."
apt install -y postgresql postgresql-contrib

# Автоматическое определение установленной мажорной версии
PG_VERSION=$(pg_config --version | awk '{print $2}' | cut -d. -f1)
log "Установлена PostgreSQL версии: ${PG_VERSION}"

# ==============================================================================
# ШАГ 4: Подключение репозитория TimescaleDB
# ==============================================================================
log "Подключение репозитория TimescaleDB..."

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
log "Установка TimescaleDB для PostgreSQL ${PG_VERSION}..."
apt install -y "timescaledb-2-postgresql-${PG_VERSION}"

# ==============================================================================
# ШАГ 6: Настройка PostgreSQL и TimescaleDB
# ==============================================================================

# timescaledb-tune: автоматическая оптимизация postgresql.conf
log "Запуск timescaledb-tune (автоматическая оптимизация)..."
if command -v timescaledb-tune &> /dev/null; then
    timescaledb-tune --quiet --yes
else
    warn "timescaledb-tune не найден. Проверьте установку TimescaleDB."
fi

# ------------------------------------------------------------------------------
# Настройка shared_preload_libraries (timescaledb + pg_stat_statements)
# Важно: не перезаписываем существующие значения, а добавляем к ним.
# ------------------------------------------------------------------------------
log "Настройка shared_preload_libraries..."

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
    warn "Не удалось найти postgresql.conf."
fi

# ------------------------------------------------------------------------------
# Перезапуск PostgreSQL для применения всех настроек
# ------------------------------------------------------------------------------
log "Перезапуск PostgreSQL..."
systemctl restart postgresql
systemctl enable postgresql

# ==============================================================================
# ШАГ 7: Создание базы данных и активация расширений
# ==============================================================================
DB_NAME="sensors"
DB_USER="postgres"

log "Создание базы данных '${DB_NAME}'..."
sudo -u postgres createdb "${DB_NAME}" 2>/dev/null || warn "База '${DB_NAME}' уже существует."

log "Активация расширений в базе '${DB_NAME}'..."

# Активация TimescaleDB
sudo -u postgres psql -d "${DB_NAME}" -c "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;" \
    && log "TimescaleDB активирован." \
    || warn "Не удалось активировать TimescaleDB."

# Активация pg_stat_statements
sudo -u postgres psql -d "${DB_NAME}" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;" \
    && log "pg_stat_statements активирован." \
    || warn "Не удалось активировать pg_stat_statements."

# ==============================================================================
# ПРОВЕРКА
# ==============================================================================
log "=== ПРОВЕРКА УСТАНОВКИ ==="
echo ""
echo "Версия PostgreSQL:"
sudo -u postgres psql -c "SELECT version();" -t | head -1

echo ""
echo "Установленные расширения в базе '${DB_NAME}':"
sudo -u postgres psql -d "${DB_NAME}" -c "\dx" | grep -E "timescaledb|pg_stat_statements" || echo "Расширения не найдены."

echo ""
echo "Статус сервиса PostgreSQL:"
systemctl is-active postgresql && echo "Работает" || echo "Не работает"

echo ""
log "=== УСТАНОВКА ЗАВЕРШЕНА ==="
echo ""
echo "Для подключения к базе используйте:"
echo "  sudo -u postgres psql -d ${DB_NAME}"
echo ""
echo "Для просмотра статистики запросов:"
echo "  SELECT * FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;"
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '12345678';"