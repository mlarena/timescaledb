using Microsoft.Extensions.Configuration;
using Npgsql;
using SensorDataGenerator.Data;

var configuration = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: false)
    .AddEnvironmentVariables()
    .Build();

var connectionString = configuration.GetConnectionString("Postgres");
if (string.IsNullOrWhiteSpace(connectionString))
{
    Console.Error.WriteLine(
        "Connection string 'ConnectionStrings:Postgres' is not configured in appsettings.json.");
    return 1;
}

var intervalSeconds = configuration.GetValue("Generator:IntervalSeconds", 1);
if (intervalSeconds <= 0)
{
    intervalSeconds = 1;
}

var activeSensorsOnly = configuration.GetValue("Generator:ActiveSensorsOnly", false);

using var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, eventArgs) =>
{
    eventArgs.Cancel = true;
    cts.Cancel();
};

await using var dataSource = NpgsqlDataSource.Create(connectionString);
var sensorRepository = new SensorRepository(dataSource);
var writer = new SensorDataWriter(dataSource);

IReadOnlyList<SensorInfo> sensors;
try
{
    sensors = await sensorRepository.LoadSensorsAsync(activeSensorsOnly, cts.Token);
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Failed to load sensors: {ex.Message}");
    return 1;
}

if (sensors.Count == 0)
{
    Console.Error.WriteLine(
        "No sensors found. Make sure the reference tables (SensorType, MonitoringPost, Sensor) are filled.");
    return 1;
}

Console.WriteLine(
    $"Loaded {sensors.Count} sensor(s). Writing one reading per sensor every {intervalSeconds}s. Press Ctrl+C to stop.");

using var timer = new PeriodicTimer(TimeSpan.FromSeconds(intervalSeconds));
try
{
    while (await timer.WaitForNextTickAsync(cts.Token))
    {
        var timestampUtc = DateTime.UtcNow;

        foreach (var sensor in sensors)
        {
            try
            {
                await writer.WriteAsync(sensor, timestampUtc, cts.Token);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(
                    $"[{DateTime.Now:HH:mm:ss}] Sensor {sensor.Id} ({sensor.SensorTypeName}): {ex.Message}");
            }
        }
    }
}
catch (OperationCanceledException)
{
    // Graceful shutdown on Ctrl+C.
}

Console.WriteLine("Stopped.");
return 0;
