import Foundation

/// Turns parsed CLI arguments plus environment into `Settings`.
/// Password precedence: `--password`, then environment, then the password store.
public enum SettingsBuilder {
    public static func make(from arguments: ParsedArguments, environment: [String: String], passwordStore: PasswordStore? = nil) throws -> Settings {
        guard let broker = arguments.options["--broker"] else { throw ArgumentError.missingRequired("--broker") }
        var settings = Settings(brokerHost: broker)
        settings.useTLS = arguments.flags.contains("--tls")
        settings.brokerPort = try port(from: arguments) ?? (settings.useTLS ? Settings.tlsPort : Settings.plainPort)
        settings.username = arguments.options["--user"]
        if let interval = try arguments.integer("--interval") { settings.intervalSeconds = Double(interval) }
        if let prefix = arguments.options["--discovery-prefix"] { settings.discoveryPrefix = prefix }
        if let prefix = arguments.options["--topic-prefix"] { settings.topicPrefix = prefix }
        settings.password = try password(for: settings, arguments: arguments, environment: environment, store: passwordStore)
        guard settings.password == nil || settings.username != nil else { throw ArgumentError.passwordRequiresUser }
        return settings
    }

    private static func port(from arguments: ParsedArguments) throws -> UInt16? {
        guard let port = try arguments.integer("--port") else { return nil }
        guard port <= Int(UInt16.max) else { throw ArgumentError.invalidValue(option: "--port", value: String(port)) }
        return UInt16(port)
    }

    /// The store is only consulted for a named user; an anonymous connection never carries a password.
    private static func password(for settings: Settings, arguments: ParsedArguments, environment: [String: String], store: PasswordStore?) throws -> String? {
        if let explicit = arguments.options["--password"] ?? environment[Settings.passwordEnvironmentKey] { return explicit }
        guard settings.username != nil else { return nil }
        return try store?.password(for: settings.keychainAccount)
    }
}
