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

    func testUnreadableStoreIsReportedAndRestartsAtZero() throws {
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: storeURL)
        let messages = MessageLog()
        let accumulator = EnergyAccumulator(storeURL: storeURL, log: messages.append)
        XCTAssertEqual(accumulator.kilowattHours, 0)
        XCTAssertEqual(messages.all.count, 1)
        XCTAssertTrue(messages.all[0].contains("unreadable"), messages.all[0])
    }

    func testMissingStoreIsSilent() {
        let messages = MessageLog()
        _ = EnergyAccumulator(storeURL: storeURL, log: messages.append)
        XCTAssertTrue(messages.all.isEmpty)
    }

    func testSaveFailureIsReportedOnce() throws {
        let blocker = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: blocker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: blocker) // a file where the directory should be
        let messages = MessageLog()
        let accumulator = EnergyAccumulator(storeURL: storeURL, log: messages.append)
        let start = Date()
        accumulator.add(watts: 1, at: start)
        accumulator.add(watts: 1, at: start.addingTimeInterval(1))
        XCTAssertEqual(messages.all.count, 1)
        XCTAssertTrue(messages.all[0].contains("cannot save"), messages.all[0])
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

private final class MessageLog: @unchecked Sendable {
    private let lock = NSLock()
    private var messages: [String] = []
    var all: [String] { lock.lock(); defer { lock.unlock() }; return messages }
    @Sendable func append(_ message: String) { lock.lock(); messages.append(message); lock.unlock() }
}
