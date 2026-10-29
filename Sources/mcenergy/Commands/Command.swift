import Foundation
import MCEnergyCore

enum Command: String, CaseIterable {
    case measure, channels, run, install, uninstall, forget, completion, help

    static let usage = """
    Usage: mcenergy <command> [options]

    Commands:
      measure                 Print one power sample as the JSON Home Assistant receives (without the energy total)
      channels                List raw IOReport energy channels of this chip (diagnostics)
      run                     Publish samples to Home Assistant over MQTT until stopped
      install                 Install a launchd agent that runs `run` at login; stores the password in the keychain
      uninstall               Remove the launchd agent and the keychain password
      forget <device-id>...   Remove stale device IDs from Home Assistant by clearing their retained messages
      completion <shell>      Print a completion script for zsh, bash or fish
      help                    Show this help

    Options for run, install and forget:
      --broker <host>         MQTT broker host (required)
      --port <n>              MQTT broker port (default 1883, or 8883 with --tls)
      --tls                   Connect over TLS; the broker certificate must be trusted by this Mac
      --user <name>           MQTT username
      --password <secret>     MQTT password; falls back to environment \(Settings.passwordEnvironmentKey),
                              then the login keychain, then an interactive prompt (install only).
                              Prefer the prompt: a password on the command line is visible in `ps` and shell history
      --interval <seconds>    Seconds between samples (default 10)
      --discovery-prefix <p>  Home Assistant discovery prefix (default homeassistant)
      --topic-prefix <p>      Topic prefix for state and availability (default mcenergy)

    Options for run only:
      --samples <n>           Stop after n samples (useful for testing)
    """

    static func resolve(_ parsed: ParsedArguments) throws -> Command {
        if parsed.flags.contains("--version") { return .help }
        if parsed.flags.contains("--help") || parsed.flags.contains("-h") { return .help }
        guard let name = parsed.command else { return .help }
        guard let command = Command(rawValue: name) else { throw ArgumentError.unknownCommand(name) }
        return command
    }

    func run(_ parsed: ParsedArguments) async throws {
        switch self {
        case .measure: try await MeasureCommand.run()
        case .channels: try await ChannelsCommand.run()
        case .run: try await RunCommand.run(parsed)
        case .install: try InstallCommand.install(parsed)
        case .uninstall: try InstallCommand.uninstall()
        case .forget: try await ForgetCommand.run(parsed)
        case .completion: try CompletionCommand.run(parsed)
        case .help: Self.printHelp(parsed)
        }
    }

    private static func printHelp(_ parsed: ParsedArguments) {
        if parsed.flags.contains("--version") {
            print("mcenergy \(DiscoveryConfig.softwareVersion)")
        } else {
            print(usage)
        }
    }
}
