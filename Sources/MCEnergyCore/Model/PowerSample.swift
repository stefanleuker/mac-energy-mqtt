import Foundation

/// Real-time SoC power in watts, derived from IOReport energy counters.
public struct SoCPower: Codable, Equatable, Sendable {
    public var cpu: Double
    public var gpu: Double
    public var ane: Double
    public var dram: Double

    public var total: Double { cpu + gpu + ane + dram }

    public init(cpu: Double, gpu: Double, ane: Double, dram: Double) {
        self.cpu = cpu
        self.gpu = gpu
        self.ane = ane
        self.dram = dram
    }
}

/// Whole-machine power in watts, refreshed by the PMU roughly once a minute.
public struct SystemPower: Codable, Equatable, Sendable {
    /// Power consumed by the whole system, whether fed from the adapter or the battery.
    /// (`SystemLoad`; the neighbouring `SystemPowerIn` is adapter input only and reads 0 on battery.)
    public var systemLoad: Double
    /// Losses inside the power adapter or internal supply.
    public var adapterEfficiencyLoss: Double
    /// Positive while charging, negative while discharging.
    public var batteryPower: Double

    public init(systemLoad: Double, adapterEfficiencyLoss: Double, batteryPower: Double) {
        self.systemLoad = systemLoad
        self.adapterEfficiencyLoss = adapterEfficiencyLoss
        self.batteryPower = batteryPower
    }
}

/// Battery state, present only on machines with an installed battery.
public struct BatteryStatus: Codable, Equatable, Sendable {
    public var levelPercent: Int
    public var isCharging: Bool
    public var externalPowerConnected: Bool
    public var cycleCount: Int
    /// Rated adapter capacity in watts, nil when unplugged.
    public var adapterRatedWatts: Int?

    public init(levelPercent: Int, isCharging: Bool, externalPowerConnected: Bool, cycleCount: Int, adapterRatedWatts: Int?) {
        self.levelPercent = levelPercent
        self.isCharging = isCharging
        self.externalPowerConnected = externalPowerConnected
        self.cycleCount = cycleCount
        self.adapterRatedWatts = adapterRatedWatts
    }
}

public struct PowerSample: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var soc: SoCPower?
    public var system: SystemPower?
    public var battery: BatteryStatus?
    /// Integrated system energy in kWh since first run.
    public var energyKWh: Double?

    public init(timestamp: Date, soc: SoCPower?, system: SystemPower?, battery: BatteryStatus?, energyKWh: Double?) {
        self.timestamp = timestamp
        self.soc = soc
        self.system = system
        self.battery = battery
        self.energyKWh = energyKWh
    }
}
