using Npgsql;
using SensorDataGenerator.Generation;

namespace SensorDataGenerator.Data;

/// <summary>
/// Writes a single reading into the data table that matches the sensor type.
/// </summary>
public sealed class SensorDataWriter
{
    private readonly NpgsqlDataSource _dataSource;

    public SensorDataWriter(NpgsqlDataSource dataSource)
    {
        _dataSource = dataSource;
    }

    public Task WriteAsync(SensorInfo sensor, DateTime timestampUtc, CancellationToken cancellationToken) =>
        sensor.SensorTypeName switch
        {
            "DOV" => WriteDovAsync(sensor, timestampUtc, cancellationToken),
            "DSPD" => WriteDspdAsync(sensor, timestampUtc, cancellationToken),
            "DUST" => WriteDustAsync(sensor, timestampUtc, cancellationToken),
            "IWS" => WriteIwsAsync(sensor, timestampUtc, cancellationToken),
            "MUEKS" => WriteMueksAsync(sensor, timestampUtc, cancellationToken),
            _ => Task.CompletedTask
        };

    private async Task WriteDovAsync(SensorInfo sensor, DateTime timestampUtc, CancellationToken cancellationToken)
    {
        const string sql = """
            INSERT INTO public."DOVData"
                ("SensorId", "DataTimestamp", "VisibleRange", "BrightFlag", "MonitoringPostId")
            VALUES
                (@sensorId, @dataTimestamp, @visibleRange, @brightFlag, @monitoringPostId);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        command.Parameters.AddWithValue("sensorId", sensor.Id);
        command.Parameters.AddWithValue("dataTimestamp", timestampUtc);
        command.Parameters.AddWithValue("visibleRange", RandomValues.Decimal(10, 2000, 2));
        command.Parameters.AddWithValue("brightFlag", RandomValues.Int(0, 2));
        command.Parameters.AddWithValue("monitoringPostId", (object?)sensor.MonitoringPostId ?? DBNull.Value);

        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private async Task WriteDspdAsync(SensorInfo sensor, DateTime timestampUtc, CancellationToken cancellationToken)
    {
        const string sql = """
            INSERT INTO public."DSPDData"
                ("SensorId", "DataTimestamp", "Grip", "Shake", "UPower", "TemperatureCase",
                 "TemperatureRoad", "HeightH2O", "HeightIce", "HeightSnow", "PercentICE", "PercentPGM",
                 "RoadStatus", "AngleToRoad", "TemperatureFreezePGM", "NeedCalibration",
                 "GPSLatitude", "GPSLongitude", "DistanceToSurface", "IsGpsValid", "MonitoringPostId")
            VALUES
                (@sensorId, @dataTimestamp, @grip, @shake, @uPower, @temperatureCase,
                 @temperatureRoad, @heightH2O, @heightIce, @heightSnow, @percentIce, @percentPgm,
                 @roadStatus, @angleToRoad, @temperatureFreezePgm, @needCalibration,
                 @gpsLatitude, @gpsLongitude, @distanceToSurface, @isGpsValid, @monitoringPostId);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        command.Parameters.AddWithValue("sensorId", sensor.Id);
        command.Parameters.AddWithValue("dataTimestamp", timestampUtc);
        command.Parameters.AddWithValue("grip", RandomValues.Decimal(0, 1, 2));
        command.Parameters.AddWithValue("shake", RandomValues.Decimal(0, 100, 2));
        command.Parameters.AddWithValue("uPower", RandomValues.Decimal(10, 14, 2));
        command.Parameters.AddWithValue("temperatureCase", RandomValues.Decimal(-40, 60, 2));
        command.Parameters.AddWithValue("temperatureRoad", RandomValues.Decimal(-40, 60, 2));
        command.Parameters.AddWithValue("heightH2O", RandomValues.Decimal(0, 5, 2));
        command.Parameters.AddWithValue("heightIce", RandomValues.Decimal(0, 5, 2));
        command.Parameters.AddWithValue("heightSnow", RandomValues.Decimal(0, 20, 2));
        command.Parameters.AddWithValue("percentIce", RandomValues.Decimal(0, 100, 2));
        command.Parameters.AddWithValue("percentPgm", RandomValues.Decimal(0, 100, 2));
        command.Parameters.AddWithValue("roadStatus", RandomValues.Int(0, 8));
        command.Parameters.AddWithValue("angleToRoad", RandomValues.Decimal(0, 90, 2));
        command.Parameters.AddWithValue("temperatureFreezePgm", RandomValues.Decimal(-60, 0, 2));
        command.Parameters.AddWithValue("needCalibration", RandomValues.Int(0, 2));
        command.Parameters.AddWithValue("gpsLatitude", RandomValues.Decimal(55, 56, 6));
        command.Parameters.AddWithValue("gpsLongitude", RandomValues.Decimal(37, 38, 6));
        command.Parameters.AddWithValue("distanceToSurface", RandomValues.Decimal(0, 10000, 2));
        command.Parameters.AddWithValue("isGpsValid", RandomValues.Bool());
        command.Parameters.AddWithValue("monitoringPostId", (object?)sensor.MonitoringPostId ?? DBNull.Value);

        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private async Task WriteDustAsync(SensorInfo sensor, DateTime timestampUtc, CancellationToken cancellationToken)
    {
        const string sql = """
            INSERT INTO public."DustData"
                ("SensorId", "DataTimestamp", "PM10Act", "PM25Act", "PM1Act", "PM10AWG", "PM25AWG",
                 "PM1AWG", "FlowProbe", "TemperatureProbe", "HumidityProbe", "LaserStatus",
                 "SupplyVoltage", "MonitoringPostId")
            VALUES
                (@sensorId, @dataTimestamp, @pm10Act, @pm25Act, @pm1Act, @pm10Awg, @pm25Awg,
                 @pm1Awg, @flowProbe, @temperatureProbe, @humidityProbe, @laserStatus,
                 @supplyVoltage, @monitoringPostId);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        command.Parameters.AddWithValue("sensorId", sensor.Id);
        command.Parameters.AddWithValue("dataTimestamp", timestampUtc);
        command.Parameters.AddWithValue("pm10Act", RandomValues.Decimal(0, 500, 2));
        command.Parameters.AddWithValue("pm25Act", RandomValues.Decimal(0, 500, 2));
        command.Parameters.AddWithValue("pm1Act", RandomValues.Decimal(0, 500, 2));
        command.Parameters.AddWithValue("pm10Awg", RandomValues.Decimal(0, 500, 2));
        command.Parameters.AddWithValue("pm25Awg", RandomValues.Decimal(0, 500, 2));
        command.Parameters.AddWithValue("pm1Awg", RandomValues.Decimal(0, 500, 2));
        command.Parameters.AddWithValue("flowProbe", RandomValues.Decimal(0, 10, 2));
        command.Parameters.AddWithValue("temperatureProbe", RandomValues.Decimal(-40, 60, 2));
        command.Parameters.AddWithValue("humidityProbe", RandomValues.Decimal(0, 100, 2));
        command.Parameters.AddWithValue("laserStatus", RandomValues.Int(0, 5));
        command.Parameters.AddWithValue("supplyVoltage", RandomValues.Decimal(0, 30, 2));
        command.Parameters.AddWithValue("monitoringPostId", (object?)sensor.MonitoringPostId ?? DBNull.Value);

        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private async Task WriteIwsAsync(SensorInfo sensor, DateTime timestampUtc, CancellationToken cancellationToken)
    {
        const string sql = """
            INSERT INTO public."IWSData"
                ("SensorId", "DataTimestamp", "EnvTemperature", "Humidity", "DewPoint", "PressureHPa",
                 "PressureQNHHPa", "PressureMmHg", "WindSpeed", "WindDirection", "WindVSound",
                 "PrecipitationType", "PrecipitationIntensity", "PrecipitationQuantity",
                 "PrecipitationElapsed", "PrecipitationPeriod", "CO2Level", "SupplyVoltage",
                 "Latitude", "Longitude", "Altitude", "KSP", "GPSSpeed", "AccelerationStDev",
                 "Roll", "Pitch", "WeAreFine", "MonitoringPostId")
            VALUES
                (@sensorId, @dataTimestamp, @envTemperature, @humidity, @dewPoint, @pressureHPa,
                 @pressureQnhHPa, @pressureMmHg, @windSpeed, @windDirection, @windVSound,
                 @precipitationType, @precipitationIntensity, @precipitationQuantity,
                 @precipitationElapsed, @precipitationPeriod, @co2Level, @supplyVoltage,
                 @latitude, @longitude, @altitude, @ksp, @gpsSpeed, @accelerationStDev,
                 @roll, @pitch, @weAreFine, @monitoringPostId);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        command.Parameters.AddWithValue("sensorId", sensor.Id);
        command.Parameters.AddWithValue("dataTimestamp", timestampUtc);
        command.Parameters.AddWithValue("envTemperature", RandomValues.Decimal(-40, 50, 2));
        command.Parameters.AddWithValue("humidity", RandomValues.Decimal(0, 100, 2));
        command.Parameters.AddWithValue("dewPoint", RandomValues.Decimal(-40, 30, 2));
        command.Parameters.AddWithValue("pressureHPa", RandomValues.Decimal(900, 1100, 2));
        command.Parameters.AddWithValue("pressureQnhHPa", RandomValues.Decimal(900, 1100, 2));
        command.Parameters.AddWithValue("pressureMmHg", RandomValues.Decimal(700, 800, 2));
        command.Parameters.AddWithValue("windSpeed", RandomValues.Decimal(0, 40, 2));
        command.Parameters.AddWithValue("windDirection", RandomValues.Decimal(0, 360, 2));
        command.Parameters.AddWithValue("windVSound", RandomValues.Decimal(0, 40, 2));
        command.Parameters.AddWithValue("precipitationType", RandomValues.Int(0, 5));
        command.Parameters.AddWithValue("precipitationIntensity", RandomValues.Decimal(0, 50, 2));
        command.Parameters.AddWithValue("precipitationQuantity", RandomValues.Decimal(0, 100, 2));
        command.Parameters.AddWithValue("precipitationElapsed", RandomValues.Int(0, 3600));
        command.Parameters.AddWithValue("precipitationPeriod", RandomValues.Int(0, 3600));
        command.Parameters.AddWithValue("co2Level", RandomValues.Decimal(300, 2000, 2));
        command.Parameters.AddWithValue("supplyVoltage", RandomValues.Decimal(10, 30, 1));
        command.Parameters.AddWithValue("latitude", RandomValues.Decimal(55, 56, 6));
        command.Parameters.AddWithValue("longitude", RandomValues.Decimal(37, 38, 6));
        command.Parameters.AddWithValue("altitude", RandomValues.Decimal(0, 500, 2));
        command.Parameters.AddWithValue("ksp", RandomValues.Int(0, 100));
        command.Parameters.AddWithValue("gpsSpeed", RandomValues.Decimal(0, 120, 1));
        command.Parameters.AddWithValue("accelerationStDev", RandomValues.Decimal(0, 10, 2));
        command.Parameters.AddWithValue("roll", RandomValues.Decimal(-180, 180, 1));
        command.Parameters.AddWithValue("pitch", RandomValues.Decimal(-90, 90, 1));
        command.Parameters.AddWithValue("weAreFine", RandomValues.Int(0, 2));
        command.Parameters.AddWithValue("monitoringPostId", (object?)sensor.MonitoringPostId ?? DBNull.Value);

        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private async Task WriteMueksAsync(SensorInfo sensor, DateTime timestampUtc, CancellationToken cancellationToken)
    {
        const string sql = """
            INSERT INTO public."MUEKSData"
                ("SensorId", "DataTimestamp", "TemperatureBox", "UPowerIn12B", "UOut12B", "IOut12B",
                 "IOut48B", "UAkb", "IAkb", "Sens220B", "WhAkb", "VisibleRange", "DoorStatus",
                 "TdsH", "TdsTds", "TkosaT1", "TkosaT3", "MonitoringPostId",
                 "OwenCh1", "OwenCh2", "TempExt")
            VALUES
                (@sensorId, @dataTimestamp, @temperatureBox, @uPowerIn12B, @uOut12B, @iOut12B,
                 @iOut48B, @uAkb, @iAkb, @sens220B, @whAkb, @visibleRange, @doorStatus,
                 @tdsH, @tdsTds, @tkosaT1, @tkosaT3, @monitoringPostId,
                 @owenCh1, @owenCh2, @tempExt);
            """;

        await using var command = _dataSource.CreateCommand(sql);
        command.Parameters.AddWithValue("sensorId", sensor.Id);
        command.Parameters.AddWithValue("dataTimestamp", timestampUtc);
        command.Parameters.AddWithValue("temperatureBox", RandomValues.Decimal(-40, 60, 2));
        command.Parameters.AddWithValue("uPowerIn12B", RandomValues.Decimal(10, 15, 2));
        command.Parameters.AddWithValue("uOut12B", RandomValues.Decimal(10, 15, 2));
        command.Parameters.AddWithValue("iOut12B", RandomValues.Decimal(0, 20, 2));
        command.Parameters.AddWithValue("iOut48B", RandomValues.Decimal(0, 10, 2));
        command.Parameters.AddWithValue("uAkb", RandomValues.Decimal(10, 15, 2));
        command.Parameters.AddWithValue("iAkb", RandomValues.Decimal(0, 20, 2));
        command.Parameters.AddWithValue("sens220B", RandomValues.Int(0, 2));
        command.Parameters.AddWithValue("whAkb", RandomValues.Decimal(0, 10000, 2));
        command.Parameters.AddWithValue("visibleRange", RandomValues.Decimal(10, 2000, 2));
        command.Parameters.AddWithValue("doorStatus", RandomValues.Int(0, 2));
        command.Parameters.AddWithValue("tdsH", RandomValues.Code(8));
        command.Parameters.AddWithValue("tdsTds", RandomValues.Code(8));
        command.Parameters.AddWithValue("tkosaT1", RandomValues.Code(8));
        command.Parameters.AddWithValue("tkosaT3", RandomValues.Code(8));
        command.Parameters.AddWithValue("monitoringPostId", (object?)sensor.MonitoringPostId ?? DBNull.Value);
        command.Parameters.AddWithValue("owenCh1", RandomValues.Decimal(-50, 150, 2));
        command.Parameters.AddWithValue("owenCh2", RandomValues.Decimal(-50, 150, 2));
        command.Parameters.AddWithValue("tempExt", RandomValues.Decimal(-40, 60, 2));

        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}
