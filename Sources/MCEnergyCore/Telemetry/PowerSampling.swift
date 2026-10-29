import Foundation

/// Anything that can produce a `PowerSample`; lets the publisher be tested without hardware.
public protocol PowerSampling: Sendable {
    func sample() -> PowerSample
}
