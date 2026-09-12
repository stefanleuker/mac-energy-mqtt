import XCTest
@testable import MCEnergyCore

final class EnergyChannelTests: XCTestCase {
    func testUnitConversion() {
        XCTAssertEqual(EnergyUnit.joules(1500, unitLabel: "mJ"), 1.5)
        XCTAssertEqual(EnergyUnit.joules(2_000_000, unitLabel: "uJ"), 2.0)
        XCTAssertEqual(EnergyUnit.joules(38_589_250, unitLabel: "nJ")!, 0.03858925, accuracy: 1e-12)
        XCTAssertNil(EnergyUnit.joules(1, unitLabel: "kWh"))
    }

    func testPrefersPreciseChannelNames() {
        let joules = ["CPU Energy": 3.0, "GPU": 0.5, "GPU Energy": 0.4, "ANE": 0.1, "DRAM": 2.0]
        let power = EnergyChannel.socPower(joulesByChannel: joules, seconds: 2)
        XCTAssertEqual(power, SoCPower(cpu: 1.5, gpu: 0.2, ane: 0.05, dram: 1.0))
        XCTAssertEqual(power?.total, 2.75)
    }

    func testSumsNumberedInstancesOnOlderChips() {
        let m2Pro = ["CPU Energy": 6.46, "GPU Energy": 0.0037, "GPU0": 0.003, "ANE0": 0.1, "DRAM0": 0.496, "DRAM1": 0.004, "DRAMX": 9]
        let power = EnergyChannel.socPower(joulesByChannel: m2Pro, seconds: 1)
        XCTAssertEqual(power, SoCPower(cpu: 6.46, gpu: 0.0037, ane: 0.1, dram: 0.5))
    }

    func testMissingChannelsReadAsZero() {
        let power = EnergyChannel.socPower(joulesByChannel: ["CPU Energy": 1.0], seconds: 1)
        XCTAssertEqual(power, SoCPower(cpu: 1, gpu: 0, ane: 0, dram: 0))
    }

    func testInvalidInputYieldsNil() {
        XCTAssertNil(EnergyChannel.socPower(joulesByChannel: [:], seconds: 1))
        XCTAssertNil(EnergyChannel.socPower(joulesByChannel: ["CPU Energy": 1], seconds: 0))
    }
}
