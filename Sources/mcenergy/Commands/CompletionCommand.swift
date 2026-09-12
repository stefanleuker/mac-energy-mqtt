import Foundation
import MCEnergyCore

enum CompletionCommand {
    static func run(_ parsed: ParsedArguments) throws {
        guard let shell = parsed.positionals.first else { throw ArgumentError.missingRequired("<shell>") }
        switch shell {
        case "zsh": print(zsh)
        case "bash": print(bash)
        case "fish": print(fish)
        default: throw ArgumentError.invalidValue(option: "completion", value: shell)
        }
    }

    private static let commands = Command.allCases.map(\.rawValue)
    private static let options = ParsedArguments.valueOptions.sorted() + ["--help", "--version"]

    private static var zsh: String {
        """
        #compdef mcenergy
        _mcenergy() {
          local -a commands options
          commands=(\(commands.map { "'\($0)'" }.joined(separator: " ")))
          options=(\(options.map { "'\($0)'" }.joined(separator: " ")))
          if (( CURRENT == 2 )); then
            _describe 'command' commands
          elif [[ ${words[2]} == completion ]]; then
            _values 'shell' zsh bash fish
          else
            _describe 'option' options
          fi
        }
        _mcenergy "$@"
        """
    }

    private static var bash: String {
        """
        _mcenergy() {
          local cur="${COMP_WORDS[COMP_CWORD]}"
          if [[ $COMP_CWORD -eq 1 ]]; then
            COMPREPLY=($(compgen -W "\(commands.joined(separator: " "))" -- "$cur"))
          elif [[ ${COMP_WORDS[1]} == completion ]]; then
            COMPREPLY=($(compgen -W "zsh bash fish" -- "$cur"))
          else
            COMPREPLY=($(compgen -W "\(options.joined(separator: " "))" -- "$cur"))
          fi
        }
        complete -F _mcenergy mcenergy
        """
    }

    private static var fish: String {
        var lines = commands.map { "complete -c mcenergy -n '__fish_use_subcommand' -a \($0)" }
        lines.append("complete -c mcenergy -n '__fish_seen_subcommand_from completion' -a 'zsh bash fish'")
        lines += options.map { "complete -c mcenergy -l \($0.dropFirst(2))" }
        return lines.joined(separator: "\n")
    }
}
