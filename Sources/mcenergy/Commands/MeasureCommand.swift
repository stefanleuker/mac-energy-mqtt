import Foundation
import MCEnergyCore

enum MeasureCommand {
    static func run() async throws {
        let meter = PowerMeter(accumulator: nil)
        _ = meter.sample() // primes the IOReport counters
        try await Task.sleep(for: .seconds(1))
        let state = StatePayload.dictionary(from: meter.sample())
        let data = try JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        if !meter.hasEnergyModel {
            FileHandle.standardError.write(Data("mcenergy: IOReport energy model unavailable, SoC power omitted\n".utf8))
        }
    }
}
