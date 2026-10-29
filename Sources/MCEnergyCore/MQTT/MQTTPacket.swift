import Foundation

/// MQTT 3.1.1 control packet encoding for the subset mcenergy needs.
public enum MQTTPacket {
    public struct Will: Equatable, Sendable {
        public var topic: String
        public var payload: Data
        public var retain: Bool
        public init(topic: String, payload: Data, retain: Bool) {
            self.topic = topic
            self.payload = payload
            self.retain = retain
        }
    }

    /// Longest string or binary field the protocol can carry; longer input is truncated rather than trapping.
    public static let maxFieldLength = Int(UInt16.max)

    /// A password without a username is forbidden by the protocol and dropped here as a last line of defence.
    public static func connect(clientID: String, username: String?, password: String?, keepAlive: UInt16, will: Will?) -> Data {
        var flags: UInt8 = 0x02 // clean session
        var payload = Data()
        payload.append(lengthPrefixed(clientID))
        if let will {
            flags |= 0x04 | (will.retain ? 0x20 : 0)
            payload.append(lengthPrefixed(will.topic))
            payload.append(lengthPrefixed(will.payload))
        }
        if let username {
            flags |= 0x80
            payload.append(lengthPrefixed(username))
            if let password {
                flags |= 0x40
                payload.append(lengthPrefixed(password))
            }
        }
        var body = lengthPrefixed("MQTT")
        body.append(0x04)
        body.append(flags)
        body.append(bigEndian(keepAlive))
        body.append(payload)
        return framed(type: 0x10, body: body)
    }

    public static func publish(topic: String, payload: Data, retain: Bool) -> Data {
        var body = lengthPrefixed(topic)
        body.append(payload)
        return framed(type: 0x30 | (retain ? 0x01 : 0x00), body: body)
    }

    public static let disconnect = Data([0xE0, 0x00])

    /// Returns the CONNACK return code, or nil when the bytes are not a CONNACK.
    public static func connackReturnCode(_ data: Data) -> UInt8? {
        let bytes = [UInt8](data)
        guard bytes.count == 4, bytes[0] == 0x20, bytes[1] == 0x02 else { return nil }
        return bytes[3]
    }

    static func framed(type: UInt8, body: Data) -> Data {
        var packet = Data([type])
        packet.append(remainingLength(body.count))
        packet.append(body)
        return packet
    }

    static func remainingLength(_ length: Int) -> Data {
        var remaining = length
        var encoded = Data()
        repeat {
            var byte = UInt8(remaining % 128)
            remaining /= 128
            if remaining > 0 { byte |= 0x80 }
            encoded.append(byte)
        } while remaining > 0
        return encoded
    }

    static func lengthPrefixed(_ string: String) -> Data {
        lengthPrefixed(Data(string.utf8))
    }

    static func lengthPrefixed(_ data: Data) -> Data {
        let field = data.prefix(maxFieldLength)
        var result = bigEndian(UInt16(field.count))
        result.append(field)
        return result
    }

    static func bigEndian(_ value: UInt16) -> Data {
        Data([UInt8(value >> 8), UInt8(value & 0xFF)])
    }
}
