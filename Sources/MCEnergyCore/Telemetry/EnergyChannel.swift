import Foundation

/// Maps SoC components to their IOReport "Energy Model" channel names.
/// Names vary between chip generations (M3: "DRAM", M2: "DRAM0"), so each has ordered candidates
/// and a candidate also matches numbered instances, which are summed (multi-die chips).
public enum EnergyChannel: CaseIterable, Sendable {
    case cpu, gpu, ane, dram

    var candidateNames: [String] {
        switch self {
        case .cpu: return ["CPU Energy"]
        case .gpu: return ["GPU Energy", "GPU"]
        case .ane: return ["ANE Energy", "ANE"]
        case .dram: return ["DRAM Energy", "DRAM"]
        }
    }

    /// Picks the joule reading for this component from a name → joules table.
    func pick(from joulesByChannel: [String: Double]) -> Double {
        for name in candidateNames {
            if let joules = joulesByChannel[name] { return joules }
            let instances = joulesByChannel.filter { Self.isNumberedInstance($0.key, of: name) }
            if !instances.isEmpty { return instances.values.reduce(0, +) }
        }
        return 0
    }

    private static func isNumberedInstance(_ channel: String, of base: String) -> Bool {
        guard channel.hasPrefix(base) else { return false }
        let suffix = channel.dropFirst(base.count)
        return !suffix.isEmpty && suffix.allSatisfy(\.isNumber)
    }

    public static func socPower(joulesByChannel: [String: Double], seconds: Double) -> SoCPower? {
        guard seconds > 0, !joulesByChannel.isEmpty else { return nil }
        func watts(_ channel: EnergyChannel) -> Double { channel.pick(from: joulesByChannel) / seconds }
        return SoCPower(cpu: watts(.cpu), gpu: watts(.gpu), ane: watts(.ane), dram: watts(.dram))
    }
}
