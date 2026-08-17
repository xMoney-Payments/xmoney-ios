import Foundation
#if canImport(XMoneyCore)
@_exported import XMoneyCore
#endif

@MainActor
public final class EmbeddedPayment {
    private let controller: EmbeddedPaymentController

    public init(
        configuration: PaymentConfig,
        onResult: @escaping (PaymentResult) -> Void
    ) {
        self.controller = EmbeddedPaymentController(
            configuration: configuration,
            onResult: onResult
        )
    }

    public var isOrderConsumed: Bool { controller.isOrderConsumed }

    public var isProcessing: Bool { controller.isProcessing }

    /// Prepares the embedded surface for `intent`. Clears `isOrderConsumed` when the order changes.
    public func prepare(intent: PaymentIntent) async throws {
        try await controller.prepare(intent: intent)
    }

    public func prepare(
        intent: PaymentIntent,
        onEvent: @escaping (EmbeddedEvent) -> Void
    ) async throws {
        try await controller.prepare(intent: intent, onEvent: onEvent)
    }

    var _controller: EmbeddedPaymentController { controller }
}
