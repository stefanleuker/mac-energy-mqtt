import Foundation

/// Builds the launchd property list that keeps `mcenergy run` alive at login.
/// The password is never written here; `run` reads it from the keychain.
public enum LaunchAgent {
    public static func plist(label: String, executable: String, settings: Settings, logPath: String) -> [String: Any] {
        [
            "Label": label,
            "ProgramArguments": [executable, "run"] + runArguments(settings),
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Background",
            "StandardOutPath": logPath,
            "StandardErrorPath": logPath,
        ]
    }

    public static func runArguments(_ settings: Settings) -> [String] {
        var arguments = [
            "--broker", settings.brokerHost,
            "--port", String(settings.brokerPort),
            "--interval", String(Int(settings.intervalSeconds)),
            "--discovery-prefix", settings.discoveryPrefix,
            "--topic-prefix", settings.topicPrefix,
        ]
        if settings.useTLS { arguments.append("--tls") }
        if let username = settings.username { arguments += ["--user", username] }
        return arguments
    }
}
