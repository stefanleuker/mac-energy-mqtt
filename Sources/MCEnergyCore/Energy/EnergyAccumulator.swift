import Foundation

/// Integrates system power over time into a monotonically increasing energy total.
/// Persists to disk so Home Assistant's `total_increasing` statistics survive restarts.
public final class EnergyAccumulator: @unchecked Sendable {
    private struct State: Codable {
        var wattHours: Double
        var lastTimestamp: Date?
    }

    private let storeURL: URL?
    private var state: State

    public init(storeURL: URL?) {
        self.storeURL = storeURL
        self.state = Self.load(from: storeURL) ?? State(wattHours: 0, lastTimestamp: nil)
    }

    public var kilowattHours: Double { state.wattHours / 1000 }

    /// Adds energy assuming `watts` was drawn since the previous reading.
    /// Gaps longer than `maxGapSeconds` (sleep, downtime) are not counted.
    public func add(watts: Double, at timestamp: Date, maxGapSeconds: TimeInterval = 300) {
        if let last = state.lastTimestamp {
            let seconds = timestamp.timeIntervalSince(last)
            if seconds > 0, seconds <= maxGapSeconds {
                state.wattHours += watts * seconds / 3600
            }
        }
        state.lastTimestamp = timestamp
        save()
    }

    private static func load(from url: URL?) -> State? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(State.self, from: data)
    }

    private func save() {
        guard let storeURL, let data = try? JSONEncoder().encode(state) else { return }
        try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: storeURL, options: .atomic)
    }
}
