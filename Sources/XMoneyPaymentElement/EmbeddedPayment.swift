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

    /// In-flight charge only. `updateOrder` does not set this.
    public var isProcessing: Bool { controller.isProcessing }

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
    /// title — this does not emit ``EmbeddedEvent/processing(_:)``. A newer
    /// `updateOrder` cancels the in-flight one.
    public func updateOrder(intent: PaymentIntent) async throws {
        try await controller.prepare(intent: intent)
    }

    public func updateOrder(
        intent: PaymentIntent,
        onEvent: @escaping (EmbeddedEvent) -> Void
    ) async throws {
        try await controller.prepare(intent: intent, onEvent: onEvent)
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
