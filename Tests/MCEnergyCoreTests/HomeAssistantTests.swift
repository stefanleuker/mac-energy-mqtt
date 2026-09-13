import XCTest
@testable import MCEnergyCore

final class HomeAssistantTests: XCTestCase {
    private let device = DeviceIdentity(id: "deepsea", name: "Deepsea", model: "Mac15,7", serialNumber: "SER123")
    private let topics = Topics(discoveryPrefix: "homeassistant", topicPrefix: "mcenergy", deviceID: "deepsea")

    private var macMiniSample: PowerSample {
        PowerSample(timestamp: Date(), soc: SoCPower(cpu: 1, gpu: 0.5, ane: 0, dram: 0.2),
                    system: SystemPower(systemLoad: 3.379, adapterEfficiencyLoss: 0.484, batteryPower: 0),
                    battery: nil, energyKWh: 0.1234567)
    }

    func testTopics() {
        XCTAssertEqual(topics.state, "mcenergy/deepsea/state")
        XCTAssertEqual(topics.availability, "mcenergy/deepsea/status")
        let cpu = SensorDefinition.all.first { $0.key == "cpu_power" }!
        XCTAssertEqual(topics.discovery(for: cpu), "homeassistant/sensor/mcenergy_deepsea/cpu_power/config")
        let charging = SensorDefinition.all.first { $0.key == "battery_charging" }!
        XCTAssertEqual(topics.discovery(for: charging), "homeassistant/binary_sensor/mcenergy_deepsea/battery_charging/config")
    }

    func testDiscoveryPayloadForPowerSensor() {
        let cpu = SensorDefinition.all.first { $0.key == "cpu_power" }!
        let payload = DiscoveryConfig.payload(for: cpu, device: device, topics: topics)
        XCTAssertEqual(payload["unique_id"] as? String, "mcenergy_deepsea_cpu_power")
        XCTAssertEqual(payload["state_topic"] as? String, "mcenergy/deepsea/state")
        XCTAssertEqual(payload["value_template"] as? String, "{{ value_json.cpu_power }}")
        XCTAssertEqual(payload["unit_of_measurement"] as? String, "W")
        XCTAssertEqual(payload["device_class"] as? String, "power")
        XCTAssertEqual(payload["state_class"] as? String, "measurement")
        XCTAssertEqual(payload["suggested_display_precision"] as? Int, 1)
        XCTAssertEqual(payload["availability_topic"] as? String, "mcenergy/deepsea/status")
        let deviceInfo = payload["device"] as? [String: Any]
        XCTAssertEqual(deviceInfo?["identifiers"] as? [String], ["mcenergy_deepsea", "SER123"])
        XCTAssertEqual(deviceInfo?["model"] as? String, "Mac15,7")
        XCTAssertNil(payload["payload_on"])
    }

    func testBinarySensorPayloadHasOnOff() {
        let charging = SensorDefinition.all.first { $0.key == "battery_charging" }!
        let payload = DiscoveryConfig.payload(for: charging, device: device, topics: topics)
        XCTAssertEqual(payload["payload_on"] as? String, "ON")
        XCTAssertEqual(payload["payload_off"] as? String, "OFF")
        XCTAssertNil(payload["unit_of_measurement"])
        XCTAssertNil(payload["suggested_display_precision"])
    }

    func testAvailableSensorsSkipBatteryOnMacMini() {
        let keys = SensorDefinition.available(for: macMiniSample).map(\.key)
        XCTAssertTrue(keys.contains("system_power"))
        XCTAssertTrue(keys.contains("cpu_power"))
        XCTAssertTrue(keys.contains("energy"))
        XCTAssertFalse(keys.contains("battery_level"))
        XCTAssertFalse(keys.contains("external_power"))
    }

    func testStatePayloadRoundsAndFlattens() {
        let state = StatePayload.dictionary(from: macMiniSample)
        XCTAssertEqual(state["cpu_power"] as? Decimal, 1)
        XCTAssertEqual(state["soc_power"] as? Decimal, Decimal(string: "1.7"))
        XCTAssertEqual(state["system_power"] as? Decimal, Decimal(string: "3.379"))
        XCTAssertEqual(state["energy"] as? Decimal, Decimal(string: "0.123457"))
        XCTAssertNil(state["battery_level"])
    }

    func testStatePayloadSerializesWithoutFloatNoise() throws {
        var sample = macMiniSample
        sample.soc = SoCPower(cpu: 0.6, gpu: 0.034, ane: 0, dram: 0.297)
        let data = try JSONSerialization.data(withJSONObject: StatePayload.dictionary(from: sample), options: [.sortedKeys])
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"cpu_power\":0.6,"), json)
        XCTAssertTrue(json.contains("\"dram_power\":0.297,"), json)
    }

    func testStatePayloadWithBattery() {
        var sample = macMiniSample
        sample.battery = BatteryStatus(levelPercent: 98, isCharging: true, externalPowerConnected: true, cycleCount: 67, adapterRatedWatts: 94)
        let state = StatePayload.dictionary(from: sample)
        XCTAssertEqual(state["battery_level"] as? Int, 98)
        XCTAssertEqual(state["battery_charging"] as? String, "ON")
        XCTAssertEqual(state["external_power"] as? String, "ON")
        XCTAssertEqual(state["adapter_rated_power"] as? Int, 94)
    }

    func testSlug() {
        XCTAssertEqual(DeviceIdentity.slug("Stefan's MacBook Pro"), "stefan_s_macbook_pro")
        XCTAssertEqual(DeviceIdentity.slug("deepsea"), "deepsea")
    }
}
