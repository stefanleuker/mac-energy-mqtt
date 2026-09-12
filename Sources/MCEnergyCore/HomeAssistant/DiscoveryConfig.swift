import Foundation

/// Builds Home Assistant MQTT discovery payloads.
public enum DiscoveryConfig {
    public static let softwareVersion = "0.1.0"

    public static func payload(for sensor: SensorDefinition, device: DeviceIdentity, topics: Topics) -> [String: Any] {
        let deviceUniqueID = "\(topics.topicPrefix)_\(device.id)"
        var payload: [String: Any] = [
            "name": sensor.name,
            "unique_id": "\(deviceUniqueID)_\(sensor.key)",
            "state_topic": topics.state,
            "value_template": "{{ value_json.\(sensor.key) }}",
            "availability_topic": topics.availability,
            "device": deviceInfo(device, uniqueID: deviceUniqueID),
            "origin": ["name": "mcenergy", "sw_version": softwareVersion],
        ]
        if let unit = sensor.unit { payload["unit_of_measurement"] = unit }
        if let deviceClass = sensor.deviceClass { payload["device_class"] = deviceClass }
        if let stateClass = sensor.stateClass { payload["state_class"] = stateClass }
        if let icon = sensor.icon { payload["icon"] = icon }
        if let category = sensor.entityCategory { payload["entity_category"] = category }
        if sensor.component == .binarySensor {
            payload["payload_on"] = "ON"
            payload["payload_off"] = "OFF"
        }
        return payload
    }

    private static func deviceInfo(_ device: DeviceIdentity, uniqueID: String) -> [String: Any] {
        var identifiers = [uniqueID]
        if let serial = device.serialNumber { identifiers.append(serial) }
        return [
            "identifiers": identifiers,
            "name": device.name,
            "manufacturer": "Apple",
            "model": device.model,
            "sw_version": "mcenergy \(softwareVersion)",
        ]
    }
}
