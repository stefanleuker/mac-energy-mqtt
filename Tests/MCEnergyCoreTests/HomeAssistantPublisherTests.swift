import XCTest
@testable import MCEnergyCore

private struct FixedSampler: PowerSampling {
    func sample() -> PowerSample {
        PowerSample(timestamp: Date(), soc: SoCPower(cpu: 1, gpu: 0, ane: 0, dram: 0),
                    system: SystemPower(systemLoad: 5, adapterEfficiencyLoss: 0.5, batteryPower: 0),
                    battery: nil, energyKWh: nil)
    }
}

final class HomeAssistantPublisherTests: XCTestCase {
    private let device = DeviceIdentity(id: "testmac", name: "Test Mac", model: "Mac15,7", serialNumber: nil)

    private func settings(port: UInt16) -> Settings {
        var settings = Settings(brokerHost: "127.0.0.1")
        settings.brokerPort = port
        settings.intervalSeconds = 0.05
        return settings
    }

    private func makePublisher(port: UInt16) -> HomeAssistantPublisher {
        HomeAssistantPublisher(settings: settings(port: port), device: device, meter: FixedSampler(), log: { _ in })
    }

    func testAnnouncesPublishesAndGoesOffline() async throws {
        let broker = try FakeBroker()
        broker.start()
        defer { broker.stop() }

        try await makePublisher(port: broker.port).run(maxSamples: 2)
        XCTAssertTrue(broker.waitForPublishes(11), "7 discovery, online, 2 states, offline")

        let discovery = broker.publishes.filter { $0.topic.hasPrefix("homeassistant/sensor/mcenergy_testmac/") }
        XCTAssertEqual(discovery.count, 7, "system, adapter loss, and five SoC sensors")
        XCTAssertTrue(discovery.allSatisfy(\.retain))
        XCTAssertTrue(discovery.contains { $0.topic == "homeassistant/sensor/mcenergy_testmac/cpu_power/config" })
        XCTAssertEqual(broker.publishes(on: "mcenergy/testmac/state").count, 2)
        let availability = broker.publishes(on: "mcenergy/testmac/status").map { String(decoding: $0.payload, as: UTF8.self) }
        XCTAssertEqual(availability, ["online", "offline"])
    }

    func testCancellationMarksDeviceOfflineBeforeLeaving() async throws {
        let broker = try FakeBroker()
        broker.start()
        defer { broker.stop() }

        let publisher = makePublisher(port: broker.port)
        let running = Task { try await publisher.run() }
        XCTAssertTrue(broker.waitForPublishes(9), "discovery, online and at least one state publish")
        running.cancel()
        do {
            try await running.value
            XCTFail("expected CancellationError")
        } catch is CancellationError {
        }
        XCTAssertTrue(broker.waitForPublishes(10), "offline follows the cancellation")
        let availability = broker.publishes(on: "mcenergy/testmac/status").map { String(decoding: $0.payload, as: UTF8.self) }
        XCTAssertEqual(availability, ["online", "offline"])
    }

    func testRetryDelayDoublesUpToMaximum() {
        let lost = MQTTError.connectionFailed("reset")
        XCTAssertEqual(HomeAssistantPublisher.nextRetryDelay(after: lost, previous: 1), 2)
        XCTAssertEqual(HomeAssistantPublisher.nextRetryDelay(after: lost, previous: 32), 60)
        XCTAssertEqual(HomeAssistantPublisher.nextRetryDelay(after: lost, previous: 60), 60)
    }

    func testBadCredentialsBackOffForMinutes() {
        XCTAssertEqual(HomeAssistantPublisher.nextRetryDelay(after: MQTTError.connectionRefused(returnCode: 4), previous: 1), 300)
        XCTAssertEqual(HomeAssistantPublisher.nextRetryDelay(after: MQTTError.connectionRefused(returnCode: 5), previous: 1), 300)
        XCTAssertEqual(HomeAssistantPublisher.nextRetryDelay(after: MQTTError.connectionRefused(returnCode: 3), previous: 1), 2)
    }
}
