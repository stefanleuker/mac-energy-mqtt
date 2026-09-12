import Foundation

/// Where the MQTT password lives between `install` and `run`.
public protocol PasswordStore: Sendable {
    func password(for account: String) throws -> String?
    func store(_ password: String, for account: String) throws
    /// Removes every password this store holds for mcenergy.
    func removeAll() throws
}
