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

### Схема применяется автоматически

Каждый create-скрипт сам разворачивает схему и устанавливает функцию-генератор
данных:

- `create_simple_db.sh` применяет `sensor_db.sql`;
- `create_timescale_db.sh` применяет `sensor_timescale_db.sql`;
- оба устанавливают функцию `generate_sensor_data(p_rows)` из
  `data_generation/generate_sensor_data.sql`.

Схема пропускается, если таблицы уже существуют. Отдельная загрузка вручную
нужна только при нестандартном сценарии:

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
    tsdb.partition_column = 'ReceivedAt',
    tsdb.chunk_interval   = '1 day',
    tsdb.segmentby        = '"SensorId"',
    tsdb.orderby          = '"ReceivedAt" DESC'
);
```

- партиционирование по `"ReceivedAt"` (время приёма) — вставки идут в свежий чанк;
- `chunk_interval = '1 day'` — один чанк на сутки;
- `segmentby = "SensorId"` — сегментация columnstore по датчику;
- columnstore-policy создаётся автоматически: чанки старше интервала сжимаются;
- кавычки зависят от параметра: `partition_column` — **без** кавычек
  (`'ReceivedAt'`), а `segmentby`/`orderby` — **с** двойными кавычками внутри
  строки (`'"SensorId"'`), т.к. они разбираются как SQL-идентификаторы;
- первичный ключ — `("Id", "ReceivedAt")`: гипертаблица требует, чтобы
  уникальные ограничения включали колонку партиционирования.

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

Функция `generate_sensor_data(p_rows)` уже установлена в обеих базах
create-скриптами (см. раздел 1). Она вставляет `p_rows` случайных строк
**в каждую** таблицу данных.

```bash
# Пример: 1 000 000 строк на таблицу (итого ~5 млн)
psql -h localhost -U postgres -d simple_db \
    -c "SELECT public.generate_sensor_data(1000000);"
```

Готовые скрипты по объёмам лежат в `data_generation/` и просто вызывают эту
функцию (перед запуском пересоздают её из `generate_sensor_data.sql`):

```bash
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

### 4.3. Запросы для сравнения (работают в обеих базах)

Все запросы ниже — **чистый SQL без функций TimescaleDB**, поэтому одинаково
выполняются и в `simple_db`, и в `timescale_db`. Именно так и надо сравнивать:
один и тот же текст запроса, одни и те же данные, разное время выполнения.

Запускайте в `psql` с включённым таймером:

```sql
\timing on
```

Перед замерами обязательно обновите статистику (иначе планировщик может
выбрать плохой план, особенно в `simple_db` после массовой заливки):

```sql
ANALYZE public."DOVData";
ANALYZE public."DSPDData";
ANALYZE public."DustData";
ANALYZE public."IWSData";
ANALYZE public."MUEKSData";
```

---

#### Q1. Аналитический скан всей таблицы (главный плюс columnstore)

Полный проход с агрегацией по всем строкам. В `simple_db` читаются целые строки,
в `timescale_db` — только нужные колонки из сжатых чанков.

```sql
SELECT count(*)                            AS rows,
       round(avg("PM10Act"), 2)            AS avg_pm10,
       round(max("PM25Act"), 2)            AS max_pm25,
       round(avg("TemperatureProbe"), 2)   AS avg_temp,
       round(avg("HumidityProbe"), 2)      AS avg_humidity
FROM public."DustData";
```

**На что смотреть:** время выполнения и `Buffers: shared read` в `EXPLAIN`.
На сжатых чанках TimescaleDB читает в разы меньше страниц.

---

#### Q2. Широкая строка: агрегация по многим колонкам

Худший случай для rowstore (читается вся строка) и лучший для columnstore
(читаются только перечисленные колонки).

```sql
SELECT count(*)                          AS rows,
       round(avg("Grip"), 2)             AS avg_grip,
       round(avg("Shake"), 2)            AS avg_shake,
       round(avg("UPower"), 2)           AS avg_upower,
       round(avg("TemperatureCase"), 2)  AS avg_temp_case,
       round(avg("TemperatureRoad"), 2)  AS avg_temp_road,
       round(avg("HeightH2O"), 2)        AS avg_h2o,
       round(avg("HeightIce"), 2)        AS avg_ice,
       round(avg("HeightSnow"), 2)       AS avg_snow,
       round(avg("PercentICE"), 2)       AS avg_percent_ice,
       round(avg("PercentPGM"), 2)       AS avg_percent_pgm,
       round(avg("AngleToRoad"), 2)      AS avg_angle
FROM public."DSPDData";
```

---

#### Q3. Почасовая агрегация за длинный период

`date_trunc` есть в обычном PostgreSQL, поэтому запрос переносим. В
`timescale_db` он выполняется по сжатым чанкам и с отсечением лишних чанков.

```sql
SELECT date_trunc('hour', "DataTimestamp") AS bucket,
       count(*)                            AS readings,
       round(avg("TemperatureRoad"), 2)    AS avg_temp,
       round(min("TemperatureRoad"), 2)    AS min_temp,
       round(max("TemperatureRoad"), 2)    AS max_temp
FROM public."DSPDData"
WHERE "DataTimestamp" >= now() - interval '90 days'
GROUP BY bucket
ORDER BY bucket;
```

---

#### Q4. Срез по диапазону времени (отсечение чанков)

На гипертаблице по `"ReceivedAt"` планировщик отбрасывает чанки вне диапазона —
в плане будет меньше узлов `Scan`. В `simple_db` это обычный индексный скан
либо чтение всей таблицы.

```sql
SELECT count(*)                         AS rows,
       round(avg("EnvTemperature"), 2)  AS avg_temp,
       round(avg("Humidity"), 2)        AS avg_humidity
FROM public."IWSData"
WHERE "ReceivedAt" >= now() - interval '7 days';
```

Проверить, какие чанки реально читались (только `timescale_db`):

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*)
FROM public."IWSData"
WHERE "ReceivedAt" >= now() - interval '7 days';
```

---

#### Q5. Последнее показание по каждому датчику

`DISTINCT ON` — стандартный PostgreSQL, работает в обеих базах.

```sql
SELECT DISTINCT ON ("SensorId")
       "SensorId",
       "DataTimestamp",
       "TemperatureRoad",
       "TemperatureCase"
FROM public."DSPDData"
ORDER BY "SensorId", "DataTimestamp" DESC;
```

---

#### Q6. Фильтр по измеряемому значению + агрегат

По колонкам значений индексов нет — это скан. В `timescale_db` помогают
minmax/sparse-индексы сжатых чанков.

```sql
SELECT count(*)                        AS icy_readings,
       round(avg("PercentICE"), 2)     AS avg_percent_ice,
       round(avg("TemperatureRoad"), 2) AS avg_temp_road
FROM public."DSPDData"
WHERE "PercentICE" > 50
  AND "DataTimestamp" >= now() - interval '30 days';
```

---

#### Q7. Join со справочником + группировка по датчику

```sql
SELECT s."SerialNumber",
       count(*)                          AS readings,
       round(avg(d."VisibleRange"), 2)   AS avg_visible_range,
       round(min(d."VisibleRange"), 2)   AS min_visible_range,
       round(max(d."VisibleRange"), 2)   AS max_visible_range
FROM public."DOVData" d
JOIN public."Sensor" s ON s."Id" = d."SensorId"
WHERE d."DataTimestamp" >= now() - interval '30 days'
GROUP BY s."SerialNumber"
ORDER BY readings DESC;
```

---

#### Q8. Группировка по посту наблюдения

Использует денормализованный `"MonitoringPostId"`.

```sql
SELECT "MonitoringPostId",
       count(*)                     AS readings,
       round(avg("TempExt"), 2)     AS avg_temp_ext,
       round(avg("UAkb"), 2)        AS avg_battery_voltage,
       round(avg("WhAkb"), 2)       AS avg_battery_energy
FROM public."MUEKSData"
WHERE "DataTimestamp" >= now() - interval '30 days'
GROUP BY "MonitoringPostId"
ORDER BY readings DESC;
```

---

#### Q9. Объём данных по суткам (проверка партиционирования)

```sql
SELECT date_trunc('day', "DataTimestamp") AS day,
       count(*)                           AS readings
FROM public."DustData"
GROUP BY day
ORDER BY day;
```

---

#### Как замерять каждый запрос

```sql
-- 1. Прогрев (не замеряем)
SELECT count(*) FROM public."DustData";

-- 2. Замер с планом и буферами
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*), round(avg("PM10Act"), 2) FROM public."DustData";

-- 3. Три прогона подряд с таймером
\timing on
SELECT count(*), round(avg("PM10Act"), 2) FROM public."DustData";
SELECT count(*), round(avg("PM10Act"), 2) FROM public."DustData";
SELECT count(*), round(avg("PM10Act"), 2) FROM public."DustData";
```

Фиксируйте в таблице результатов: база, объём данных, состояние чанков
(сжаты/нет), время, `shared read` из `EXPLAIN`.

#### Важные оговорки для честного сравнения

1. **Свежие чанки не сжаты.** Пока чанк младше `chunk_interval` (1 день), он
   лежит в rowstore. Чтобы увидеть эффект columnstore сразу после заливки,
   сожмите чанки вручную (раздел 4.6).
2. **Данные из `data_generation` лежат в одном чанке.** Функция ставит
   `"ReceivedAt" = now()` для всех строк, поэтому вся масса попадает в один
   чанк, и отсечение чанков (Q4) на ней не проявится. Для демонстрации
   партиционирования распределите `"ReceivedAt"` по времени, например:

   ```sql
   -- Разложить ReceivedAt по 30 суткам назад от DataTimestamp
   UPDATE public."DustData"
   SET "ReceivedAt" = "DataTimestamp";
   ```
   (выполнять до сжатия чанков; на большом объёме — долго).
3. **`simple_db` требует `VACUUM`** после массовых вставок/удалений, иначе
   таблица раздувается и сравнение нечестное:
   ```sql
   VACUUM (ANALYZE) public."DustData";
   ```
4. **Одинаковые данные.** Перед сравнением сверьте `count(*)` в обеих базах.
5. **`time_bucket` — только TimescaleDB.** В примерах выше он намеренно не
   используется (в `simple_db` его нет). Для `timescale_db` его можно
   применять как замену `date_trunc`, он умеет произвольные интервалы
   (`'15 minutes'`, `'1 day'`) и работает с `timezone`.

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
# 1. Установка и создание баз (схема и функция генератора ставятся автоматически)
cd scripts && chmod +x *.sh
sudo ./install_postgres_and_extension.sh
sudo ./create_simple_db.sh
sudo ./create_timescale_db.sh
cd ..

# 2. Тестовые данные (функция уже установлена create-скриптом)
psql -h localhost -U postgres -d timescale_db \
    -c "SELECT public.generate_sensor_data(1000000);"

# 3. Нагрузка в реальном времени (собранный генератор)
./release/linux-x64/SensorDataGenerator

# 4. Замеры
psql -h localhost -U postgres -d timescale_db
#   \timing on
#   EXPLAIN (ANALYZE, BUFFERS) SELECT ...
```
