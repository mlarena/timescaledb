

CREATE TABLE public."SensorType" (
	"Id" serial4 NOT NULL,
	"SensorTypeName" varchar(20) NOT NULL,
	"Description" text NOT NULL,
	"CreatedAt" timestamptz DEFAULT now() NOT NULL,
	CONSTRAINT "SensorType_pkey" PRIMARY KEY ("Id"),
	CONSTRAINT "SensorType_SensorTypeName_key" UNIQUE ("SensorTypeName")
);

INSERT INTO public."SensorType"
    ("SensorTypeName", "Description", "CreatedAt")
VALUES
    ('DSPD',  'Датчик состояния дорожного полотна', NOW()),
    ('IWS',   'Датчик комплекный параметров атмосферы', NOW()),
    ('DOV',   'Датчик оптической видимости', NOW()),
    ('DUST',  'Датчик концентрации пыли', NOW()),
    ('MUEKS', 'Модуль управления электроснабжением', NOW())
ON CONFLICT ("SensorTypeName") DO NOTHING;



CREATE TABLE public."MonitoringPost" (
	"Id" serial4 NOT NULL,
	"Name" varchar(255) NOT NULL,
	"Description" text NULL,
	"Longitude" float8 NULL,
	"Latitude" float8 NULL,
	"IsMobile" bool DEFAULT false NOT NULL,
	"IsActive" bool DEFAULT true NOT NULL,
	"CreatedAt" timestamptz DEFAULT now() NOT NULL,
	"UpdatedAt" timestamptz DEFAULT now() NOT NULL,
	"Address" text NULL,
	"PollingIntervalSeconds" int4 DEFAULT 60 NOT NULL,
	"LastPolledAt" timestamptz NULL,
	CONSTRAINT "MonitoringPost_pkey" PRIMARY KEY ("Id"),
	CONSTRAINT "MonitoringPost_Name_key" UNIQUE ("Name")
);
INSERT INTO public."MonitoringPost"
(
    "Name", "Description", "Longitude", "Latitude", "IsMobile", "IsActive", "CreatedAt", "UpdatedAt", "Address", "PollingIntervalSeconds", "LastPolledAt"
)
SELECT
    'АДМС', 'Автоматическая дорожная метео станция', 37.485538, 55.862116, false, true, now(), now(), 'г. Москва. ул. Лавочкина 19', 60, null
WHERE NOT EXISTS (
    SELECT 1 FROM public."MonitoringPost" WHERE "Name" = 'АДМС'
);



CREATE TABLE public."Sensor" (
	"Id" serial4 NOT NULL,
	"SensorTypeId" int4 NOT NULL,
	"MonitoringPostId" int4 NULL,
	"Longitude" float8 NULL,
	"Latitude" float8 NULL,
	"SerialNumber" varchar(64) NOT NULL,
	"IsSerialNumberLocked" bool DEFAULT false NOT NULL,
	"EndPointsName" varchar(255) NOT NULL,
	"Url" text NOT NULL,
	"LastActivityUTC" timestamptz NULL,
	"CreatedAt" timestamptz DEFAULT now() NOT NULL,
	"IsActive" bool DEFAULT true NOT NULL,
	CONSTRAINT "Sensor_pkey" PRIMARY KEY ("Id"),
	CONSTRAINT "Sensor_SensorTypeId_fkey" FOREIGN KEY ("SensorTypeId") REFERENCES public."SensorType" ("Id"),
	CONSTRAINT "Sensor_MonitoringPostId_fkey" FOREIGN KEY ("MonitoringPostId") REFERENCES public."MonitoringPost" ("Id"),
	CONSTRAINT "Sensor_SerialNumber_key" UNIQUE ("SerialNumber")
);

INSERT INTO public."Sensor"
    ("SensorTypeId",
     "MonitoringPostId",
     "SerialNumber",
     "EndPointsName",
     "Url",
     "IsActive")
SELECT * FROM (
    VALUES
     ((SELECT "Id" FROM public."SensorType" WHERE "SensorTypeName" = 'DOV'),
     (SELECT "Id" FROM public."MonitoringPost" WHERE "Name" = 'АДМС'),
     'DOV_01',
     'Датчик оптической видимости',
     'http://192.168.1.10/json',
     true),

    ((SELECT "Id" FROM public."SensorType" WHERE "SensorTypeName" = 'MUEKS'),
     (SELECT "Id" FROM public."MonitoringPost" WHERE "Name" = 'АДМС'),
     'MUEKS_01',
     'Датчик температуры грунта',
     'http://192.168.1.14/json',
     true),

    ((SELECT "Id" FROM public."SensorType" WHERE "SensorTypeName" = 'IWS'),
     (SELECT "Id" FROM public."MonitoringPost" WHERE "Name" = 'АДМС'),
     'IWS_01',
     'Датчик комплекный параметров атмосферы',
     'http://192.168.1.16/json',
     true),

    ((SELECT "Id" FROM public."SensorType" WHERE "SensorTypeName" = 'DUST'),
     (SELECT "Id" FROM public."MonitoringPost" WHERE "Name" = 'АДМС'),
     'DUST_01',
     'Датчик концентрации пыли',
     'http://192.168.1.11/json',
     false),

    ((SELECT "Id" FROM public."SensorType" WHERE "SensorTypeName" = 'DSPD'),
     (SELECT "Id" FROM public."MonitoringPost" WHERE "Name" = 'АДМС'),
     'DSPD_01',
     'Датчик состояния дорожного полотна 1',
     'http://192.168.1.9/json',
     true)
) AS v("SensorTypeId", "MonitoringPostId", "SerialNumber", "EndPointsName", "Url", "IsActive")
WHERE NOT EXISTS (
    SELECT 1 FROM public."Sensor" s WHERE s."SerialNumber" = v."SerialNumber"
);



-- ============================================================
-- Indexes
-- ============================================================
-- Foreign keys (PostgreSQL does not create indexes for them automatically)
CREATE INDEX "IX_Sensor_SensorTypeId"     ON public."Sensor" ("SensorTypeId");
CREATE INDEX "IX_Sensor_MonitoringPostId" ON public."Sensor" ("MonitoringPostId");

-- Common lookups
CREATE INDEX "IX_Sensor_LastActivityUTC"  ON public."Sensor" ("LastActivityUTC");
CREATE INDEX "IX_Sensor_MonitoringPostId_IsActive" ON public."Sensor" ("MonitoringPostId", "IsActive");
CREATE INDEX "IX_MonitoringPost_IsActive" ON public."MonitoringPost" ("IsActive");



CREATE TABLE public."DOVData" (
	"Id" serial4 NOT NULL,
	"SensorId" int4 NOT NULL,
	"ReceivedAt" timestamptz DEFAULT now() NOT NULL,
	"DataTimestamp" timestamptz NOT NULL,
	"VisibleRange" numeric(10, 2) NULL,
	"BrightFlag" int4 NULL,
	"MonitoringPostId" int4 NULL,
	CONSTRAINT "DOVData_pkey" PRIMARY KEY ("Id"),
	CONSTRAINT "DOVData_SensorId_fkey" FOREIGN KEY ("SensorId") REFERENCES public."Sensor" ("Id"),
	CONSTRAINT "DOVData_MonitoringPostId_fkey" FOREIGN KEY ("MonitoringPostId") REFERENCES public."MonitoringPost" ("Id")
);


CREATE TABLE public."DSPDData" (
	"Id" serial4 NOT NULL,
	"SensorId" int4 NOT NULL,
	"ReceivedAt" timestamptz DEFAULT now() NOT NULL,
	"DataTimestamp" timestamptz NOT NULL,
	"Grip" numeric(5, 2) NULL,
	"Shake" numeric(5, 2) NULL,
	"UPower" numeric(5, 2) NULL,
	"TemperatureCase" numeric(5, 2) NULL,
	"TemperatureRoad" numeric(5, 2) NULL,
	"HeightH2O" numeric(5, 2) NULL,
	"HeightIce" numeric(5, 2) NULL,
	"HeightSnow" numeric(5, 2) NULL,
	"PercentICE" numeric(5, 2) NULL,
	"PercentPGM" numeric(5, 2) NULL,
	"RoadStatus" int4 NULL,
	"AngleToRoad" numeric(5, 2) NULL,
	"TemperatureFreezePGM" numeric(5, 2) NULL,
	"NeedCalibration" int4 NULL,
	"GPSLatitude" numeric(10, 6) NULL,
	"GPSLongitude" numeric(10, 6) NULL,
	"DistanceToSurface" numeric(12, 2) NULL,
	"IsGpsValid" bool DEFAULT true NULL,
	"MonitoringPostId" int4 NULL,
	CONSTRAINT "DSPDData_pkey" PRIMARY KEY ("Id"),
	CONSTRAINT "DSPDData_SensorId_fkey" FOREIGN KEY ("SensorId") REFERENCES public."Sensor" ("Id"),
	CONSTRAINT "DSPDData_MonitoringPostId_fkey" FOREIGN KEY ("MonitoringPostId") REFERENCES public."MonitoringPost" ("Id")
);


CREATE TABLE public."DustData" (
	"Id" serial4 NOT NULL,
	"SensorId" int4 NOT NULL,
	"ReceivedAt" timestamptz DEFAULT now() NOT NULL,
	"DataTimestamp" timestamptz NOT NULL,
	"PM10Act" numeric(10, 2) NULL,
	"PM25Act" numeric(10, 2) NULL,
	"PM1Act" numeric(10, 2) NULL,
	"PM10AWG" numeric(10, 2) NULL,
	"PM25AWG" numeric(10, 2) NULL,
	"PM1AWG" numeric(10, 2) NULL,
	"FlowProbe" numeric(10, 2) NULL,
	"TemperatureProbe" numeric(10, 2) NULL,
	"HumidityProbe" numeric(10, 2) NULL,
	"LaserStatus" int4 NULL,
	"SupplyVoltage" numeric(10, 2) NULL,
	"MonitoringPostId" int4 NULL,
	CONSTRAINT "DustData_pkey" PRIMARY KEY ("Id"),
	CONSTRAINT "DustData_SensorId_fkey" FOREIGN KEY ("SensorId") REFERENCES public."Sensor" ("Id"),
	CONSTRAINT "DustData_MonitoringPostId_fkey" FOREIGN KEY ("MonitoringPostId") REFERENCES public."MonitoringPost" ("Id")
);

CREATE TABLE public."IWSData" (
	"Id" serial4 NOT NULL,
	"SensorId" int4 NOT NULL,
	"ReceivedAt" timestamptz DEFAULT now() NOT NULL,
	"DataTimestamp" timestamptz NOT NULL,
	"EnvTemperature" numeric(5, 2) NULL,
	"Humidity" numeric(5, 2) NULL,
	"DewPoint" numeric(5, 2) NULL,
	"PressureHPa" numeric(7, 2) NULL,
	"PressureQNHHPa" numeric(7, 2) NULL,
	"PressureMmHg" numeric(7, 2) NULL,
	"WindSpeed" numeric(5, 2) NULL,
	"WindDirection" numeric(6, 2) NULL,
	"WindVSound" numeric(6, 2) NULL,
	"PrecipitationType" int4 NULL,
	"PrecipitationIntensity" numeric(5, 2) NULL,
	"PrecipitationQuantity" numeric(5, 2) NULL,
	"PrecipitationElapsed" int4 NULL,
	"PrecipitationPeriod" int4 NULL,
	"CO2Level" numeric(6, 2) NULL,
	"SupplyVoltage" numeric(5, 1) NULL,
	"Latitude" numeric(10, 6) NULL,
	"Longitude" numeric(10, 6) NULL,
	"Altitude" numeric(7, 2) NULL,
	"KSP" int4 NULL,
	"GPSSpeed" numeric(5, 1) NULL,
	"AccelerationStDev" numeric(5, 2) NULL,
	"Roll" numeric(5, 1) NULL,
	"Pitch" numeric(5, 1) NULL,
	"WeAreFine" int4 NULL,
	"MonitoringPostId" int4 NULL,
	CONSTRAINT "IWSData_pkey" PRIMARY KEY ("Id"),
	CONSTRAINT "IWSData_SensorId_fkey" FOREIGN KEY ("SensorId") REFERENCES public."Sensor" ("Id"),
	CONSTRAINT "IWSData_MonitoringPostId_fkey" FOREIGN KEY ("MonitoringPostId") REFERENCES public."MonitoringPost" ("Id")
);


CREATE TABLE public."MUEKSData" (
	"Id" serial4 NOT NULL,
	"SensorId" int4 NOT NULL,
	"ReceivedAt" timestamptz DEFAULT now() NOT NULL,
	"DataTimestamp" timestamptz NOT NULL,
	"TemperatureBox" numeric(5, 2) NULL,
	"UPowerIn12B" numeric(5, 2) NULL,
	"UOut12B" numeric(5, 2) NULL,
	"IOut12B" numeric(5, 2) NULL,
	"IOut48B" numeric(5, 2) NULL,
	"UAkb" numeric(5, 2) NULL,
	"IAkb" numeric(5, 2) NULL,
	"Sens220B" int4 NULL,
	"WhAkb" numeric(10, 2) NULL,
	"VisibleRange" numeric(10, 2) NULL,
	"DoorStatus" int4 NULL,
	"TdsH" varchar(50) NULL,
	"TdsTds" varchar(50) NULL,
	"TkosaT1" varchar(50) NULL,
	"TkosaT3" varchar(50) NULL,
	"MonitoringPostId" int4 NULL,
	"OwenCh1" numeric(5, 2) NULL,
	"OwenCh2" numeric(5, 2) NULL,
	"TempExt" numeric(5, 2) NULL,
	CONSTRAINT "MUEKSData_pkey" PRIMARY KEY ("Id"),
	CONSTRAINT "MUEKSData_SensorId_fkey" FOREIGN KEY ("SensorId") REFERENCES public."Sensor" ("Id"),
	CONSTRAINT "MUEKSData_MonitoringPostId_fkey" FOREIGN KEY ("MonitoringPostId") REFERENCES public."MonitoringPost" ("Id")
);



-- ============================================================
-- Indexes for sensor data tables
-- ============================================================
-- Composite index (SensorId, DataTimestamp DESC) covers the most common
-- query pattern: latest readings for a given sensor. The leading SensorId
-- column also serves as the index for the SensorId foreign key.
CREATE INDEX "IX_DOVData_SensorId_DataTimestamp"   ON public."DOVData"   ("SensorId", "DataTimestamp" DESC);
CREATE INDEX "IX_DSPDData_SensorId_DataTimestamp"  ON public."DSPDData"  ("SensorId", "DataTimestamp" DESC);
CREATE INDEX "IX_DustData_SensorId_DataTimestamp"  ON public."DustData"  ("SensorId", "DataTimestamp" DESC);
CREATE INDEX "IX_IWSData_SensorId_DataTimestamp"   ON public."IWSData"   ("SensorId", "DataTimestamp" DESC);
CREATE INDEX "IX_MUEKSData_SensorId_DataTimestamp" ON public."MUEKSData" ("SensorId", "DataTimestamp" DESC);

-- Range scans over the whole table by time
CREATE INDEX "IX_DOVData_DataTimestamp"   ON public."DOVData"   ("DataTimestamp" DESC);
CREATE INDEX "IX_DSPDData_DataTimestamp"  ON public."DSPDData"  ("DataTimestamp" DESC);
CREATE INDEX "IX_DustData_DataTimestamp"  ON public."DustData"  ("DataTimestamp" DESC);
CREATE INDEX "IX_IWSData_DataTimestamp"   ON public."IWSData"   ("DataTimestamp" DESC);
CREATE INDEX "IX_MUEKSData_DataTimestamp" ON public."MUEKSData" ("DataTimestamp" DESC);

-- Foreign keys on the denormalized MonitoringPostId column
CREATE INDEX "IX_DOVData_MonitoringPostId"   ON public."DOVData"   ("MonitoringPostId");
CREATE INDEX "IX_DSPDData_MonitoringPostId"  ON public."DSPDData"  ("MonitoringPostId");
CREATE INDEX "IX_DustData_MonitoringPostId"  ON public."DustData"  ("MonitoringPostId");
CREATE INDEX "IX_IWSData_MonitoringPostId"   ON public."IWSData"   ("MonitoringPostId");
CREATE INDEX "IX_MUEKSData_MonitoringPostId" ON public."MUEKSData" ("MonitoringPostId");




