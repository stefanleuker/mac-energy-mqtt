import Foundation
import MCEnergyCore

enum RunCommand {
    static func run(_ parsed: ParsedArguments) async throws {
        let settings = try SettingsBuilder.make(from: parsed, environment: ProcessInfo.processInfo.environment, passwordStore: KeychainStore())
        let maxSamples = try parsed.integer("--samples")
        let device = DeviceIdentity.current()
        let meter = PowerMeter(accumulator: EnergyAccumulator(storeURL: Settings.energyStoreURL))
        let publisher = HomeAssistantPublisher(settings: settings, device: device, meter: meter, log: log)
        log("publishing \(device.name) (\(device.model)) as \(settings.topicPrefix)/\(device.id) every \(Int(settings.intervalSeconds))s")
        try await publisher.run(maxSamples: maxSamples)
    }

    @Sendable private static func log(_ message: String) {
        FileHandle.standardError.write(Data("\(Date().formatted(.iso8601)) \(message)\n".utf8))
    }
}
