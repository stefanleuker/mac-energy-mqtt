import Foundation

/// Turns parsed CLI arguments plus environment into `Settings`.
/// Password precedence: `--password`, then environment, then the password store.
public enum SettingsBuilder {
    public static func make(from arguments: ParsedArguments, environment: [String: String], passwordStore: PasswordStore? = nil) throws -> Settings {
        guard let broker = arguments.options["--broker"] else { throw ArgumentError.missingRequired("--broker") }
        var settings = Settings(brokerHost: broker)
        if let port = try arguments.integer("--port") {
            guard port <= 65535 else { throw ArgumentError.invalidValue(option: "--port", value: String(port)) }
            settings.brokerPort = UInt16(port)
        }
        settings.username = arguments.options["--user"]
        if let interval = try arguments.integer("--interval") { settings.intervalSeconds = Double(interval) }
        if let prefix = arguments.options["--discovery-prefix"] { settings.discoveryPrefix = prefix }
        if let prefix = arguments.options["--topic-prefix"] { settings.topicPrefix = prefix }
        settings.password = try arguments.options["--password"]
            ?? environment[Settings.passwordEnvironmentKey]
            ?? passwordStore?.password(for: settings.keychainAccount)
        return settings
    }
}
