import XCTest
@testable import MCEnergyCore

final class SmartBatteryParserTests: XCTestCase {
    private let macBook: [String: Any] = [
        "BatteryInstalled": true,
        "CurrentCapacity": 98,
        "IsCharging": false,
        "ExternalConnected": true,
        "CycleCount": 67,
        "AdapterDetails": ["Watts": 94],
        "PowerTelemetryData": ["SystemPowerIn": 7627, "AdapterEfficiencyLoss": 7, "BatteryPower": -1500],
    ]

    private let macMini: [String: Any] = [
        "BatteryInstalled": false,
        "ExternalConnected": true,
        "PowerTelemetryData": ["SystemPowerIn": 3379, "AdapterEfficiencyLoss": 484, "BatteryPower": 0],
    ]

    func testSystemPowerConvertsMilliwatts() {
        let power = SmartBatteryParser.systemPower(from: macBook)
        XCTAssertEqual(power, SystemPower(systemPowerIn: 7.627, adapterEfficiencyLoss: 0.007, batteryPower: -1.5))
    }

    func testBatteryStatusOnMacBook() {
        let status = SmartBatteryParser.batteryStatus(from: macBook)
        XCTAssertEqual(status, BatteryStatus(levelPercent: 98, isCharging: false, externalPowerConnected: true, cycleCount: 67, adapterRatedWatts: 94))
    }

    func testAdapterWattsHiddenWhenUnplugged() {
        var unplugged = macBook
        unplugged["ExternalConnected"] = false
        XCTAssertNil(SmartBatteryParser.batteryStatus(from: unplugged)?.adapterRatedWatts)
    }

    func testMacMiniHasSystemPowerButNoBattery() {
        XCTAssertEqual(SmartBatteryParser.systemPower(from: macMini)?.systemPowerIn, 3.379)
        XCTAssertNil(SmartBatteryParser.batteryStatus(from: macMini))
    }

    func testMissingTelemetryYieldsNil() {
        XCTAssertNil(SmartBatteryParser.systemPower(from: [:]))
        XCTAssertNil(SmartBatteryParser.batteryStatus(from: [:]))
    }
}
