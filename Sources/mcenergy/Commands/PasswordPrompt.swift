import Foundation
import MCEnergyCore

enum PasswordPrompt {
    /// Asks on the terminal without echo. Returns nil when there is no terminal to ask on.
    static func read() throws -> String? {
        guard isatty(STDIN_FILENO) == 1 else { throw PasswordPromptError.noTerminal }
        guard let raw = getpass("MQTT password (leave empty for none): ") else { throw PasswordPromptError.noTerminal }
        let password = String(cString: raw)
        return password.isEmpty ? nil : password
    }
}

enum PasswordPromptError: Error, CustomStringConvertible {
    case noTerminal
    var description: String {
        "no password given: pass --password, set \(Settings.passwordEnvironmentKey), or run install in a terminal"
    }
}
