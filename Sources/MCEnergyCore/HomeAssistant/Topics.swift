import Foundation

/// MQTT topic layout for one device.
public struct Topics: Equatable, Sendable {
    public var discoveryPrefix: String
    public var topicPrefix: String
    public var deviceID: String

    public init(discoveryPrefix: String, topicPrefix: String, deviceID: String) {
        self.discoveryPrefix = discoveryPrefix
        self.topicPrefix = topicPrefix
        self.deviceID = deviceID
    }

    public var state: String { "\(topicPrefix)/\(deviceID)/state" }
    public var availability: String { "\(topicPrefix)/\(deviceID)/status" }

    public func discovery(for sensor: SensorDefinition) -> String {
        "\(discoveryPrefix)/\(sensor.component.rawValue)/\(topicPrefix)_\(deviceID)/\(sensor.key)/config"
    }

    /// Every message mcenergy leaves retained on the broker for this device: all discovery configs plus availability.
    /// Publishing an empty retained payload to each removes the device from Home Assistant.
    public var retainedTopics: [String] {
        SensorDefinition.all.map(discovery(for:)) + [availability]
    }
}
