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

    /// The order Pay charges, or `nil` before the first successful bind.
    /// A custom host that forwards the intent returned by `updateOrder { }`
    /// can skip calling `updateOrder(intent:)` when it equals this, so the
    /// echo does not cancel a newer update.
    public var boundIntent: PaymentIntent? { controller.boundIntent }

    /// In-flight charge only. `updateOrder` does not set this.
    public var isProcessing: Bool { controller.isProcessing }

    /// False while an update runs, while a charge is in flight, after the order
    /// is consumed, and after a later bind failed (stale order).
    public var isInteractionEnabled: Bool { controller.isInteractionEnabled }

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

    /// Rebinds a new signed order without tearing down the embedded surface.
    ///
    /// Pay, `confirm()`, and Apple Pay are no-ops until this returns
    /// (`isInteractionEnabled` is false). The Pay button keeps its current
    /// title — this does not emit ``EmbeddedEvent/processing(_:)``. The newest
    /// call wins: it cancels any in-flight update, even when `intent` is the
    /// order that is already bound. Throws ``PaymentError/paymentInProgress``
    /// for a different order while a charge is in flight. If the bind fails
    /// after an order was bound, Pay stays locked on the stale order and
    /// ``EmbeddedEvent/updateFailed(_:)`` is emitted.
    /// This does not lock Pay while your server creates `intent`; use the
    /// `createOrder` overload when the shopper changes the cart.
    public func updateOrder(intent: PaymentIntent) async throws {
        try await controller.prepare(intent: intent)
    }

    public func updateOrder(
        intent: PaymentIntent,
        onEvent: @escaping (EmbeddedEvent) -> Void
    ) async throws {
        try await controller.prepare(intent: intent, onEvent: onEvent)
    }

    /// Locks Pay, creates the next signed order, binds it without tearing
    /// down the embedded surface, and returns the bound intent.
    ///
    /// Pay, `confirm()`, and Apple Pay are no-ops from this call until the new
    /// order is bound, including while `createOrder` talks to your server.
    /// `createOrder` runs on the main actor. If it throws, the previous order
    /// stays bound and payable. A newer update, or cancelling the calling task,
    /// cancels the in-flight creation task.
    @discardableResult
    public func updateOrder(
        createOrder: @escaping @MainActor () async throws -> PaymentIntent
    ) async throws -> PaymentIntent {
        try await controller.updateOrder(createOrder: createOrder)
    }

    /// `onEvent` comes first so `createOrder` can stay a trailing closure.
    @discardableResult
    public func updateOrder(
        onEvent: @escaping (EmbeddedEvent) -> Void,
        createOrder: @escaping @MainActor () async throws -> PaymentIntent
    ) async throws -> PaymentIntent {
        try await controller.updateOrder(onEvent: onEvent, createOrder: createOrder)
    }

    public func updateAppearance(_ appearance: PaymentConfig.AppearanceConfig) {
        controller.updateAppearance(appearance)
    }

    public func updateLocale(_ locale: String) {
        controller.updateLocale(locale)
    }

    public func updateStyle(_ style: PaymentConfig.UserInterfaceStyle) {
        controller.updateStyle(style)
    }

    public func updateWalletAppearance(_ appearance: PaymentConfig.WalletAppearance) {
        controller.updateWalletAppearance(appearance)
    }

    /// Submit the currently selected method (new card or saved card).
    /// Use with `SubmitButtonConfig.visible = false` so the merchant owns the Pay CTA.
    /// No-op while `isInteractionEnabled` is false (`updateOrder` or an in-flight charge).
    public func confirm() {
        controller.confirm()
    }

    var _controller: EmbeddedPaymentController { controller }
}
