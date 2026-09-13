import Foundation

/// Combines all telemetry sources into one `PowerSample`.
public final class PowerMeter: @unchecked Sendable {
    private let energyModel: EnergyModelReader?
    private let accumulator: EnergyAccumulator?

    public init(accumulator: EnergyAccumulator?) {
        self.energyModel = EnergyModelReader()
        self.accumulator = accumulator
    }

    public var hasEnergyModel: Bool { energyModel != nil }

    public func sample() -> PowerSample {
        let now = Date()
        let battery = IOKitRegistry.properties(ofService: "AppleSmartBattery") ?? [:]
        let system = SmartBatteryParser.systemPower(from: battery)
        if let watts = system?.systemLoad {
            accumulator?.add(watts: watts, at: now)
        }
        return PowerSample(
            timestamp: now,
            soc: energyModel?.read(),
            system: system,
            battery: SmartBatteryParser.batteryStatus(from: battery),
            energyKWh: accumulator?.kilowattHours
        )
    }
}
