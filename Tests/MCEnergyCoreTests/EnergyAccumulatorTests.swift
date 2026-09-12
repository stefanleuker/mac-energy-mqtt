import XCTest
@testable import MCEnergyCore

final class EnergyAccumulatorTests: XCTestCase {
    private var storeURL: URL!

    override func setUp() {
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcenergy-tests-\(UUID().uuidString)/energy.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
    }

    func testIntegratesWattsOverTime() {
        let accumulator = EnergyAccumulator(storeURL: nil)
        let start = Date()
        accumulator.add(watts: 100, at: start)
        accumulator.add(watts: 100, at: start.addingTimeInterval(36))
        XCTAssertEqual(accumulator.kilowattHours, 0.001, accuracy: 1e-9)
    }

    func testLongGapsAreNotCounted() {
        let accumulator = EnergyAccumulator(storeURL: nil)
        let start = Date()
        accumulator.add(watts: 100, at: start)
        accumulator.add(watts: 100, at: start.addingTimeInterval(3600))
        XCTAssertEqual(accumulator.kilowattHours, 0)
        accumulator.add(watts: 100, at: start.addingTimeInterval(3636))
        XCTAssertEqual(accumulator.kilowattHours, 0.001, accuracy: 1e-9)
    }

    func testPersistsAcrossInstances() {
        let start = Date()
        let first = EnergyAccumulator(storeURL: storeURL)
        first.add(watts: 1000, at: start)
        first.add(watts: 1000, at: start.addingTimeInterval(36))

        let second = EnergyAccumulator(storeURL: storeURL)
        XCTAssertEqual(second.kilowattHours, 0.01, accuracy: 1e-9)
    }
}
