-- ============================================================
-- generate_sensor_data(p_rows)
--
-- Inserts p_rows random telemetry rows into EACH sensor data table:
--   DOVData, DSPDData, DustData, IWSData, MUEKSData.
--
-- Rows are attached to the sensors found in the reference tables, matched
-- by sensor type, so the reference tables (SensorType, MonitoringPost,
-- Sensor) must be filled before running this function.
--
-- Existing rows are preserved: the function only appends new data.
-- To start from a clean state run, for example:
--   TRUNCATE public."DOVData", public."DSPDData", public."DustData",
--            public."IWSData", public."MUEKSData";
--
-- This file only defines the function. The per-volume scripts
-- (generate_100000.sql, generate_500000.sql, ...) include it via \ir.
-- ============================================================
CREATE OR REPLACE FUNCTION public.generate_sensor_data(p_rows bigint)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- ---------------------------------------------------------
    -- DOVData
    -- ---------------------------------------------------------
    INSERT INTO public."DOVData"
        ("SensorId", "ReceivedAt", "DataTimestamp",
         "VisibleRange", "BrightFlag", "MonitoringPostId")
    SELECT
        s."Id",
        now(),
        now() - (g * interval '1 second'),
        round((random() * 1990 + 10)::numeric, 2),   -- VisibleRange  [10, 2000]
        (random() * 2)::int,                          -- BrightFlag    {0, 1}
        s."MonitoringPostId"
    FROM public."Sensor" s
    JOIN public."SensorType" st ON st."Id" = s."SensorTypeId"
    CROSS JOIN generate_series(1, p_rows) AS g
    WHERE st."SensorTypeName" = 'DOV';

    -- ---------------------------------------------------------
    -- DSPDData
    -- ---------------------------------------------------------
    INSERT INTO public."DSPDData"
        ("SensorId", "ReceivedAt", "DataTimestamp",
         "Grip", "Shake", "UPower", "TemperatureCase", "TemperatureRoad",
         "HeightH2O", "HeightIce", "HeightSnow", "PercentICE", "PercentPGM",
         "RoadStatus", "AngleToRoad", "TemperatureFreezePGM", "NeedCalibration",
         "GPSLatitude", "GPSLongitude", "DistanceToSurface", "IsGpsValid",
         "MonitoringPostId")
    SELECT
        s."Id",
        now(),
        now() - (g * interval '1 second'),
        round((random() * 1)::numeric, 2),            -- Grip                 [0, 1]
        round((random() * 100)::numeric, 2),          -- Shake                [0, 100]
        round((random() * 4 + 10)::numeric, 2),       -- UPower               [10, 14]
        round((random() * 100 - 40)::numeric, 2),     -- TemperatureCase      [-40, 60]
        round((random() * 100 - 40)::numeric, 2),     -- TemperatureRoad      [-40, 60]
        round((random() * 5)::numeric, 2),            -- HeightH2O            [0, 5]
        round((random() * 5)::numeric, 2),            -- HeightIce            [0, 5]
        round((random() * 20)::numeric, 2),           -- HeightSnow           [0, 20]
        round((random() * 100)::numeric, 2),          -- PercentICE           [0, 100]
        round((random() * 100)::numeric, 2),          -- PercentPGM           [0, 100]
        (random() * 8)::int,                          -- RoadStatus           {0..7}
        round((random() * 90)::numeric, 2),           -- AngleToRoad          [0, 90]
        round((random() * 60 - 60)::numeric, 2),      -- TemperatureFreezePGM [-60, 0]
        (random() * 2)::int,                          -- NeedCalibration      {0, 1}
        round((random() * 1 + 55)::numeric, 6),       -- GPSLatitude          [55, 56]
        round((random() * 1 + 37)::numeric, 6),       -- GPSLongitude         [37, 38]
        round((random() * 10000)::numeric, 2),        -- DistanceToSurface    [0, 10000]
        random() < 0.5,                               -- IsGpsValid           boolean
        s."MonitoringPostId"
    FROM public."Sensor" s
    JOIN public."SensorType" st ON st."Id" = s."SensorTypeId"
    CROSS JOIN generate_series(1, p_rows) AS g
    WHERE st."SensorTypeName" = 'DSPD';

    -- ---------------------------------------------------------
    -- DustData
    -- ---------------------------------------------------------
    INSERT INTO public."DustData"
        ("SensorId", "ReceivedAt", "DataTimestamp",
         "PM10Act", "PM25Act", "PM1Act", "PM10AWG", "PM25AWG", "PM1AWG",
         "FlowProbe", "TemperatureProbe", "HumidityProbe", "LaserStatus",
         "SupplyVoltage", "MonitoringPostId")
    SELECT
        s."Id",
        now(),
        now() - (g * interval '1 second'),
        round((random() * 500)::numeric, 2),          -- PM10Act          [0, 500]
        round((random() * 500)::numeric, 2),          -- PM25Act          [0, 500]
        round((random() * 500)::numeric, 2),          -- PM1Act           [0, 500]
        round((random() * 500)::numeric, 2),          -- PM10AWG          [0, 500]
        round((random() * 500)::numeric, 2),          -- PM25AWG          [0, 500]
        round((random() * 500)::numeric, 2),          -- PM1AWG           [0, 500]
        round((random() * 10)::numeric, 2),           -- FlowProbe        [0, 10]
        round((random() * 100 - 40)::numeric, 2),     -- TemperatureProbe [-40, 60]
        round((random() * 100)::numeric, 2),          -- HumidityProbe    [0, 100]
        (random() * 5)::int,                          -- LaserStatus      {0..4}
        round((random() * 30)::numeric, 2),           -- SupplyVoltage    [0, 30]
        s."MonitoringPostId"
    FROM public."Sensor" s
    JOIN public."SensorType" st ON st."Id" = s."SensorTypeId"
    CROSS JOIN generate_series(1, p_rows) AS g
    WHERE st."SensorTypeName" = 'DUST';

    -- ---------------------------------------------------------
    -- IWSData
    -- ---------------------------------------------------------
    INSERT INTO public."IWSData"
        ("SensorId", "ReceivedAt", "DataTimestamp",
         "EnvTemperature", "Humidity", "DewPoint", "PressureHPa", "PressureQNHHPa",
         "PressureMmHg", "WindSpeed", "WindDirection", "WindVSound",
         "PrecipitationType", "PrecipitationIntensity", "PrecipitationQuantity",
         "PrecipitationElapsed", "PrecipitationPeriod", "CO2Level", "SupplyVoltage",
         "Latitude", "Longitude", "Altitude", "KSP", "GPSSpeed", "AccelerationStDev",
         "Roll", "Pitch", "WeAreFine", "MonitoringPostId")
    SELECT
        s."Id",
        now(),
        now() - (g * interval '1 second'),
        round((random() * 90 - 40)::numeric, 2),      -- EnvTemperature       [-40, 50]
        round((random() * 100)::numeric, 2),          -- Humidity             [0, 100]
        round((random() * 70 - 40)::numeric, 2),      -- DewPoint             [-40, 30]
        round((random() * 200 + 900)::numeric, 2),    -- PressureHPa          [900, 1100]
        round((random() * 200 + 900)::numeric, 2),    -- PressureQNHHPa       [900, 1100]
        round((random() * 100 + 700)::numeric, 2),    -- PressureMmHg         [700, 800]
        round((random() * 40)::numeric, 2),           -- WindSpeed            [0, 40]
        round((random() * 360)::numeric, 2),          -- WindDirection        [0, 360]
        round((random() * 40)::numeric, 2),           -- WindVSound           [0, 40]
        (random() * 5)::int,                          -- PrecipitationType    {0..4}
        round((random() * 50)::numeric, 2),           -- PrecipitationIntensity [0, 50]
        round((random() * 100)::numeric, 2),          -- PrecipitationQuantity  [0, 100]
        (random() * 3600)::int,                       -- PrecipitationElapsed [0, 3600]
        (random() * 3600)::int,                       -- PrecipitationPeriod  [0, 3600]
        round((random() * 1700 + 300)::numeric, 2),   -- CO2Level             [300, 2000]
        round((random() * 20 + 10)::numeric, 1),      -- SupplyVoltage        [10, 30]
        round((random() * 1 + 55)::numeric, 6),       -- Latitude             [55, 56]
        round((random() * 1 + 37)::numeric, 6),       -- Longitude            [37, 38]
        round((random() * 500)::numeric, 2),          -- Altitude             [0, 500]
        (random() * 100)::int,                        -- KSP                  [0, 99]
        round((random() * 120)::numeric, 1),          -- GPSSpeed             [0, 120]
        round((random() * 10)::numeric, 2),           -- AccelerationStDev    [0, 10]
        round((random() * 360 - 180)::numeric, 1),    -- Roll                 [-180, 180]
        round((random() * 180 - 90)::numeric, 1),     -- Pitch                [-90, 90]
        (random() * 2)::int,                          -- WeAreFine            {0, 1}
        s."MonitoringPostId"
    FROM public."Sensor" s
    JOIN public."SensorType" st ON st."Id" = s."SensorTypeId"
    CROSS JOIN generate_series(1, p_rows) AS g
    WHERE st."SensorTypeName" = 'IWS';

    -- ---------------------------------------------------------
    -- MUEKSData
    -- ---------------------------------------------------------
    INSERT INTO public."MUEKSData"
        ("SensorId", "ReceivedAt", "DataTimestamp",
         "TemperatureBox", "UPowerIn12B", "UOut12B", "IOut12B", "IOut48B",
         "UAkb", "IAkb", "Sens220B", "WhAkb", "VisibleRange", "DoorStatus",
         "TdsH", "TdsTds", "TkosaT1", "TkosaT3", "MonitoringPostId",
         "OwenCh1", "OwenCh2", "TempExt")
    SELECT
        s."Id",
        now(),
        now() - (g * interval '1 second'),
        round((random() * 100 - 40)::numeric, 2),     -- TemperatureBox  [-40, 60]
        round((random() * 5 + 10)::numeric, 2),       -- UPowerIn12B     [10, 15]
        round((random() * 5 + 10)::numeric, 2),       -- UOut12B         [10, 15]
        round((random() * 20)::numeric, 2),           -- IOut12B         [0, 20]
        round((random() * 10)::numeric, 2),           -- IOut48B         [0, 10]
        round((random() * 5 + 10)::numeric, 2),       -- UAkb            [10, 15]
        round((random() * 20)::numeric, 2),           -- IAkb            [0, 20]
        (random() * 2)::int,                          -- Sens220B        {0, 1}
        round((random() * 10000)::numeric, 2),        -- WhAkb           [0, 10000]
        round((random() * 1990 + 10)::numeric, 2),    -- VisibleRange    [10, 2000]
        (random() * 2)::int,                          -- DoorStatus      {0, 1}
        upper(substr(md5(random()::text), 1, 8)),     -- TdsH
        upper(substr(md5(random()::text), 1, 8)),     -- TdsTds
        upper(substr(md5(random()::text), 1, 8)),     -- TkosaT1
        upper(substr(md5(random()::text), 1, 8)),     -- TkosaT3
        s."MonitoringPostId",
        round((random() * 200 - 50)::numeric, 2),     -- OwenCh1         [-50, 150]
        round((random() * 200 - 50)::numeric, 2),     -- OwenCh2         [-50, 150]
        round((random() * 100 - 40)::numeric, 2)      -- TempExt         [-40, 60]
    FROM public."Sensor" s
    JOIN public."SensorType" st ON st."Id" = s."SensorTypeId"
    CROSS JOIN generate_series(1, p_rows) AS g
    WHERE st."SensorTypeName" = 'MUEKS';
END;
$$;
