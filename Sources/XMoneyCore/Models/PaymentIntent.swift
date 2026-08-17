import Foundation

public struct OrderPayload: Equatable, Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}

public struct OrderChecksum: Equatable, Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}

public struct OrderCredentials: Equatable, Sendable {
    public let orderPayload: OrderPayload
    public let orderChecksum: OrderChecksum

    public init(orderPayload: OrderPayload, orderChecksum: OrderChecksum) {
        self.orderPayload = orderPayload
        self.orderChecksum = orderChecksum
    }
}

/// Order credentials produced by the merchant backend for a single checkout session.
public struct PaymentIntent: Equatable, Sendable {
    public let credentials: OrderCredentials

    public var orderPayload: String { credentials.orderPayload.value }
    public var orderChecksum: String { credentials.orderChecksum.value }

    public init(credentials: OrderCredentials) {
        self.credentials = credentials
    }

    public init(orderPayload: OrderPayload, orderChecksum: OrderChecksum) {
        self.credentials = OrderCredentials(orderPayload: orderPayload, orderChecksum: orderChecksum)
    }
}
