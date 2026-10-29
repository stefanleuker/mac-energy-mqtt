import Foundation

public enum ArgumentError: Error, Equatable, CustomStringConvertible {
    case missingValue(String)
    case unknownOption(String)
    case unknownCommand(String)
    case missingRequired(String)
    case invalidValue(option: String, value: String)
    case passwordRequiresUser

    public var description: String {
        switch self {
        case .missingValue(let option): return "option \(option) requires a value"
        case .unknownOption(let option): return "unknown option \(option)"
        case .unknownCommand(let command): return "unknown command \(command)"
        case .missingRequired(let option): return "missing required option \(option)"
        case .invalidValue(let option, let value): return "invalid value '\(value)' for \(option)"
        case .passwordRequiresUser: return "a password needs --user: MQTT does not allow a password without a username"
        }
    }
}

/// Splits `command [--option value]... [positional]...` without third-party dependencies.
public struct ParsedArguments: Equatable, Sendable {
    public var command: String?
    public var positionals: [String] = []
    public var options: [String: String] = [:]
    public var flags: Set<String> = []

    public static let valueOptions: Set<String> = [
        "--broker", "--port", "--user", "--password", "--interval", "--discovery-prefix", "--topic-prefix", "--samples",
    ]
    public static let booleanFlags: Set<String> = ["--help", "-h", "--version", "--tls"]

    public static func parse(_ arguments: [String]) throws -> ParsedArguments {
        var parsed = ParsedArguments()
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            if booleanFlags.contains(argument) {
                parsed.flags.insert(argument)
            } else if valueOptions.contains(argument) {
                guard let value = iterator.next() else { throw ArgumentError.missingValue(argument) }
                parsed.options[argument] = value
            } else if argument.hasPrefix("-") {
                throw ArgumentError.unknownOption(argument)
            } else if parsed.command == nil {
                parsed.command = argument
            } else {
                parsed.positionals.append(argument)
            }
        }
        return parsed
    }

    public func integer(_ option: String) throws -> Int? {
        guard let raw = options[option] else { return nil }
        guard let value = Int(raw), value > 0 else { throw ArgumentError.invalidValue(option: option, value: raw) }
        return value
    }
}
