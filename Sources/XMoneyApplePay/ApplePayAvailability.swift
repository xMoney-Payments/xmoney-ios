import Foundation

/// Site/config allows Apple Pay (`isAvailable`) and PassKit reports a
/// usable device (`isReady`). Same flags as ``ApplePay``.
public struct ApplePayAvailability: Equatable {
    /// Site/config returned a usable Apple Pay merchant ID for this order.
    public let isAvailable: Bool
    /// PassKit reports this device can make Apple Pay payments.
    public let isReady: Bool

    public init(isAvailable: Bool, isReady: Bool) {
        self.isAvailable = isAvailable
        self.isReady = isReady
    }
}
