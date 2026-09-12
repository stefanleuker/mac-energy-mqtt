import XCTest
@testable import MCEnergyCore

final class ConfigTests: XCTestCase {
    func testParsesCommandOptionsAndFlags() throws {
        let parsed = try ParsedArguments.parse(["run", "--broker", "ha.local", "--port", "1884", "--help", "zsh"])
        XCTAssertEqual(parsed.command, "run")
        XCTAssertEqual(parsed.options["--broker"], "ha.local")
        XCTAssertEqual(parsed.options["--port"], "1884")
        XCTAssertTrue(parsed.flags.contains("--help"))
        XCTAssertEqual(parsed.positionals, ["zsh"])
    }

    func testRejectsUnknownOptionAndMissingValue() {
        XCTAssertThrowsError(try ParsedArguments.parse(["run", "--bogus"])) { XCTAssertEqual($0 as? ArgumentError, .unknownOption("--bogus")) }
        XCTAssertThrowsError(try ParsedArguments.parse(["run", "--broker"])) { XCTAssertEqual($0 as? ArgumentError, .missingValue("--broker")) }
    }

    func testSettingsDefaultsAndEnvironmentPassword() throws {
        let parsed = try ParsedArguments.parse(["run", "--broker", "192.168.0.78", "--user", "mac"])
        let settings = try SettingsBuilder.make(from: parsed, environment: [Settings.passwordEnvironmentKey: "secret"])
        XCTAssertEqual(settings.brokerHost, "192.168.0.78")
        XCTAssertEqual(settings.brokerPort, 1883)
        XCTAssertEqual(settings.username, "mac")
        XCTAssertEqual(settings.password, "secret")
        XCTAssertEqual(settings.intervalSeconds, 10)
        XCTAssertEqual(settings.discoveryPrefix, "homeassistant")
    }

    func testExplicitPasswordWinsOverEnvironment() throws {
        let parsed = try ParsedArguments.parse(["run", "--broker", "b", "--password", "cli", "--interval", "30"])
        let settings = try SettingsBuilder.make(from: parsed, environment: [Settings.passwordEnvironmentKey: "env"])
        XCTAssertEqual(settings.password, "cli")
        XCTAssertEqual(settings.intervalSeconds, 30)
    }

    func testSettingsRequireBrokerAndValidNumbers() throws {
        XCTAssertThrowsError(try SettingsBuilder.make(from: ParsedArguments.parse(["run"]), environment: [:])) {
            XCTAssertEqual($0 as? ArgumentError, .missingRequired("--broker"))
        }
        XCTAssertThrowsError(try SettingsBuilder.make(from: ParsedArguments.parse(["run", "--broker", "b", "--port", "70000"]), environment: [:]))
        XCTAssertThrowsError(try SettingsBuilder.make(from: ParsedArguments.parse(["run", "--broker", "b", "--interval", "x"]), environment: [:]))
    }

    func testLaunchAgentPlistNeverContainsPassword() throws {
        var settings = Settings(brokerHost: "b")
        settings.username = "u"
        settings.password = "p"
        let plist = LaunchAgent.plist(label: "local.mcenergy", executable: "/usr/local/bin/mcenergy", settings: settings, logPath: "/tmp/l")
        let arguments = plist["ProgramArguments"] as? [String]
        XCTAssertEqual(arguments?.prefix(4), ["/usr/local/bin/mcenergy", "run", "--broker", "b"])
        XCTAssertFalse(arguments?.contains("p") ?? true)
        XCTAssertNil(plist["EnvironmentVariables"])
        XCTAssertEqual(plist["KeepAlive"] as? Bool, true)
    }

    func testPasswordFallsBackToStore() throws {
        let store = InMemoryPasswordStore()
        try store.store("stored", for: "mac@b:1883")
        let parsed = try ParsedArguments.parse(["run", "--broker", "b", "--user", "mac"])
        XCTAssertEqual(try SettingsBuilder.make(from: parsed, environment: [:], passwordStore: store).password, "stored")
        XCTAssertEqual(try SettingsBuilder.make(from: parsed, environment: [Settings.passwordEnvironmentKey: "env"], passwordStore: store).password, "env")
        let otherUser = try ParsedArguments.parse(["run", "--broker", "b", "--user", "other"])
        XCTAssertNil(try SettingsBuilder.make(from: otherUser, environment: [:], passwordStore: store).password)
    }

    func testKeychainAccountIsUniquePerBrokerAndUser() {
        var settings = Settings(brokerHost: "192.168.0.78")
        XCTAssertEqual(settings.keychainAccount, "anonymous@192.168.0.78:1883")
        settings.username = "mac"
        settings.brokerPort = 8883
        XCTAssertEqual(settings.keychainAccount, "mac@192.168.0.78:8883")
    }
}

final class InMemoryPasswordStore: PasswordStore, @unchecked Sendable {
    private var passwords: [String: String] = [:]
    func password(for account: String) throws -> String? { passwords[account] }
    func store(_ password: String, for account: String) throws { passwords[account] = password }
    func removeAll() throws { passwords.removeAll() }
}
