import Foundation

/// One Home Assistant entity fed from the shared state topic.
public struct SensorDefinition: Equatable, Sendable {
    public enum Component: String, Sendable {
        case sensor
        case binarySensor = "binary_sensor"
    }

    public enum Requirement: Sendable {
        case soc, system, battery, energy
    }

    public var key: String
    public var name: String
    public var component: Component
    public var requirement: Requirement
    public var unit: String?
    public var deviceClass: String?
    public var stateClass: String?
    public var icon: String?
    public var entityCategory: String?

    /// Every entity mcenergy can offer. Which ones get announced depends on the machine.
    public static let all: [SensorDefinition] = [
        power("system_power", "System Power", .system),
        power("adapter_loss", "Adapter Loss", .system, category: "diagnostic"),
        power("battery_power", "Battery Power", .battery),
        power("soc_power", "SoC Power", .soc),
        power("cpu_power", "CPU Power", .soc),
        power("gpu_power", "GPU Power", .soc),
        power("ane_power", "Neural Engine Power", .soc),
        power("dram_power", "Memory Power", .soc),
        SensorDefinition(key: "energy", name: "Energy", component: .sensor, requirement: .energy,
                         unit: "kWh", deviceClass: "energy", stateClass: "total_increasing", icon: nil, entityCategory: nil),
        SensorDefinition(key: "battery_level", name: "Battery Level", component: .sensor, requirement: .battery,
                         unit: "%", deviceClass: "battery", stateClass: "measurement", icon: nil, entityCategory: nil),
        SensorDefinition(key: "cycle_count", name: "Battery Cycles", component: .sensor, requirement: .battery,
                         unit: nil, deviceClass: nil, stateClass: "total_increasing", icon: "mdi:battery-sync", entityCategory: "diagnostic"),
        SensorDefinition(key: "adapter_rated_power", name: "Adapter Rated Power", component: .sensor, requirement: .battery,
                         unit: "W", deviceClass: "power", stateClass: nil, icon: "mdi:power-plug", entityCategory: "diagnostic"),
        SensorDefinition(key: "battery_charging", name: "Battery Charging", component: .binarySensor, requirement: .battery,
                         unit: nil, deviceClass: "battery_charging", stateClass: nil, icon: nil, entityCategory: nil),
        SensorDefinition(key: "external_power", name: "External Power", component: .binarySensor, requirement: .battery,
                         unit: nil, deviceClass: "plug", stateClass: nil, icon: nil, entityCategory: nil),
    ]

    public static func available(for sample: PowerSample) -> [SensorDefinition] {
        all.filter { definition in
            switch definition.requirement {
            case .soc: return sample.soc != nil
            case .system: return sample.system != nil
            case .battery: return sample.battery != nil
            case .energy: return sample.energyKWh != nil
            }
        }
    }

    private static func power(_ key: String, _ name: String, _ requirement: Requirement, category: String? = nil) -> SensorDefinition {
        SensorDefinition(key: key, name: name, component: .sensor, requirement: requirement,
                         unit: "W", deviceClass: "power", stateClass: "measurement", icon: nil, entityCategory: category)
    }
}
