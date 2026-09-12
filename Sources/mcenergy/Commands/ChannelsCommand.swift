import Foundation
import MCEnergyCore

enum ChannelsCommand {
    static func run() async throws {
        guard let reader = EnergyModelReader() else {
            throw ChannelsError.energyModelUnavailable
        }
        try await Task.sleep(for: .seconds(1))
        for channel in reader.readRawChannels() where !channel.name.contains("DTL") && !channel.name.hasSuffix("_SRAM") {
            print("\(channel.name.padding(toLength: 24, withPad: " ", startingAt: 0)) \(channel.value) \(channel.unitLabel)")
        }
    }
}

enum ChannelsError: Error, CustomStringConvertible {
    case energyModelUnavailable
    var description: String { "IOReport energy model unavailable on this machine" }
}
