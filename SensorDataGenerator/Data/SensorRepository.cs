using Npgsql;

namespace SensorDataGenerator.Data;

/// <summary>
/// Reads sensors from the reference tables. The reference tables are expected
/// to be filled beforehand; this repository never creates or modifies them.
/// </summary>
public sealed class SensorRepository
{
    private const string LoadAllSensorsSql = """
        SELECT s."Id", s."MonitoringPostId", st."SensorTypeName"
        FROM public."Sensor" s
        JOIN public."SensorType" st ON st."Id" = s."SensorTypeId"
        ORDER BY s."Id";
        """;

    private const string LoadActiveSensorsSql = """
        SELECT s."Id", s."MonitoringPostId", st."SensorTypeName"
        FROM public."Sensor" s
        JOIN public."SensorType" st ON st."Id" = s."SensorTypeId"
        WHERE s."IsActive" = true
        ORDER BY s."Id";
        """;

    private readonly NpgsqlDataSource _dataSource;

    public SensorRepository(NpgsqlDataSource dataSource)
    {
        _dataSource = dataSource;
    }

    public async Task<IReadOnlyList<SensorInfo>> LoadSensorsAsync(
        bool activeOnly,
        CancellationToken cancellationToken)
    {
        var sql = activeOnly ? LoadActiveSensorsSql : LoadAllSensorsSql;

        var sensors = new List<SensorInfo>();
        await using var command = _dataSource.CreateCommand(sql);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            sensors.Add(new SensorInfo
            {
                Id = reader.GetInt32(0),
                MonitoringPostId = reader.IsDBNull(1) ? null : reader.GetInt32(1),
                SensorTypeName = reader.GetString(2)
            });
        }

        return sensors;
    }
}
