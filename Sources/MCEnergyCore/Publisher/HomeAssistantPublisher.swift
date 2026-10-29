import Foundation

/// Samples power on a fixed interval and publishes it to Home Assistant over MQTT.
/// Reconnects with backoff whenever the broker connection drops; on cancellation it marks the
/// device offline before leaving so Home Assistant does not have to wait for the will.
public actor HomeAssistantPublisher {
    public typealias Log = @Sendable (String) -> Void

    static let initialRetryDelay: Double = 1
    static let maxRetryDelay: Double = 60
    static let authenticationRetryDelay: Double = 300

    private let settings: Settings
    private let device: DeviceIdentity
    private let topics: Topics
    private let meter: any PowerSampling
    private let log: Log
    private var retryDelay = HomeAssistantPublisher.initialRetryDelay

    public init(settings: Settings, device: DeviceIdentity, meter: any PowerSampling, log: @escaping Log) {
        self.settings = settings
        self.device = device
        self.topics = Topics(discoveryPrefix: settings.discoveryPrefix, topicPrefix: settings.topicPrefix, deviceID: device.id)
        self.meter = meter
        self.log = log
    }

    /// Runs until `maxSamples` have been published, or forever when nil. Throws `CancellationError` once
    /// the task is cancelled and the device has been marked offline.
    public func run(maxSamples: Int? = nil) async throws {
        var published = 0
        while maxSamples.map({ published < $0 }) ?? true {
            let client = MQTTClient(options: clientOptions())
            do {
                try await client.connect()
                log("connected to \(settings.brokerHost):\(settings.brokerPort)")
                try await announce(client)
                try await publishLoop(client, maxSamples: maxSamples, published: &published)
                await goOffline(client)
            } catch is CancellationError {
                await goOffline(client)
                log("stopped")
                throw CancellationError()
            } catch {
                await client.disconnect()
                if Task.isCancelled { throw CancellationError() }
                retryDelay = Self.nextRetryDelay(after: error, previous: retryDelay)
                log("connection lost: \(error). retrying in \(Int(retryDelay))s")
                try await Task.sleep(for: .seconds(retryDelay))
            }
        }
    }

    /// Bad credentials are not transient: retrying every minute only risks a broker lockout.
    static func nextRetryDelay(after error: Error, previous: Double) -> Double {
        if let mqttError = error as? MQTTError, mqttError.isAuthenticationFailure { return authenticationRetryDelay }
        return min(previous * 2, maxRetryDelay)
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
            retryDelay = Self.initialRetryDelay
        }
    }

    private func goOffline(_ client: MQTTClient) async {
        try? await client.publish(topic: topics.availability, payload: Data("offline".utf8), retain: true)
        await client.disconnect()
    }

    private func clientOptions() -> MQTTClient.Options {
        var options = MQTTClient.Options(
            host: settings.brokerHost, port: settings.brokerPort,
            clientID: "\(settings.topicPrefix)-\(device.id)",
            username: settings.username, password: settings.password,
            keepAlive: UInt16(min(65535, max(30, settings.intervalSeconds * 3))),
            will: MQTTPacket.Will(topic: topics.availability, payload: Data("offline".utf8), retain: true)
        )
        options.useTLS = settings.useTLS
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
