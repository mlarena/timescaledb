namespace SensorDataGenerator.Generation;

/// <summary>
/// Helpers that produce plausible random telemetry values.
/// </summary>
internal static class RandomValues
{
    public static decimal Decimal(double min, double max, int decimals)
    {
        var value = Random.Shared.NextDouble() * (max - min) + min;
        return Math.Round((decimal)value, decimals);
    }

    public static int Int(int minInclusive, int maxExclusive) =>
        Random.Shared.Next(minInclusive, maxExclusive);

    public static bool Bool() => Random.Shared.Next(2) == 0;

    public static string Code(int length)
    {
        const string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        var chars = new char[length];
        for (var i = 0; i < length; i++)
        {
            chars[i] = alphabet[Random.Shared.Next(alphabet.Length)];
        }

        return new string(chars);
    }
}
