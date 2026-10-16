# TimescaleDB Sensor Test Bench

Тестовый стенд для сравнения производительности **обычного PostgreSQL** и
**TimescaleDB** на задаче хранения телеметрии с датчиков дорожной метеостанции.

Стенд состоит из двух баз с одинаковой схемой, генератора нагрузки и набора
SQL-скриптов для заливки больших объёмов тестовых данных.

## Состав репозитория

| Каталог / файл | Назначение |
|----------------|------------|
| `simple_db/sensor_db.sql` | Схема и справочные данные для обычного PostgreSQL. |
| `timescale_db/sensor_timescale_db.sql` | Та же схема, но таблицы данных — гипертаблицы TimescaleDB с columnstore. |
| `scripts/` | Скрипты установки PostgreSQL/TimescaleDB и создания баз (см. `scripts/README.md`). |
| `scripts/build_sensor_data_generator.ps1` | Сборка генератора данных (PowerShell, для Windows). |
| `SensorDataGenerator/` | Консольное приложение .NET: пишет телеметрию в базу раз в секунду. |
| `data_generation/` | SQL-скрипты для заливки 100k / 500k / 1M / 2M / 5M записей на таблицу. |

## Модель данных

Справочники (заполняются один раз):

- `SensorType` — типы датчиков (`DOV`, `DSPD`, `DUST`, `IWS`, `MUEKS`);
- `MonitoringPost` — посты наблюдения;
- `Sensor` — датчики, привязанные к типу и посту.

Таблицы данных (растут постоянно, по одной на тип датчика):

- `DOVData`, `DSPDData`, `DustData`, `IWSData`, `MUEKSData`.

В каждой таблице данных есть `"SensorId"`, `"ReceivedAt"` (время приёма),
`"DataTimestamp"` (время измерения) и набор полей конкретного датчика.

---

## 1. Установка PostgreSQL и создание баз

Подробности — в `scripts/README.md`. Кратко, на чистом Debian:

```bash
cd scripts
chmod +x *.sh

# Установка PostgreSQL + TimescaleDB (один раз, от root)
sudo ./install_postgres_and_extension.sh

# Создание баз (каждую — один раз)
sudo ./create_simple_db.sh      # база simple_db    (pg_stat_statements)
sudo ./create_timescale_db.sh   # база timescale_db (timescaledb + pg_stat_statements)
```

Обе базы создаются с расширением `pg_stat_statements` для сбора статистики
запросов. Скрипты идемпотентны — повторный запуск безопасен.

### Загрузка схемы

```bash
# Из корня репозитория
sudo -u postgres psql -d simple_db    -f simple_db/sensor_db.sql
sudo -u postgres psql -d timescale_db -f timescale_db/sensor_timescale_db.sql
```

### Ключевое отличие `timescale_db`

Таблицы данных созданы как **гипертаблицы** с включённым columnstore
(сжатием) через декларативный синтаксис:

```sql
) WITH (
    tsdb.hypertable,
    tsdb.columnstore      = true,
    tsdb.partition_column = '"ReceivedAt"',
    tsdb.chunk_interval   = '1 day',
    tsdb.segmentby        = '"SensorId"',
    tsdb.orderby          = '"ReceivedAt" DESC'
);
```

- партиционирование по `"ReceivedAt"` (время приёма) — вставки идут в свежий чанк;
- `chunk_interval = '1 day'` — один чанк на сутки;
- `segmentby = "SensorId"` — сегментация columnstore по датчику;
- columnstore-policy создаётся автоматически: чанки старше интервала сжимаются.

---

## 2. Генератор данных (SensorDataGenerator)

Консольное приложение .NET 8, которое раз в секунду пишет по одной строке
в таблицу данных каждого датчика. Строка подключения — в `appsettings.json`.

```json
{
  "ConnectionStrings": {
    "Postgres": "Host=localhost;Port=5432;Database=simple_db;Username=postgres;Password=12345678"
  },
  "Generator": {
    "IntervalSeconds": 1,
    "ActiveSensorsOnly": false
  }
}
```

Для замера на TimescaleDB поменяйте `Database` на `timescale_db`.

### Сборка (Windows, PowerShell)

```powershell
./scripts/build_sensor_data_generator.ps1
```

Скрипт собирает self-contained single-file бинарник под `linux-x64`
в `release/linux-x64/`. Параметры:

```powershell
./scripts/build_sensor_data_generator.ps1 -Runtime linux-arm64
./scripts/build_sensor_data_generator.ps1 -OutputDir D:\build\gen
```

Эквивалентная команда вручную:

```powershell
dotnet publish SensorDataGenerator/SensorDataGenerator.csproj `
    -c Release -r linux-x64 --self-contained true `
    -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true `
    -o release/linux-x64/
```

### Запуск (Debian)

```bash
./SensorDataGenerator
```

Остановка — `Ctrl+C`.

---

## 3. Заливка больших объёмов данных

SQL-скрипты в `data_generation/` создают функцию `generate_sensor_data(p_rows)`,
которая вставляет `p_rows` случайных строк **в каждую** таблицу данных.

```bash
# Пример: 1 000 000 строк на таблицу (итого ~5 млн)
psql -h localhost -U postgres -d simple_db -f data_generation/generate_1000000.sql
```

Доступные объёмы: `100000`, `500000`, `1000000`, `2000000`, `5000000`.

Функция **только дописывает** данные. Для чистого старта:

```sql
TRUNCATE public."DOVData", public."DSPDData", public."DustData",
         public."IWSData", public."MUEKSData";
```

---

## 4. Анализ производительности базы данных

Ниже — методика сравнения `simple_db` и `timescale_db` на одинаковых данных.

### 4.1. Сначала прогрейте кеш

Первый прогон запроса читает данные с диска и всегда медленнее. Перед замерами
выполните запрос 2–3 раза и замеряйте последний прогон.

### 4.2. Замер времени одного запроса

```sql
-- Включить точный вывод времени
\timing on

-- Многократно выполнить запрос для стабильной оценки
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT ...
```

- `ANALYZE` — реально выполняет запрос и показывает фактические времена.
- `BUFFERS` — показывает чтение из кеша (`shared hit`) и с диска (`read`).
- Для запросов, меняющих данные, оборачивайте в транзакцию:
  ```sql
  BEGIN;
  EXPLAIN (ANALYZE, BUFFERS) ... ;
  ROLLBACK;
  ```

### 4.3. Типовые аналитические запросы для сравнения

**Последние показания конкретного датчика:**

```sql
SELECT *
FROM public."DOVData"
WHERE "SensorId" = 1
ORDER BY "DataTimestamp" DESC
LIMIT 10;
```

**Агрегация по времени (среднее за час):**

```sql
SELECT time_bucket('1 hour', "DataTimestamp") AS bucket,
       avg("TemperatureRoad") AS avg_temp
FROM public."DSPDData"
WHERE "SensorId" = 1
  AND "DataTimestamp" >= now() - interval '30 days'
GROUP BY bucket
ORDER BY bucket;
```

**Скан по диапазону времени по всей таблице:**

```sql
SELECT count(*), avg("VisibleRange")
FROM public."DOVData"
WHERE "DataTimestamp" >= now() - interval '7 days';
```

**Аналитический скан большого объёма (проверка columnstore):**

```sql
SELECT avg("PM10Act"), max("PM25Act")
FROM public."DustData";
```

На TimescaleDB эти запросы идут через `time_bucket`, сегментацию и сжатые
чанки — сравнивайте план (`EXPLAIN`) и время с `simple_db`.

### 4.4. Статистика запросов (pg_stat_statements)

Включён в обеих базах. Позволяет найти самые дорогие запросы:

```sql
-- Топ-10 по суммарному времени
SELECT query,
       calls,
       round(total_exec_time::numeric, 2) AS total_ms,
       round(mean_exec_time::numeric, 2)  AS mean_ms,
       rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Сбросить статистику перед новым экспериментом
SELECT pg_stat_statements_reset();
```

### 4.5. Размер таблиц, индексов и сжатия

```sql
-- Размер по таблицам (данные + индексы)
SELECT relname,
       pg_size_pretty(pg_total_relation_size(oid)) AS total,
       pg_size_pretty(pg_relation_size(oid))       AS data,
       pg_size_pretty(pg_indexes_size(oid))        AS indexes
FROM pg_class
WHERE relname IN ('DOVData','DSPDData','DustData','IWSData','MUEKSData')
ORDER BY pg_total_relation_size(oid) DESC;
```

На TimescaleDB дополнительно:

```sql
-- Размер гипертаблицы
SELECT hypertable_name,
       pg_size_pretty(hypertable_size(format('%I', hypertable_name)::regclass)) AS size
FROM timescaledb_information.hypertables;

-- Список чанков с диапазонами времени
SELECT chunk_name, range_start, range_end, is_compressed
FROM timescaledb_information.chunks
WHERE hypertable_name = 'DOVData'
ORDER BY range_start DESC;

-- Экономия от сжатия (несжатый vs сжатый размер)
SELECT * FROM hypertable_compression_stats('public."DOVData"');

-- Информация о настройках columnstore по чанкам
SELECT * FROM chunk_columnstore_stats('public."DOVData"');
```

### 4.6. Управление сжатием при тестах

Свежие чанки (младше `chunk_interval`) лежат несжатыми. Чтобы сразу увидеть
эффект columnstore, сожмите чанки вручную:

```sql
-- Сжать все чанки гипертаблицы
SELECT convert_to_columnstore(c) FROM show_chunks('public."DOVData"') c;

-- Обратно в rowstore (например, перед массовой дозагрузкой)
SELECT convert_to_rowstore(c) FROM show_chunks('public."DOVData"') c;
```

Ускорить автосжатие в тесте (сжимать чанки старше 1 часа):

```sql
SELECT remove_columnstore_policy('public."DOVData"');
CALL add_columnstore_policy('public."DOVData"', after => INTERVAL '1 hour');
```

### 4.7. Нагрузка на запись

- Сравните скорость вставки генератора: запустите `SensorDataGenerator` против
  `simple_db` и против `timescale_db` на одинаковых данных.
- Для тяжёлой заливки удобнее SQL-функция из `data_generation/`:

  ```sql
  \timing on
  SELECT public.generate_sensor_data(1000000);
  ```

- Дополнительно смотрите на загрузку диска:

  ```bash
  iostat -x 1      # из пакета sysstat
  vmstat 1
  ```

### 4.8. Ретеншн (удаление старых данных)

Для многолетнего хранения стоит ограничить глубину хранения:

```sql
-- Удалять данные старше 2 лет (TimescaleDB делает это по чанкам, быстро)
SELECT add_retention_policy('public."DOVData"', INTERVAL '2 years');
```

### 4.9. Чек-лист корректного сравнения

1. Одинаковый объём данных в обеих базах.
2. Одинаковое железо и версия PostgreSQL.
3. Прогрев кеша перед замерами.
4. Замер последнего из 2–3 прогонов, а не первого.
5. `EXPLAIN (ANALYZE, BUFFERS)` для сравнения планов, а не только времени.
6. Для TimescaleDB — учтите состояние чанков (сжаты/нет) и наличие политики.
7. Фиксируйте результат: время, план, размер таблиц до и после.

---

## 5. Быстрый старт (полный цикл)

```bash
# 1. Установка и создание баз
cd scripts && chmod +x *.sh
sudo ./install_postgres_and_extension.sh
sudo ./create_simple_db.sh
sudo ./create_timescale_db.sh
cd ..

# 2. Схема
sudo -u postgres psql -d simple_db    -f simple_db/sensor_db.sql
sudo -u postgres psql -d timescale_db -f timescale_db/sensor_timescale_db.sql

# 3. Тестовые данные
psql -h localhost -U postgres -d timescale_db -f data_generation/generate_1000000.sql

# 4. Нагрузка в реальном времени (собранный генератор)
./release/linux-x64/SensorDataGenerator

# 5. Замеры
psql -h localhost -U postgres -d timescale_db
#   \timing on
#   EXPLAIN (ANALYZE, BUFFERS) SELECT ...
```
