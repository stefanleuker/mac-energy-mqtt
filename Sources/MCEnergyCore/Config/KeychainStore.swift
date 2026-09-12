import Foundation
import Security

public enum KeychainError: Error, Equatable, CustomStringConvertible {
    case unexpectedStatus(OSStatus)

    public var description: String {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
            return "keychain error \(status): \(message)"
        }
    }
}

/// Generic-password items in the user's login keychain.
public struct KeychainStore: PasswordStore {
    public static let defaultService = "mcenergy"

    public var service: String

    public init(service: String = KeychainStore.defaultService) {
        self.service = service
    }

    public func password(for account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            return String(decoding: data, as: UTF8.self)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Delete-then-add instead of update: deleting needs no access-control approval,
    /// so a rebuilt binary can replace the item without a keychain prompt.
    public func store(_ password: String, for account: String) throws {
        try delete(baseQuery(account: account))
        var attributes = baseQuery(account: account)
        attributes[kSecValueData] = Data(password.utf8)
        attributes[kSecAttrLabel] = "mcenergy MQTT password"
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    public func removeAll() throws {
        try delete([kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecMatchLimit: kSecMatchLimitAll])
    }

    private func delete(_ query: [CFString: Any]) throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unexpectedStatus(status) }
    }

    private func baseQuery(account: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
    }
}
