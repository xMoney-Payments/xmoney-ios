import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

@MainActor
final class EmbeddedPaymentController: NSObject, ThreeDSPresenter {
    private var liveConfiguration: PaymentConfig
    private let onResult: (PaymentResult) -> Void

    private(set) var paymentConfig: PaymentConfig?
    private var session: PaymentSession?
    private var onEvent: (EmbeddedEvent) -> Void = { _ in }
    private var threeDSSession: ThreeDSSafariController?
    private weak var hostView: UIView?
    private var prepareGeneration = 0
    private var boundIntent: PaymentIntent?
    private var createOrderTask: Task<PaymentIntent, Error>?
    private var operationTask: Task<Void, Never>?
    private var submitHandler: (() -> Void)?
    private var onLiveConfigChange: (() -> Void)?
    private var onUpdatingOrderChange: ((Bool) -> Void)?
    private var onOrderBound: ((SheetState) -> Void)?
    private(set) var isUpdatingOrder = false {
        didSet {
            guard isUpdatingOrder != oldValue else { return }
            onUpdatingOrderChange?(isUpdatingOrder)
        }
    }

    var sheetState: SheetState? { session?.state }
    /// In-flight charge only. Order rebind uses `isUpdatingOrder`, not this flag.
    var isProcessing: Bool { session?.isProcessing ?? false }
    var isOrderConsumed: Bool { session?.isOrderConsumed ?? false }
    var isInteractionEnabled: Bool {
        !isUpdatingOrder && (session?.isInteractionEnabled ?? false)
    }

    init(
        configuration: PaymentConfig,
        onResult: @escaping (PaymentResult) -> Void
    ) {
        self.liveConfiguration = configuration
        self.onResult = onResult
    }

    func attachHostView(_ view: UIView) {
        hostView = view
    }

    func setOnLiveConfigChange(_ handler: (() -> Void)?) {
        onLiveConfigChange = handler
    }

    func setOnUpdatingOrderChange(_ handler: ((Bool) -> Void)?) {
        onUpdatingOrderChange = handler
        handler?(isUpdatingOrder)
    }

    func setOnOrderBound(_ handler: ((SheetState) -> Void)?) {
        onOrderBound = handler
    }

    func emit(_ event: EmbeddedEvent) {
        onEvent(event)
    }

    /// Submit the currently selected method (new card or saved card).
    /// Use with `SubmitButtonConfig.visible = false` so the merchant owns the Pay CTA.
    func confirm() {
        guard isInteractionEnabled else { return }
        submitHandler?()
    }

    func bindSubmitHandler(_ handler: (() -> Void)?) {
        submitHandler = handler
    }

    func updateAppearance(_ appearance: PaymentConfig.AppearanceConfig) {
        liveConfiguration.options.appearance = appearance
        publishLiveConfig()
    }

    func updateLocale(_ locale: String) {
        liveConfiguration.options.locale = locale
        publishLiveConfig()
    }

    func updateStyle(_ style: PaymentConfig.UserInterfaceStyle) {
        liveConfiguration.options.style = style
        publishLiveConfig()
    }

    func updateWalletAppearance(_ appearance: PaymentConfig.WalletAppearance) {
        liveConfiguration.paymentMethods.applePay.appearance = appearance
        publishLiveConfig()
    }

    private func publishLiveConfig() {
        paymentConfig = liveConfiguration
        onLiveConfigChange?()
    }

    func prepare(intent: PaymentIntent, onEvent: ((EmbeddedEvent) -> Void)? = nil) async throws {
        if let onEvent {
            self.onEvent = onEvent
        }
        paymentConfig = liveConfiguration
        if boundIntent == intent, session?.state != nil, session?.isOrderConsumed == false {
            return
        }
        prepareGeneration += 1
        let generation = prepareGeneration
        createOrderTask?.cancel()
        createOrderTask = nil
        guard !(session?.isProcessing ?? false) else {
            throw PaymentError.payment("Payment in progress")
        }
        isUpdatingOrder = true

        try await bindLocked(intent: intent, generation: generation)
    }

    func updateOrder(
        onEvent: ((EmbeddedEvent) -> Void)? = nil,
        createOrder: @escaping () async throws -> PaymentIntent
    ) async throws {
        guard !(session?.isProcessing ?? false) else {
            throw PaymentError.payment("Payment in progress")
        }
        if let onEvent {
            self.onEvent = onEvent
        }
        paymentConfig = liveConfiguration
        prepareGeneration += 1
        let generation = prepareGeneration
        isUpdatingOrder = true

        createOrderTask?.cancel()
        let task = Task { try await createOrder() }
        createOrderTask = task
        let intent: PaymentIntent
        do {
            intent = try await task.value
        } catch {
            if generation == prepareGeneration {
                createOrderTask = nil
            }
            guard generation == prepareGeneration else {
                throw CancellationError()
            }
            isUpdatingOrder = false
            throw error
        }

        guard generation == prepareGeneration else {
            throw CancellationError()
        }
        createOrderTask = nil
        if boundIntent == intent, session?.state != nil, session?.isOrderConsumed == false {
            isUpdatingOrder = false
            return
        }
        try await bindLocked(intent: intent, generation: generation)
    }

    private func bindLocked(intent: PaymentIntent, generation: Int) async throws {
        let initial = boundIntent == nil
        do {
            if session == nil {
                session = try PaymentSession(configuration: liveConfiguration, intent: intent)
            }
            guard let session else {
                if generation == prepareGeneration {
                    isUpdatingOrder = false
                }
                return
            }
            let state = try await session.bind(intent: intent)
            guard generation == prepareGeneration else {
                throw CancellationError()
            }
            boundIntent = intent
            isUpdatingOrder = false
            onOrderBound?(state)
        } catch is CancellationError {
            if generation == prepareGeneration {
                isUpdatingOrder = false
            }
            throw CancellationError()
        } catch let error as PaymentError {
            guard generation == prepareGeneration else {
                throw CancellationError()
            }
            isUpdatingOrder = false
            if initial {
                onResult(.failed(error.merchantFacing()))
            }
            throw error
        } catch {
            guard generation == prepareGeneration else {
                throw CancellationError()
            }
            isUpdatingOrder = false
            if initial {
                let mapped = PaymentError.load(error.localizedDescription)
                onResult(.failed(mapped.merchantFacing()))
            }
            throw error
        }
    }

    func startApplePay() {
        guard isInteractionEnabled, let session,
              let authorizer = session.makeWalletAuthorizer(presenter: self) else { return }
        emit(.processing(true))
        operationTask?.cancel()
        operationTask = Task { @MainActor in
            let result = await session.startWallet(authorizer)
            self.deliver(result)
        }
    }

    func payWithCard(_ input: CardInput) {
        guard isInteractionEnabled, let session else { return }

        let numberInvalid = CardFieldValidators.validateCardNumber(input.number) != nil
        let expiryInvalid = CardFieldValidators.validateExpiry(month: input.expiryMonth, year: input.expiryYear) != nil
        let cvvInvalid = CardFieldValidators.validateCVV(input.cvv) != nil
        let holderInvalid = CardFieldValidators.validateHolderName(input.holderName) != nil
        if numberInvalid || expiryInvalid || cvvInvalid || holderInvalid { return }

        emit(.processing(true))
        operationTask?.cancel()
        operationTask = Task { @MainActor in
            let result = await session.submitNewCard(input, presenter: self)
            self.deliver(result)
        }
    }

    func paySavedCard(_ card: SavedCard) {
        guard isInteractionEnabled, let session else { return }
        emit(.processing(true))
        operationTask?.cancel()
        operationTask = Task { @MainActor in
            let result = await session.submitSavedCard(cardId: card.id, presenter: self)
            self.deliver(result)
        }
    }

    @MainActor
    func deleteSavedCardAndReload(_ card: SavedCard) async throws {
        guard isInteractionEnabled, let session else { return }
        _ = try await session.deleteSavedCard(cardId: card.id)
    }

    private func deliver(_ result: EngineResult) {
        emit(.processing(false))
        onResult(OrderConsumption.merchantResult(result))
    }

    // MARK: - ThreeDSPresenter

    func presentThreeDS(url: URL) async -> ThreeDSChallengeEnd {
        let locale = paymentConfig?.options.locale ?? liveConfiguration.options.locale
        let session = ThreeDSSafariController(locale: locale)
        threeDSSession = session
        return await session.present(url: url, from: topViewController())
    }

    func dismissThreeDS() {
        Task { @MainActor in
            self.threeDSSession?.dismiss()
            self.threeDSSession = nil
        }
    }

    private func topViewController() -> UIViewController? {
        if let host = hostView?.window?.rootViewController {
            return Self.topMost(from: host)
        }
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let window = scenes
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        guard let root = window?.rootViewController else { return nil }
        return Self.topMost(from: root)
    }

    private static func topMost(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return topMost(from: presented)
        }
        if let nav = root as? UINavigationController, let visible = nav.visibleViewController {
            return topMost(from: visible)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topMost(from: selected)
        }
        return root
    }

    #if DEBUG
    func testingInstallBound(
        _ intent: PaymentIntent,
        state: SheetState,
        processing: Bool = false
    ) throws {
        if session == nil {
            session = try PaymentSession(configuration: liveConfiguration, intent: intent)
        }
        session?.testingInstall(state: state, processing: processing)
        boundIntent = intent
    }

    func testingFailNextBind(_ error: Error) {
        session?.testingBindError = error
    }
    #endif
}
