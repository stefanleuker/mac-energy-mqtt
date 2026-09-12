import Foundation

/// Reads the "Energy Model" IOReport group and turns counter deltas into watts.
public final class EnergyModelReader: @unchecked Sendable {
    private let subscription: UnsafeMutableRawPointer
    private let subscribedChannels: CFMutableDictionary
    private var previousSample: CFDictionary
    private var previousTime: Date

    public init?() {
        guard let desired = IOReportCopyChannelsInGroup("Energy Model" as CFString, nil, 0, 0, 0)?.takeRetainedValue()
        else { return nil }
        var subscribed: Unmanaged<CFMutableDictionary>?
        guard let subscription = IOReportCreateSubscription(nil, desired, &subscribed, 0, nil),
              let subscribedChannels = subscribed?.takeRetainedValue(),
              let first = IOReportCreateSamples(subscription, subscribedChannels, nil)?.takeRetainedValue()
        else { return nil }
        self.subscription = subscription
        self.subscribedChannels = subscribedChannels
        self.previousSample = first
        self.previousTime = Date()
    }

    /// Average SoC power since the previous call.
    public func read() -> SoCPower? {
        guard let current = IOReportCreateSamples(subscription, subscribedChannels, nil)?.takeRetainedValue(),
              let delta = IOReportCreateSamplesDelta(previousSample, current, nil)?.takeRetainedValue()
        else { return nil }
        let now = Date()
        let seconds = now.timeIntervalSince(previousTime)
        previousSample = current
        previousTime = now
        return EnergyChannel.socPower(joulesByChannel: Self.joulesByChannel(delta), seconds: seconds)
    }

    public struct RawChannel: Equatable, Sendable {
        public var name: String
        public var unitLabel: String
        public var value: Int64
    }

    /// Every channel with its raw counter delta since the previous call, for diagnosing new chips.
    public func readRawChannels() -> [RawChannel] {
        guard let current = IOReportCreateSamples(subscription, subscribedChannels, nil)?.takeRetainedValue(),
              let delta = IOReportCreateSamplesDelta(previousSample, current, nil)?.takeRetainedValue()
        else { return [] }
        previousSample = current
        previousTime = Date()
        return Self.rawChannels(delta)
    }

    private static func rawChannels(_ delta: CFDictionary) -> [RawChannel] {
        guard let channels = (delta as NSDictionary)["IOReportChannels"] as? [NSDictionary] else { return [] }
        return channels.compactMap { channel in
            let cf = channel as CFDictionary
            guard let name = IOReportChannelGetChannelName(cf)?.takeUnretainedValue() as String?,
                  let unit = IOReportChannelGetUnitLabel(cf)?.takeUnretainedValue() as String?
            else { return nil }
            return RawChannel(name: name, unitLabel: unit, value: IOReportSimpleGetIntegerValue(cf, 0))
        }
    }

    private static func joulesByChannel(_ delta: CFDictionary) -> [String: Double] {
        var result: [String: Double] = [:]
        for channel in rawChannels(delta) {
            if let joules = EnergyUnit.joules(channel.value, unitLabel: channel.unitLabel) {
                result[channel.name] = joules
            }
        }
        return result
    }
}
