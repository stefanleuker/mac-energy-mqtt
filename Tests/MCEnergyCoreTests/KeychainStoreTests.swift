import XCTest
@testable import MCEnergyCore

/// Uses a throwaway service name so the real mcenergy item is never touched.
final class KeychainStoreTests: XCTestCase {
    private var store: KeychainStore!

    override func setUp() {
        store = KeychainStore(service: "mcenergy-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try store.removeAll()
    }

    func testStoreReadReplaceAndRemove() throws {
        XCTAssertNil(try store.password(for: "a@b:1"))
        try store.store("first", for: "a@b:1")
        XCTAssertEqual(try store.password(for: "a@b:1"), "first")
        try store.store("second", for: "a@b:1")
        XCTAssertEqual(try store.password(for: "a@b:1"), "second")
        try store.store("other", for: "x@b:1")
        try store.removeAll()
        XCTAssertNil(try store.password(for: "a@b:1"))
        XCTAssertNil(try store.password(for: "x@b:1"))
    }

    func testRemoveAllOnEmptyStoreSucceeds() throws {
        XCTAssertNoThrow(try store.removeAll())
    }
}
