import XCTest
@testable import MCEnergyCore

final class MQTTPacketTests: XCTestCase {
    func testConnectWithCredentialsAndWill() {
        let will = MQTTPacket.Will(topic: "t/s", payload: Data("off".utf8), retain: true)
        let packet = MQTTPacket.connect(clientID: "id", username: "u", password: "p", keepAlive: 60, will: will)
        let expected: [UInt8] = [
            0x10, 30,
            0, 4, 0x4D, 0x51, 0x54, 0x54, 4,
            0x02 | 0x04 | 0x20 | 0x80 | 0x40,
            0, 60,
            0, 2, 0x69, 0x64,
            0, 3, 0x74, 0x2F, 0x73,
            0, 3, 0x6F, 0x66, 0x66,
            0, 1, 0x75,
            0, 1, 0x70,
        ]
        XCTAssertEqual([UInt8](packet), expected)
    }

    func testConnectWithoutOptionalFields() {
        let packet = [UInt8](MQTTPacket.connect(clientID: "a", username: nil, password: nil, keepAlive: 30, will: nil))
        XCTAssertEqual(packet[9], 0x02)
        XCTAssertEqual(packet.count, 2 + 10 + 3)
    }

    func testPasswordWithoutUsernameIsDropped() {
        let packet = MQTTPacket.connect(clientID: "a", username: nil, password: "secret", keepAlive: 30, will: nil)
        XCTAssertEqual(packet, MQTTPacket.connect(clientID: "a", username: nil, password: nil, keepAlive: 30, will: nil))
    }

    func testOverlongFieldsAreTruncatedInsteadOfTrapping() {
        let field = MQTTPacket.lengthPrefixed(Data(count: 70_000))
        XCTAssertEqual(field.count, 2 + MQTTPacket.maxFieldLength)
        XCTAssertEqual([UInt8](field.prefix(2)), [0xFF, 0xFF])
    }

    func testPublishRetained() {
        let packet = [UInt8](MQTTPacket.publish(topic: "a/b", payload: Data("1".utf8), retain: true))
        XCTAssertEqual(packet, [0x31, 6, 0, 3, 0x61, 0x2F, 0x62, 0x31])
    }

    func testRemainingLengthUsesContinuationBytes() {
        XCTAssertEqual([UInt8](MQTTPacket.remainingLength(127)), [0x7F])
        XCTAssertEqual([UInt8](MQTTPacket.remainingLength(128)), [0x80, 0x01])
        XCTAssertEqual([UInt8](MQTTPacket.remainingLength(321)), [0xC1, 0x02])
    }

    func testConnackParsing() {
        XCTAssertEqual(MQTTPacket.connackReturnCode(Data([0x20, 0x02, 0x00, 0x00])), 0)
        XCTAssertEqual(MQTTPacket.connackReturnCode(Data([0x20, 0x02, 0x00, 0x05])), 5)
        XCTAssertNil(MQTTPacket.connackReturnCode(Data([0x30, 0x02, 0x00, 0x00])))
        XCTAssertNil(MQTTPacket.connackReturnCode(Data([0x20, 0x02])))
    }
}
