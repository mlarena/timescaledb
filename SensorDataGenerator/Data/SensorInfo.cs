namespace SensorDataGenerator.Data;

/// <summary>
/// A single sensor loaded from the reference tables (Sensor + SensorType).
/// </summary>
public sealed class SensorInfo
{
    public int Id { get; init; }

    public int? MonitoringPostId { get; init; }

    public string SensorTypeName { get; init; } = string.Empty;
}
