import Foundation

/// Runtime configuration shared by `run` and `install`.
public struct Settings: Equatable, Sendable {
    public static let plainPort: UInt16 = 1883
    public static let tlsPort: UInt16 = 8883

    public var brokerHost: String
    public var brokerPort: UInt16 = Settings.plainPort
    public var useTLS = false
    public var username: String?
    public var password: String?
    public var intervalSeconds: Double = 10
    public var discoveryPrefix = "homeassistant"
    public var topicPrefix = "mcenergy"

    public init(brokerHost: String) {
        self.brokerHost = brokerHost
    }

    public static let passwordEnvironmentKey = "MCENERGY_MQTT_PASSWORD"

    /// Keychain account name, unique per broker and user.
    public var keychainAccount: String { "\(username ?? "anonymous")@\(brokerHost):\(brokerPort)" }

    public static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("mcenergy", isDirectory: true)
    }

    public static var energyStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent("energy.json")
    }
}
