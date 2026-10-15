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
    /// A later bind failed, so the bound order no longer matches the cart.
    private var isStaleOrder = false
    private var bindGeneration = 0
    private var createOrderTask: Task<PaymentIntent, Error>?

    /// True after COMPLETE, FAILED, or post-submit CANCELED for the current order.
    /// Binding a new order via ``present(from:intent:onEvent:)`` clears this.
    public private(set) var isOrderConsumed = false

    /// Site/config returned a usable Apple Pay merchant ID for this order.
    public private(set) var isAvailable = false

    /// PassKit reports this device can make Apple Pay payments.
    public private(set) var isReady = false

    /// Not observable: read it when you render, or after `updateOrder` returns.
    public var isInteractionEnabled: Bool {
        !isProcessing && !isOrderConsumed && !isUpdatingOrder && !isStaleOrder
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
    /// The newest call wins, even when `intent` is already bound. Throws
    /// ``PaymentError/paymentInProgress`` for a different order during a charge.
    /// If the bind fails after an order was bound, `present` stays a no-op on
    /// the stale order until a later update succeeds.
    /// This does not lock Pay while your server creates `intent`; use the
    /// `createOrder` overload when the shopper changes the cart.
    public func updateOrder(intent: PaymentIntent) async throws {
        if isProcessing {
            if payableIntent == intent { return }
            throw PaymentError.paymentInProgress
        }
        bindGeneration += 1
        let generation = bindGeneration
        createOrderTask?.cancel()
        createOrderTask = nil
        if payableIntent == intent, !isOrderConsumed {
            isStaleOrder = false
            isUpdatingOrder = false
            return
        }
        isUpdatingOrder = true
        defer {
            if generation == bindGeneration {
                isUpdatingOrder = false
            }
        }
        try await bindPayableIntent(intent, generation: generation)
    }

    /// Locks the wallet, creates the next signed order, binds it, and returns it.
    ///
    /// `present` is a no-op from this call until the new order is bound,
    /// including while `createOrder` talks to your server. `createOrder` runs
    /// on the main actor. If it throws, the previous order stays bound and
    /// payable. A newer update, or cancelling the calling task, cancels the
    /// in-flight creation task.
    @discardableResult
    public func updateOrder(
        createOrder: @escaping @MainActor () async throws -> PaymentIntent
    ) async throws -> PaymentIntent {
        guard !isProcessing else {
            throw PaymentError.paymentInProgress
        }
        bindGeneration += 1
        let generation = bindGeneration
        isUpdatingOrder = true
        defer {
            if generation == bindGeneration {
                isUpdatingOrder = false
            }
        }
        createOrderTask?.cancel()
        let task = Task { @MainActor in try await createOrder() }
        createOrderTask = task
        let intent: PaymentIntent
        do {
            intent = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            try Task.checkCancellation()
        } catch {
            guard generation == bindGeneration else {
                throw CancellationError()
            }
            createOrderTask = nil
            throw error
        }
        guard generation == bindGeneration else {
            throw CancellationError()
        }
        createOrderTask = nil
        if payableIntent == intent, !isOrderConsumed {
            isStaleOrder = false
            return intent
        }
        try await bindPayableIntent(intent, generation: generation)
        return intent
    }

    private func bindPayableIntent(_ intent: PaymentIntent, generation: Int) async throws {
        let state: SheetState
        do {
            state = try await bindWalletSession(intent: intent)
        } catch {
            guard generation == bindGeneration, !(error is CancellationError), !Task.isCancelled else {
                throw CancellationError()
            }
            if payableIntent != nil {
                isStaleOrder = true
            }
            throw error
        }
        guard generation == bindGeneration else {
            throw CancellationError()
        }
        _ = store(state)
        payableIntent = intent
        isStaleOrder = false
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
        Self.register()
        let payable = payableIntent ?? intent
        let key = "\(payable.orderPayload):\(payable.orderChecksum)"
        guard !isProcessing, !isUpdatingOrder, !isStaleOrder else { return }
        dismissRequested = false
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

                let threeDS = ApplePayThreeDSPresenter(
                    host: PresentationAnchor.resolve(from: presenter),
                    locale: configuration.options.locale
                )
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
        #if DEBUG
        session.testingLoad = testingLoad
        #endif
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

    #if DEBUG
    /// Replaces the network load for `updateOrder` binds.
    var testingLoad: ((PaymentIntent) async throws -> SheetState)?

    var testingPayableIntent: PaymentIntent? { payableIntent }

    func testingInstallPayable(_ intent: PaymentIntent, processing: Bool = false) {
        payableIntent = intent
        isProcessing = processing
    }
    #endif
}
