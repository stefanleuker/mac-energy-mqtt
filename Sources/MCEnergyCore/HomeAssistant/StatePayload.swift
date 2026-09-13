import Foundation

/// Flattens a `PowerSample` into the JSON published on the state topic.
public enum StatePayload {
    public static func dictionary(from sample: PowerSample) -> [String: Any] {
        var state: [String: Any] = [:]
        if let soc = sample.soc {
            state["cpu_power"] = watts(soc.cpu)
            state["gpu_power"] = watts(soc.gpu)
            state["ane_power"] = watts(soc.ane)
            state["dram_power"] = watts(soc.dram)
            state["soc_power"] = watts(soc.total)
        }
        if let system = sample.system {
            state["system_power"] = watts(system.systemLoad)
            state["adapter_loss"] = watts(system.adapterEfficiencyLoss)
            state["battery_power"] = watts(system.batteryPower)
        }
        if let battery = sample.battery {
            state["battery_level"] = battery.levelPercent
            state["cycle_count"] = battery.cycleCount
            state["battery_charging"] = onOff(battery.isCharging)
            state["external_power"] = onOff(battery.externalPowerConnected)
            if let rated = battery.adapterRatedWatts { state["adapter_rated_power"] = rated }
        }
        if let energy = sample.energyKWh {
            state["energy"] = rounded(energy, places: 6)
        }
        return state
    }

    /// Decimal keeps JSON output at three places instead of binary-float noise like 0.59999999999999998.
    private static func watts(_ value: Double) -> Decimal { rounded(value, places: 3) }

    private static func rounded(_ value: Double, places: Int) -> Decimal {
        var source = Decimal(value)
        var result = Decimal()
        NSDecimalRound(&result, &source, places, .plain)
        return result
    }
    private static func onOff(_ flag: Bool) -> String { flag ? "ON" : "OFF" }
}
