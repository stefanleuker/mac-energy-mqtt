import Network
import XCTest
@testable import MCEnergyCore

/// A tiny in-process broker: answers CONNECT with CONNACK and records every published packet.
private final class FakeBroker: @unchecked Sendable {
    private let listener: NWListener
    private let lock = NSLock()
    private var buffer = Data()
    private(set) var connectPacket: Data?
    private(set) var publishes: [(topic: String, payload: Data, retain: Bool)] = []
    let connackReturnCode: UInt8

    init(connackReturnCode: UInt8 = 0) throws {
        self.connackReturnCode = connackReturnCode
        listener = try NWListener(using: .tcp, on: .any)
    }

    var port: UInt16 { listener.port!.rawValue }

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
                connectPacket = packet
                connection.send(content: Data([0x20, 0x02, 0x00, connackReturnCode]), completion: .idempotent)
            case 3:
                let body = packet.dropFirst(2)
                let topicLength = Int(body[body.startIndex]) << 8 | Int(body[body.startIndex + 1])
                let topic = String(decoding: body.dropFirst(2).prefix(topicLength), as: UTF8.self)
                publishes.append((topic, body.dropFirst(2 + topicLength), packet.first! & 0x01 == 1))
            default:
                break
            }
        }
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

    func waitForPublishes(_ count: Int) {
        for _ in 0..<200 {
            lock.lock(); let done = publishes.count >= count; lock.unlock()
            if done { return }
            usleep(10_000)
        }
    }
}

final class MQTTClientTests: XCTestCase {
    private func options(port: UInt16) -> MQTTClient.Options {
        MQTTClient.Options(host: "127.0.0.1", port: port, clientID: "test", username: "u", password: "p", keepAlive: 30,
                           will: MQTTPacket.Will(topic: "w", payload: Data("offline".utf8), retain: true))
    }

    func testConnectPublishDisconnect() async throws {
        let broker = try FakeBroker()
        broker.start()
        defer { broker.stop() }

        let client = MQTTClient(options: options(port: broker.port))
        try await client.connect()
        try await client.publish(topic: "mcenergy/x/state", payload: Data("{}".utf8))
        try await client.publish(topic: "mcenergy/x/status", payload: Data("online".utf8), retain: true)
        broker.waitForPublishes(2)
        await client.disconnect()

        XCTAssertEqual(broker.connectPacket, MQTTPacket.connect(clientID: "test", username: "u", password: "p", keepAlive: 30, will: options(port: 1).will))
        XCTAssertEqual(broker.publishes.count, 2)
        XCTAssertEqual(broker.publishes[0].topic, "mcenergy/x/state")
        XCTAssertEqual(broker.publishes[1].payload, Data("online".utf8))
        XCTAssertTrue(broker.publishes[1].retain)
    }

    func testRefusedConnectionThrows() async throws {
        let broker = try FakeBroker(connackReturnCode: 5)
        broker.start()
        defer { broker.stop() }

        let client = MQTTClient(options: options(port: broker.port))
        do {
            try await client.connect()
            XCTFail("expected refusal")
        } catch let error as MQTTError {
            XCTAssertEqual(error, .connectionRefused(returnCode: 5))
        }
    }

    func testConnectTimesOutWhileWaiting() async {
        var options = options(port: 1883)
        options.host = "10.255.255.1" // non-routable, keeps the connection in preparing/waiting
        options.connectTimeout = 1
        let client = MQTTClient(options: options)
        let started = Date()
        do {
            try await client.connect()
            XCTFail("expected timeout")
        } catch let error as MQTTError {
            guard case .connectionFailed(let reason) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertTrue(reason.hasPrefix("timeout after 1s"), reason)
            XCTAssertLessThan(Date().timeIntervalSince(started), 5)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testPublishWithoutConnectionThrows() async {
        let client = MQTTClient(options: options(port: 1))
        do {
            try await client.publish(topic: "t", payload: Data())
            XCTFail("expected notConnected")
        } catch {
            XCTAssertEqual(error as? MQTTError, .notConnected)
        }
    }
}
