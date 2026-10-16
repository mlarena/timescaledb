# Скрипты установки и создания баз данных

Набор bash-скриптов для чистого **Debian**: установка PostgreSQL + TimescaleDB
и создание двух баз данных — `simple_db` (обычный PostgreSQL) и `timescale_db`
(с расширением TimescaleDB). В обеих базах включается `pg_stat_statements`.

## Состав каталога

| Файл | Назначение |
|------|------------|
| `install_postgres_and_extension.sh` | Устанавливает PostgreSQL и TimescaleDB, настраивает `shared_preload_libraries`, перезапускает сервер. Базы **не** создаёт. |
| `create_simple_db.sh` | Создаёт базу `simple_db` и включает в ней `pg_stat_statements`. |
| `create_timescale_db.sh` | Создаёт базу `timescale_db` и включает в ней `timescaledb` и `pg_stat_statements`. |
| `README.md` | Этот файл. |

## Требования

- Debian (bookworm, trixie и т.п.), доступ в интернет.
- Права root или sudo.
- Скрипты запускать **по порядку**: сначала установка, затем создание баз.

## Порядок выполнения

```bash
cd scripts
chmod +x *.sh

# 1. Установка PostgreSQL + TimescaleDB (один раз)
sudo ./install_postgres_and_extension.sh

# 2. Создание баз (можно в любом порядке, каждую — один раз)
sudo ./create_simple_db.sh
sudo ./create_timescale_db.sh
```

Все скрипты идемпотентны: повторный запуск не сломает уже установленное и
не пересоздаст существующие базы.

## Что делает каждый скрипт

### `install_postgres_and_extension.sh`

1. Обновляет систему, ставит зависимости (`curl`, `gnupg`, `lsb-release`, `wget`).
2. Подключает официальный репозиторий PostgreSQL (PGDG) и ставит
   последнюю стабильную версию `postgresql` + `postgresql-contrib`.
3. Подключает репозиторий TimescaleDB и ставит пакет
   `timescaledb-2-postgresql-<версия>`.
4. Запускает `timescaledb-tune` для автонастройки `postgresql.conf`.
5. Прописывает `shared_preload_libraries = 'timescaledb,pg_stat_statements'`
   (существующие значения сохраняются, дубли убираются).
6. Перезапускает и включает автозапуск службы `postgresql`.
7. Задаёт пароль роли `postgres` (по умолчанию `12345678`, переменная
   `DB_PASSWORD` в начале скрипта) — нужен для TCP-подключений.

> `shared_preload_libraries` задаётся один раз на весь кластер, поэтому
> TimescaleDB и `pg_stat_statements` прописаны здесь, а не в скриптах создания
> баз. Само расширение включается отдельно в каждой базе (`CREATE EXTENSION`).

### `create_simple_db.sh`

- Создаёт базу `simple_db`, если её ещё нет.
- Выполняет `CREATE EXTENSION IF NOT EXISTS pg_stat_statements;`.
- Показывает список расширений базы.

### `create_timescale_db.sh`

- Создаёт базу `timescale_db`, если её ещё нет.
- Выполняет `CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;`.
- Выполняет `CREATE EXTENSION IF NOT EXISTS pg_stat_statements;`.
- Показывает список расширений и версию TimescaleDB.

## Загрузка схемы (опционально)

После создания баз можно загрузить схему и справочные данные:

```bash
# Из корня репозитория

# Обычная схема
sudo -u postgres psql -d simple_db -f simple_db/sensor_db.sql

# Схема с гипертаблицами TimescaleDB
sudo -u postgres psql -d timescale_db -f timescale_db/sensor_timescale_db.sql
```

Скрипты генерации тестовых данных находятся в `data_generation/`
(см. `data_generation/generate_sensor_data.sql`).

## Подключение

Строка подключения для приложения `SensorDataGenerator`
(файл `SensorDataGenerator/appsettings.json`, ключ `ConnectionStrings:Postgres`):

```
Host=localhost;Port=5432;Database=simple_db;Username=postgres;Password=12345678
```

Для TimescaleDB замените `Database` на `timescale_db`.

Проверка из командной строки:

```bash
psql -h localhost -U postgres -d simple_db
psql -h localhost -U postgres -d timescale_db
```

## Статистика запросов (pg_stat_statements)

```sql
-- Топ-10 самых долгих запросов
SELECT query, calls, total_exec_time, mean_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Сброс статистики
SELECT pg_stat_statements_reset();
```

## Проверка результата

```sql
-- В нужной базе
SELECT extname, extversion FROM pg_extension;

-- Версия TimescaleDB (в timescale_db)
SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';

-- Список гипертаблиц (в timescale_db, после загрузки схемы)
SELECT hypertable_name FROM timescaledb_information.hypertables;
```

## Возможные проблемы

- **`CREATE EXTENSION timescaledb` падает с ошибкой про `shared_preload_libraries`.**
  Значит, не выполнен или не завершился перезапуск PostgreSQL после установки.
  Проверьте `SHOW shared_preload_libraries;` — там должно быть `timescaledb`,
  при необходимости перезапустите службу: `systemctl restart postgresql`.
- **Не удаётся подключиться по TCP с паролем.** Убедитесь, что пароль роли
  `postgres` задан (`install_postgres_and_extension.sh`) и в `pg_hba.conf`
  разрешён вход `host ... 127.0.0.1/32` (по умолчанию на Debian разрешён).
- **`psql: command not found`.** PostgreSQL ещё не установлен — выполните
  `install_postgres_and_extension.sh`.
