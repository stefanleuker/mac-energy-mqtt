import Foundation

/// Pure parsing of the `AppleSmartBattery` registry properties.
/// Present on every Apple Silicon Mac, even those without a battery.
public enum SmartBatteryParser {
    public static func systemPower(from properties: [String: Any]) -> SystemPower? {
        guard let telemetry = properties["PowerTelemetryData"] as? [String: Any],
              let systemLoad = milliwatts(telemetry["SystemLoad"]) else { return nil }
        return SystemPower(
            systemLoad: systemLoad,
            adapterEfficiencyLoss: milliwatts(telemetry["AdapterEfficiencyLoss"]) ?? 0,
            batteryPower: milliwatts(telemetry["BatteryPower"]) ?? 0
        )
    }

    public static func batteryStatus(from properties: [String: Any]) -> BatteryStatus? {
        guard properties["BatteryInstalled"] as? Bool == true,
              let level = properties["CurrentCapacity"] as? Int else { return nil }
        let externalConnected = properties["ExternalConnected"] as? Bool ?? false
        let adapter = properties["AdapterDetails"] as? [String: Any]
        return BatteryStatus(
            levelPercent: level,
            isCharging: properties["IsCharging"] as? Bool ?? false,
            externalPowerConnected: externalConnected,
            cycleCount: properties["CycleCount"] as? Int ?? 0,
            adapterRatedWatts: externalConnected ? adapter?["Watts"] as? Int : nil
        )
    }

    private static func milliwatts(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        return number.doubleValue / 1000
    }
}
