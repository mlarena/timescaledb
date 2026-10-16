-- Generates 100000 rows in EACH sensor data table.
-- Run with:  psql -f generate_100000.sql
-- (The \ir include below loads the generator function from this directory.)
\ir generate_sensor_data.sql

SELECT public.generate_sensor_data(100000);
