import Foundation
import MCEnergyCore

/// Clears the retained discovery and availability messages of device IDs this Mac no longer uses,
/// for example after a host name change left a stale twin in Home Assistant.
enum ForgetCommand {
    static func run(_ parsed: ParsedArguments) async throws {
        guard !parsed.positionals.isEmpty else { throw ArgumentError.missingRequired("<device-id>") }
        let settings = try SettingsBuilder.make(from: parsed, environment: ProcessInfo.processInfo.environment, passwordStore: KeychainStore())
        let client = MQTTClient(options: clientOptions(settings))
        try await client.connect()
        for deviceID in parsed.positionals {
            let topics = Topics(discoveryPrefix: settings.discoveryPrefix, topicPrefix: settings.topicPrefix, deviceID: DeviceIdentity.slug(deviceID))
            for topic in topics.retainedTopics {
                try await client.publish(topic: topic, payload: Data(), retain: true)
            }
            print("cleared \(topics.retainedTopics.count) retained messages of \(settings.topicPrefix)/\(topics.deviceID)")
        }
        await client.disconnect()
    }

    private static func clientOptions(_ settings: Settings) -> MQTTClient.Options {
        var options = MQTTClient.Options(
            host: settings.brokerHost, port: settings.brokerPort,
            clientID: "\(settings.topicPrefix)-forget-\(getpid())",
            username: settings.username, password: settings.password, keepAlive: 30, will: nil
        )
        options.useTLS = settings.useTLS
        return options
    }
}
