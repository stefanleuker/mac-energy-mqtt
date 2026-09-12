import Foundation
import MCEnergyCore

let arguments = Array(CommandLine.arguments.dropFirst())

do {
    let parsed = try ParsedArguments.parse(arguments)
    let command = try Command.resolve(parsed)
    try await command.run(parsed)
} catch let error as ArgumentError {
    FileHandle.standardError.write(Data("mcenergy: \(error)\n\n\(Command.usage)\n".utf8))
    exit(64)
} catch {
    FileHandle.standardError.write(Data("mcenergy: \(error)\n".utf8))
    exit(1)
}
