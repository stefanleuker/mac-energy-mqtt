import Foundation
import SystemConfiguration

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
        let hostName = localHostName() ?? shortHostName(ProcessInfo.processInfo.hostName)
        return DeviceIdentity(
            id: slug(hostName),
            name: Host.current().localizedName ?? hostName,
            model: sysctlString("hw.model") ?? "Mac",
            serialNumber: IOKitRegistry.platformSerialNumber()
        )
    }

    /// The Bonjour name from Sharing settings, e.g. "spencer": set by the user, stable across networks.
    /// `ProcessInfo.hostName` is a reverse DNS lookup instead and has produced router-assigned names
    /// like "43c42d9c-….fritz.box", which split one Mac into several Home Assistant devices.
    private static func localHostName() -> String? {
        guard let name = SCDynamicStoreCopyLocalHostName(nil) as String?, !name.isEmpty else { return nil }
        return name
    }

    /// Strips only a trailing Bonjour `.local`, leaving names like `my.local.net` alone.
    public static func shortHostName(_ hostName: String) -> String {
        let suffix = ".local"
        return hostName.hasSuffix(suffix) ? String(hostName.dropLast(suffix.count)) : hostName
    }

    /// Lowercase ASCII alphanumerics and underscores only: Home Assistant discovery allows nothing else
    /// in node and object IDs. Falls back to "mac" when nothing usable remains.
    public static func slug(_ text: String) -> String {
        let mapped = text.lowercased().map { character -> Character in
            character.isASCII && (character.isLetter || character.isNumber) ? character : "_"
        }
        let trimmed = String(mapped).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return trimmed.isEmpty ? "mac" : trimmed
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
