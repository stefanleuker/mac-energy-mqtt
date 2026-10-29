import Foundation
import Network

/// A tiny in-process broker: answers CONNECT with CONNACK and records every published packet.
final class FakeBroker: @unchecked Sendable {
    struct Publish: Equatable {
        var topic: String
        var payload: Data
        var retain: Bool
    }

    private let listener: NWListener
    private let lock = NSLock()
    private var buffer = Data()
    private var recordedConnect: Data?
    private var recordedPublishes: [Publish] = []
    let connackReturnCode: UInt8
    /// Closes the socket right after CONNACK, like a broker that is shutting down.
    let closesAfterConnack: Bool

    init(connackReturnCode: UInt8 = 0, closesAfterConnack: Bool = false) throws {
        self.connackReturnCode = connackReturnCode
        self.closesAfterConnack = closesAfterConnack
        listener = try NWListener(using: .tcp, on: .any)
    }

    var port: UInt16 { listener.port!.rawValue }

    var connectPacket: Data? { lock.lock(); defer { lock.unlock() }; return recordedConnect }
    var publishes: [Publish] { lock.lock(); defer { lock.unlock() }; return recordedPublishes }

    func start() {
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .global())
            self?.receive(on: connection)
        }
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            if case .ready = state { ready.signal() }
        }
        listener.start(queue: .global())
        ready.wait()
    }

    func stop() { listener.cancel() }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, _ in
            guard let self, let data else { return }
            self.consume(data, connection: connection)
            if !isComplete { self.receive(on: connection) }
        }
    }

    private func consume(_ data: Data, connection: NWConnection) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)
        while let packet = Self.nextPacket(&buffer) {
            switch packet.first! >> 4 {
            case 1:
                recordedConnect = packet
                connection.send(content: Data([0x20, 0x02, 0x00, connackReturnCode]), completion: .contentProcessed { [closesAfterConnack] _ in
                    if closesAfterConnack { connection.cancel() }
                })
            case 3:
                let body = packet.dropFirst(Self.fixedHeaderLength(packet))
                let topicLength = Int(body[body.startIndex]) << 8 | Int(body[body.startIndex + 1])
                let topic = String(decoding: body.dropFirst(2).prefix(topicLength), as: UTF8.self)
                recordedPublishes.append(Publish(topic: topic, payload: body.dropFirst(2 + topicLength), retain: packet.first! & 0x01 == 1))
            default:
                break
            }
        }
    }

    /// Type byte plus the variable-length "remaining length" field.
    private static func fixedHeaderLength(_ packet: Data) -> Int {
        let bytes = [UInt8](packet)
        var index = 1
        while bytes[index] & 0x80 != 0 { index += 1 }
        return index + 1
    }

    private static func nextPacket(_ buffer: inout Data) -> Data? {
        guard buffer.count >= 2 else { return nil }
        let bytes = [UInt8](buffer)
        var length = 0, multiplier = 1, index = 1
        while true {
            guard index < bytes.count else { return nil }
            length += Int(bytes[index] & 0x7F) * multiplier
            if bytes[index] & 0x80 == 0 { break }
            multiplier *= 128
            index += 1
        }
        let total = index + 1 + length
        guard bytes.count >= total else { return nil }
        let packet = buffer.prefix(total)
        buffer = buffer.dropFirst(total)
        return Data(packet)
    }

    /// Polls up to two seconds for `count` publishes; returns whether they arrived.
    @discardableResult
    func waitForPublishes(_ count: Int) -> Bool {
        for _ in 0..<200 {
            if publishes.count >= count { return true }
            usleep(10_000)
        }
        return publishes.count >= count
    }

    func publishes(on topic: String) -> [Publish] { publishes.filter { $0.topic == topic } }
}
