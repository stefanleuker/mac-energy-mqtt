import Foundation

/// Converts IOReport energy unit labels to joules.
public enum EnergyUnit {
    public static func joules(_ value: Int64, unitLabel: String) -> Double? {
        let factor: Double
        switch unitLabel {
        case "J": factor = 1
        case "mJ": factor = 1e-3
        case "uJ", "µJ": factor = 1e-6
        case "nJ": factor = 1e-9
        default: return nil
        }
        return Double(value) * factor
    }
}
