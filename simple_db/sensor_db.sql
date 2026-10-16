

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
    ('MUEKS', 'Модуль управления электроснабжением', NOW()),
    ('RELAY', 'Релейный модуль', NOW())
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
     1,
     'DOV_01',
     'Датчик оптической видимости',
     'http://192.168.1.10/json',
     true),

    ((SELECT "Id" FROM public."SensorType" WHERE "SensorTypeName" = 'MUEKS'),
     1,
     'MUEKS_01',
     'Датчик температуры грунта',
     'http://192.168.1.14/json',
     true),

    ((SELECT "Id" FROM public."SensorType" WHERE "SensorTypeName" = 'IWS'),
     1,
     'IWS_01',
     'Датчик комплекный параметров атмосферы',
     'http://192.168.1.16/json',
     true),

    ((SELECT "Id" FROM public."SensorType" WHERE "SensorTypeName" = 'DUST'),
     1,
     'DUST_01',
     'Датчик концентрации пыли',
     'http://192.168.1.11/json',
     false),

    ((SELECT "Id" FROM public."SensorType" WHERE "SensorTypeName" = 'DSPD'),
     1,
     'DSPD_01',
     'Датчик состояния дорожного полотна 1',
     'http://192.168.1.9/json',
     true),

     ((SELECT "Id" FROM public."SensorType" WHERE "SensorTypeName" = 'DSPD'),
     1,
     'DSPD_02',
     'Датчик состояния дорожного полотна 2',
     'http://192.168.1.8/json',
     true)
) AS v("SensorTypeId", "MonitoringPostId", "SerialNumber", "EndPointsName", "Url", "IsActive")
WHERE NOT EXISTS (
    SELECT 1 FROM public."Sensor" WHERE "MonitoringPostId" = 1
);



CREATE TABLE public."SensorType" (
	"Id" serial4 NOT NULL,
	"SensorTypeName" varchar(20) NOT NULL,
	"Description" text NOT NULL,
	"CreatedAt" timestamptz DEFAULT now() NOT NULL,
	CONSTRAINT "SensorType_SensorTypeName_key" UNIQUE ("SensorTypeName"),
	CONSTRAINT "SensorType_pkey" PRIMARY KEY ("Id")
);

INSERT INTO public."SensorType" 
    ("SensorTypeName", "Description", "CreatedAt")
VALUES
    ('DSPD',  'Датчик состояния дорожного полотна', NOW()),
    ('IWS',   'Датчик комплекный параметров атмосферы', NOW()),
    ('DOV',   'Датчик оптической видимости', NOW()),    
    ('DUST',  'Датчик концентрации пыли', NOW()),
    ('MUEKS', 'Модуль управления электроснабжением', NOW()),
    ('RELAY', 'Релейный модуль', NOW())
ON CONFLICT ("SensorTypeName") DO NOTHING;