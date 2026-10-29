import Foundation

/// Integrates system power over time into a monotonically increasing energy total.
/// Persists to disk so Home Assistant's `total_increasing` statistics survive restarts.
public final class EnergyAccumulator: @unchecked Sendable {
    public typealias Log = @Sendable (String) -> Void

    private struct State: Codable {
        var wattHours: Double
        var lastTimestamp: Date?
    }

    private let storeURL: URL?
    private let log: Log
    private var state: State
    private var reportedSaveFailure = false

    public init(storeURL: URL?, log: @escaping Log = { _ in }) {
        self.storeURL = storeURL
        self.log = log
        self.state = Self.load(from: storeURL, log: log) ?? State(wattHours: 0, lastTimestamp: nil)
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

    /// A missing file is the normal first start; an unreadable one is worth a log line because the total restarts at 0.
    private static func load(from url: URL?, log: Log) -> State? {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try JSONDecoder().decode(State.self, from: Data(contentsOf: url))
        } catch {
            log("energy store \(url.path) unreadable (\(error)), energy total restarts at 0")
            return nil
        }
    }

    private func save() {
        guard let storeURL, let data = try? JSONEncoder().encode(state) else { return }
        do {
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            guard !reportedSaveFailure else { return }
            reportedSaveFailure = true
            log("cannot save energy store \(storeURL.path): \(error)")
        }
    }
}
