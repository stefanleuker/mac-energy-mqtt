import Foundation

/// Identifies this Mac towards Home Assistant.
public struct DeviceIdentity: Equatable, Sendable {
    /// Stable slug used in topics and unique IDs, e.g. "deepsea".
    public var id: String
    public var name: String
    public var model: String
    public var serialNumber: String?

    public init(id: String, name: String, model: String, serialNumber: String?) {
        self.id = id
        self.name = name
        self.model = model
        self.serialNumber = serialNumber
    }

    public static func current() -> DeviceIdentity {
        let hostName = ProcessInfo.processInfo.hostName.replacingOccurrences(of: ".local", with: "")
        return DeviceIdentity(
            id: slug(hostName),
            name: Host.current().localizedName ?? hostName,
            model: sysctlString("hw.model") ?? "Mac",
            serialNumber: IOKitRegistry.platformSerialNumber()
        )
    }

    /// Lowercase alphanumerics and underscores only, safe for MQTT topics and HA object IDs.
    public static func slug(_ text: String) -> String {
        let mapped = text.lowercased().map { character -> Character in
            character.isLetter || character.isNumber ? character : "_"
        }
        return String(mapped).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
