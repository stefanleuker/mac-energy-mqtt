import Foundation
import MCEnergyCore

enum RunCommand {
    static func run(_ parsed: ParsedArguments) async throws {
        let settings = try SettingsBuilder.make(from: parsed, environment: ProcessInfo.processInfo.environment, passwordStore: KeychainStore())
        let maxSamples = try parsed.integer("--samples")
        let device = DeviceIdentity.current()
        let meter = PowerMeter(accumulator: EnergyAccumulator(storeURL: Settings.energyStoreURL, log: log))
        let publisher = HomeAssistantPublisher(settings: settings, device: device, meter: meter, log: log)
        log("publishing \(device.name) (\(device.model)) as \(settings.topicPrefix)/\(device.id) every \(Int(settings.intervalSeconds))s")

        let publishing = Task { try await publisher.run(maxSamples: maxSamples) }
        let terminationSignals = [SIGTERM, SIGINT].map { TerminationSignal.observe($0) { publishing.cancel() } }
        defer { terminationSignals.forEach { $0.cancel() } }
        do {
            try await publishing.value
        } catch is CancellationError {
            // Shutdown requested; the publisher has already marked the device offline.
        }
    }

    @Sendable private static func log(_ message: String) {
        FileHandle.standardError.write(Data("\(Date().formatted(.iso8601)) \(message)\n".utf8))
    }
}

/// Turns a Unix signal into a callback so `run` can say goodbye to the broker instead of just dying.
enum TerminationSignal {
    static func observe(_ signalNumber: Int32, _ handler: @escaping @Sendable () -> Void) -> DispatchSourceSignal {
        signal(signalNumber, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .global())
        source.setEventHandler(handler: handler)
        source.resume()
        return source
    }
}
