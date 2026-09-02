import UIKit
#if canImport(XMoneyCore)
@_exported import XMoneyCore
#endif

@MainActor
public final class ApplePay {
    private let configuration: PaymentConfig
    private let onResult: (PaymentResult) -> Void

    private var isProcessing = false
    private var threeDSPresenter: ApplePayThreeDSPresenter?
    private var applePayHandler: ApplePayHandler?

    private var consumedOrderKey: String?
    private var dismissRequested = false
    private var payableIntent: PaymentIntent?
    private var isUpdatingOrder = false

    /// True after COMPLETE, FAILED, or post-submit CANCELED for the current order.
    /// Binding a new order via ``present(from:intent:onEvent:)`` clears this.
    public private(set) var isOrderConsumed = false

    /// Site/config returned a usable Apple Pay merchant ID for this order.
    public private(set) var isAvailable = false

    /// PassKit reports this device can make Apple Pay payments.
    public private(set) var isReady = false

    public var isInteractionEnabled: Bool {
        !isProcessing && !isOrderConsumed && !isUpdatingOrder
    }

    public static func register() {
        ApplePayBootstrap.install()
    }

    public init(
        configuration: PaymentConfig,
        onResult: @escaping (PaymentResult) -> Void
    ) {
        Self.register()
        self.configuration = configuration
        self.onResult = onResult
    }

    /// Bind without presenting PassKit and return controller-equivalent availability flags.
    /// Load / setup failures resolve to both flags false. `CancellationError` is rethrown.
    public func availability(intent: PaymentIntent) async throws -> ApplePayAvailability {
        do {
            return store(try await bindWalletSession(intent: intent))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            clearAvailability()
            return ApplePayAvailability(isAvailable: false, isReady: false)
        }
    }

    /// Validates and stores `intent` as the next payable order. Pay is locked until this returns.
    public func updateOrder(intent: PaymentIntent) async throws {
        guard !isProcessing else {
            throw PaymentError.payment("Payment in progress")
        }
        isUpdatingOrder = true
        defer { isUpdatingOrder = false }
        let state = try await bindWalletSession(intent: intent)
        _ = store(state)
        payableIntent = intent
        let key = "\(intent.orderPayload):\(intent.orderChecksum)"
        if consumedOrderKey != key {
            isOrderConsumed = false
        }
    }

    public func present(
        from presenter: UIViewController,
        intent: PaymentIntent,
        onEvent: ((ApplePayEvent) -> Void)? = nil
    ) {
        guard !isProcessing, !isUpdatingOrder else { return }
        Self.register()
        dismissRequested = false
        let payable = payableIntent ?? intent
        let key = "\(payable.orderPayload):\(payable.orderChecksum)"
        if consumedOrderKey == key, isOrderConsumed { return }
        if consumedOrderKey != key {
            isOrderConsumed = false
        }

        isProcessing = true
        onEvent?(.processing(true))

        Task { @MainActor in
            do {
                var config = configuration
                config.paymentMethods.applePay.enabled = true
                let session = try PaymentSession(configuration: config, intent: payable)
                let state = try await session.bind(intent: payable)
                _ = store(state)

                guard state.applePayAvailable, state.applePayReady else {
                    deliverLoadOrSetupFailure(
                        .applePay("Apple Pay is not available on this device."),
                        onEvent: onEvent
                    )
                    return
                }

                onEvent?(.ready)

                let threeDS = ApplePayThreeDSPresenter(host: PresentationAnchor.resolve(from: presenter))
                self.threeDSPresenter = threeDS
                guard let authorizer = session.makeWalletAuthorizer(presenter: threeDS) else {
                    deliverLoadOrSetupFailure(
                        .applePay("Apple Pay is not available on this device."),
                        onEvent: onEvent
                    )
                    return
                }
                self.applePayHandler = authorizer as? ApplePayHandler
                if self.dismissRequested {
                    deliver(
                        .init(
                            status: .canceled,
                            transaction: nil,
                            errorCode: nil,
                            errorMessage: nil
                        ),
                        onEvent: onEvent
                    )
                    return
                }

                let result = await session.startWallet(authorizer)
                deliver(result, onEvent: onEvent)
                self.isOrderConsumed = session.isOrderConsumed
                if session.isOrderConsumed {
                    self.consumedOrderKey = key
                }
            } catch let error as PaymentError {
                deliverLoadOrSetupFailure(error, onEvent: onEvent)
            } catch {
                deliverLoadOrSetupFailure(
                    .load(error.localizedDescription),
                    onEvent: onEvent
                )
            }
        }
    }

    /// Dismisses the Apple Pay sheet if it is visible and the user has not
    /// authorized yet. No-op during token submit / 3DS.
    public func dismiss() {
        Task { @MainActor in
            if self.applePayHandler?.didAuthorizePayment == true { return }
            self.dismissRequested = true
            self.applePayHandler?.dismiss()
        }
    }

    // MARK: - Bind / flags

    private func bindWalletSession(intent: PaymentIntent) async throws -> SheetState {
        Self.register()
        var config = configuration
        config.paymentMethods.applePay.enabled = true
        let session = try PaymentSession(configuration: config, intent: intent)
        return try await session.bind(intent: intent)
    }

    private func store(_ state: SheetState) -> ApplePayAvailability {
        let flags = ApplePayAvailability(
            isAvailable: state.applePayAvailable,
            isReady: state.applePayReady
        )
        isAvailable = flags.isAvailable
        isReady = flags.isReady
        return flags
    }

    private func clearAvailability() {
        isAvailable = false
        isReady = false
    }

    // MARK: - Result delivery

    private func deliverLoadOrSetupFailure(
        _ error: PaymentError,
        onEvent: ((ApplePayEvent) -> Void)?
    ) {
        isProcessing = false
        // Load / capability failures do not consume the order.
        onEvent?(.processing(false))
        onResult(.failed(error.merchantFacing()))
        threeDSPresenter = nil
        applePayHandler = nil
    }

    private func deliver(
        _ result: EngineResult,
        onEvent: ((ApplePayEvent) -> Void)?
    ) {
        isProcessing = false
        defer {
            threeDSPresenter = nil
            applePayHandler = nil
        }

        onEvent?(.processing(false))
        onResult(OrderConsumption.merchantResult(result))
    }
}
