import XCTest
@testable import MCEnergyCore

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
        let connected = await client.isConnected
        XCTAssertTrue(connected)
        try await client.publish(topic: "mcenergy/x/state", payload: Data("{}".utf8))
        try await client.publish(topic: "mcenergy/x/status", payload: Data("online".utf8), retain: true)
        broker.waitForPublishes(2)
        await client.disconnect()

        XCTAssertEqual(broker.connectPacket, MQTTPacket.connect(clientID: "test", username: "u", password: "p", keepAlive: 30, will: options(port: 1).will))
        XCTAssertEqual(broker.publishes.count, 2)
        XCTAssertEqual(broker.publishes[0].topic, "mcenergy/x/state")
        XCTAssertEqual(broker.publishes[1].payload, Data("online".utf8))
        XCTAssertTrue(broker.publishes[1].retain)
        let stillConnected = await client.isConnected
        XCTAssertFalse(stillConnected)
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
            XCTAssertTrue(error.isAuthenticationFailure)
        }
        let connected = await client.isConnected
        XCTAssertFalse(connected)
    }

    func testBrokerClosingSocketIsNoticedWithoutSending() async throws {
        let broker = try FakeBroker(closesAfterConnack: true)
        broker.start()
        defer { broker.stop() }

        let client = MQTTClient(options: options(port: broker.port))
        try await client.connect()
        for _ in 0..<200 {
            guard await client.isConnected else { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let connected = await client.isConnected
        XCTAssertFalse(connected, "client should notice the closed socket")
        do {
            try await client.publish(topic: "t", payload: Data())
            XCTFail("expected notConnected")
        } catch {
            XCTAssertEqual(error as? MQTTError, .notConnected)
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

    func testCancellationAbortsConnectBeforeTimeout() async {
        var options = options(port: 1883)
        options.host = "10.255.255.1"
        options.connectTimeout = 60
        let client = MQTTClient(options: options)
        let started = Date()
        let connecting = Task { try await client.connect() }
        try? await Task.sleep(for: .milliseconds(100))
        connecting.cancel()
        do {
            try await connecting.value
            XCTFail("expected cancellation")
        } catch {
            XCTAssertLessThan(Date().timeIntervalSince(started), 5)
        }
        let connected = await client.isConnected
        XCTAssertFalse(connected)
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
