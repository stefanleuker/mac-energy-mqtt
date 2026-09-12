import Foundation

/// Samples power on a fixed interval and publishes it to Home Assistant over MQTT.
/// Reconnects with backoff whenever the broker connection drops.
public actor HomeAssistantPublisher {
    public typealias Log = @Sendable (String) -> Void

    private let settings: Settings
    private let device: DeviceIdentity
    private let topics: Topics
    private let meter: PowerMeter
    private let log: Log

    public init(settings: Settings, device: DeviceIdentity, meter: PowerMeter, log: @escaping Log) {
        self.settings = settings
        self.device = device
        self.topics = Topics(discoveryPrefix: settings.discoveryPrefix, topicPrefix: settings.topicPrefix, deviceID: device.id)
        self.meter = meter
        self.log = log
    }

    /// Runs until `maxSamples` have been published, or forever when nil.
    public func run(maxSamples: Int? = nil) async throws {
        var published = 0
        var backoff: Double = 2
        while maxSamples.map({ published < $0 }) ?? true {
            let client = MQTTClient(options: clientOptions())
            do {
                try await client.connect()
                backoff = 2
                log("connected to \(settings.brokerHost):\(settings.brokerPort)")
                try await announce(client)
                try await publishLoop(client, maxSamples: maxSamples, published: &published)
                await client.disconnect()
            } catch {
                await client.disconnect()
                log("connection lost: \(error). retrying in \(Int(backoff))s")
                try await Task.sleep(for: .seconds(backoff))
                backoff = min(backoff * 2, 60)
            }
        }
    }

    private func announce(_ client: MQTTClient) async throws {
        let sample = meter.sample()
        for sensor in SensorDefinition.available(for: sample) {
            let payload = DiscoveryConfig.payload(for: sensor, device: device, topics: topics)
            try await client.publish(topic: topics.discovery(for: sensor), payload: try json(payload), retain: true)
        }
        try await client.publish(topic: topics.availability, payload: Data("online".utf8), retain: true)
    }

    private func publishLoop(_ client: MQTTClient, maxSamples: Int?, published: inout Int) async throws {
        while maxSamples.map({ published < $0 }) ?? true {
            try await Task.sleep(for: .seconds(settings.intervalSeconds))
            let sample = meter.sample()
            try await client.publish(topic: topics.state, payload: try json(StatePayload.dictionary(from: sample)))
            published += 1
        }
        try await client.publish(topic: topics.availability, payload: Data("offline".utf8), retain: true)
    }

    private func clientOptions() -> MQTTClient.Options {
        var options = MQTTClient.Options(
            host: settings.brokerHost, port: settings.brokerPort,
            clientID: "\(settings.topicPrefix)-\(device.id)",
            username: settings.username, password: settings.password,
            keepAlive: UInt16(min(65535, max(30, settings.intervalSeconds * 3))),
            will: MQTTPacket.Will(topic: topics.availability, payload: Data("offline".utf8), retain: true)
        )
        let log = self.log
        options.onWaiting = { reason in
            log("waiting for network: \(reason). If macOS asks for Local Network access, allow it.")
        }
        return options
    }

    private func json(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
