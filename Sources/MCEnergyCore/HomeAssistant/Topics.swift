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
}
