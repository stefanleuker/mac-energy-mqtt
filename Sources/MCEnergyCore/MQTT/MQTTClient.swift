import Foundation
import Network

public enum MQTTError: Error, Equatable {
    case connectionFailed(String)
    case connectionRefused(returnCode: UInt8)
    case unexpectedResponse
    case notConnected
}

/// Minimal MQTT 3.1.1 publisher over Network.framework. QoS 0 only.
public actor MQTTClient {
    public struct Options: Sendable {
        public var host: String
        public var port: UInt16
        public var clientID: String
        public var username: String?
        public var password: String?
        public var keepAlive: UInt16
        public var will: MQTTPacket.Will?
        /// How long a connection may sit in Network.framework's `waiting` state before giving up.
        /// Long enough for a user to answer the macOS "Local Network" permission dialog.
        public var connectTimeout: TimeInterval = 60
        /// Called with the reason whenever the connection has to wait, e.g. a pending permission.
        public var onWaiting: (@Sendable (String) -> Void)?

        public init(host: String, port: UInt16, clientID: String, username: String?, password: String?, keepAlive: UInt16, will: MQTTPacket.Will?) {
            self.host = host
            self.port = port
            self.clientID = clientID
            self.username = username
            self.password = password
            self.keepAlive = keepAlive
            self.will = will
        }
    }

    private let options: Options
    private var connection: NWConnection?

    public init(options: Options) {
        self.options = options
    }

    public func connect() async throws {
        let endpoint = NWEndpoint.hostPort(host: .init(options.host), port: .init(rawValue: options.port)!)
        let connection = NWConnection(to: endpoint, using: .tcp)
        self.connection = connection
        try await waitUntilReady(connection)
        try await send(MQTTPacket.connect(
            clientID: options.clientID, username: options.username, password: options.password,
            keepAlive: options.keepAlive, will: options.will
        ))
        let response = try await receive(exactly: 4)
        guard let code = MQTTPacket.connackReturnCode(response) else { throw MQTTError.unexpectedResponse }
        guard code == 0 else { throw MQTTError.connectionRefused(returnCode: code) }
    }

    public func publish(topic: String, payload: Data, retain: Bool = false) async throws {
        try await send(MQTTPacket.publish(topic: topic, payload: payload, retain: retain))
    }

    public func disconnect() async {
        try? await send(MQTTPacket.disconnect)
        connection?.cancel()
        connection = nil
    }

    /// `waiting` is not treated as failure: Network.framework retries by itself once the path becomes
    /// viable, which is what happens after the user grants Local Network access. The timeout bounds it.
    private func waitUntilReady(_ connection: NWConnection) async throws {
        let queue = DispatchQueue(label: "mcenergy.mqtt")
        let timeout = options.connectTimeout
        let onWaiting = options.onWaiting
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let resumed = ResumeOnce()
            let lastWaitingReason = ReasonBox()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resumed.run { continuation.resume() }
                case .waiting(let error):
                    lastWaitingReason.value = error.localizedDescription
                    onWaiting?(error.localizedDescription)
                case .failed(let error):
                    connection.cancel()
                    resumed.run { continuation.resume(throwing: MQTTError.connectionFailed(error.localizedDescription)) }
                case .cancelled:
                    resumed.run { continuation.resume(throwing: MQTTError.connectionFailed("cancelled")) }
                default:
                    break
                }
            }
            queue.asyncAfter(deadline: .now() + timeout) {
                resumed.run {
                    connection.cancel()
                    let reason = lastWaitingReason.value.map { " (\($0))" } ?? ""
                    continuation.resume(throwing: MQTTError.connectionFailed("timeout after \(Int(timeout))s\(reason)"))
                }
            }
            connection.start(queue: queue)
        }
    }

    private func send(_ data: Data) async throws {
        guard let connection else { throw MQTTError.notConnected }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: MQTTError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func receive(exactly length: Int) async throws -> Data {
        guard let connection else { throw MQTTError.notConnected }
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: length, maximumLength: length) { data, _, _, error in
                if let data, data.count == length {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: MQTTError.connectionFailed(error?.localizedDescription ?? "connection closed"))
                }
            }
        }
    }
}

/// Last `waiting` reason, shared between the state handler and the timeout closure.
private final class ReasonBox: @unchecked Sendable {
    private let lock = NSLock()
    private var reason: String?
    var value: String? {
        get { lock.lock(); defer { lock.unlock() }; return reason }
        set { lock.lock(); reason = newValue; lock.unlock() }
    }
}

/// Guards a continuation against the multiple state callbacks Network.framework may deliver.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        body()
    }
}
