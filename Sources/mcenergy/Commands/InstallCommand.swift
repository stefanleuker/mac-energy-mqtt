import Foundation
import MCEnergyCore

enum InstallCommand {
    static let label = "local.mcenergy"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/mcenergy.log")
    }

    static func install(_ parsed: ParsedArguments) throws {
        let keychain = KeychainStore()
        var settings = try SettingsBuilder.make(from: parsed, environment: ProcessInfo.processInfo.environment, passwordStore: keychain)
        if settings.password == nil { settings.password = try PasswordPrompt.read() }
        if let password = settings.password { try keychain.store(password, for: settings.keychainAccount) }
        let plist = LaunchAgent.plist(label: label, executable: executablePath(), settings: settings, logPath: logURL.path)
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: plistURL, options: .atomic)
        _ = launchctl(["bootout", domain, plistURL.path])
        let status = launchctl(["bootstrap", domain, plistURL.path])
        guard status == 0 else { throw InstallError.launchctlFailed(status) }
        print("installed \(label) → \(plistURL.path)")
        print("password stored in login keychain (service \(keychain.service), account \(settings.keychainAccount))")
        print("log: \(logURL.path)")
    }

    static func uninstall() throws {
        _ = launchctl(["bootout", domain, plistURL.path])
        try KeychainStore().removeAll()
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
        print("removed \(label) and its keychain password")
    }

    private static var domain: String { "gui/\(getuid())" }

    private static func executablePath() -> String {
        URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().path
    }

    private static func launchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}

enum InstallError: Error, CustomStringConvertible {
    case launchctlFailed(Int32)

    var description: String {
        switch self {
        case .launchctlFailed(let status): return "launchctl bootstrap failed with status \(status)"
        }
    }
}
