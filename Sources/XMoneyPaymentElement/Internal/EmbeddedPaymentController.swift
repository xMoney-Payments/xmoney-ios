import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

/// Who asked for a rebind. Merchant calls always supersede in-flight work;
/// the SDK's own declarative host re-asserting the bound intent does not.
enum BindOrigin {
    case merchant
    /// The host mounted with its current intent. It may be older than an
    /// order the merchant bound directly, so it never clears the stale lock.
    case surfaceMount
    /// The host's intent changed. Switching back to the bound intent means
    /// the cart matches it again, so the stale lock clears.
    case surfaceUpdate
}

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
    private var createOrderTask: Task<PaymentIntent, Error>?
    private var operationTask: Task<Void, Never>?
    private var submitHandler: (() -> Void)?
    private var onLiveConfigChange: (() -> Void)?
    private var onOrderLockChange: ((Bool) -> Void)?
    private var onOrderBound: ((SheetState) -> Void)?
    private var initialFailureReported = false
    private(set) var isUpdatingOrder = false {
        didSet { publishOrderLock(oldValue: oldValue || isStaleOrder) }
    }
    /// A later bind failed: the bound order no longer matches the cart, so Pay
    /// stays locked until a bind succeeds.
    private(set) var isStaleOrder = false {
        didSet { publishOrderLock(oldValue: isUpdatingOrder || oldValue) }
    }
    /// State used when tests mount a form without binding an order.
    private var previewState: SheetState?

    var isOrderLocked: Bool { isUpdatingOrder || isStaleOrder }

    var sheetState: SheetState? { session?.state ?? previewState }
    var boundIntent: PaymentIntent? {
        guard let session, session.isBound else { return nil }
        return session.intent
    }
    /// In-flight charge only. Order rebind uses `isUpdatingOrder`, not this flag.
    var isProcessing: Bool { session?.isProcessing ?? false }
    var isOrderConsumed: Bool { session?.isOrderConsumed ?? false }
    var isInteractionEnabled: Bool {
        if let session {
            guard !isOrderLocked, session.isBound else { return false }
            return session.isInteractionEnabled
        }
        return !isOrderLocked && previewState != nil
    }

    /// Installs config and state so a form can render without a network bind.
    func preview(_ state: SheetState) {
        paymentConfig = liveConfiguration
        previewState = state
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

    func setOnOrderLockChange(_ handler: ((Bool) -> Void)?) {
        onOrderLockChange = handler
        handler?(isOrderLocked)
    }

    func setOnOrderBound(_ handler: ((SheetState) -> Void)?) {
        onOrderBound = handler
    }

    func emit(_ event: EmbeddedEvent) {
        onEvent(event)
    }

    private func publishOrderLock(oldValue: Bool) {
        guard isOrderLocked != oldValue else { return }
        onOrderLockChange?(isOrderLocked)
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

    private func isBoundAndPayable(_ intent: PaymentIntent) -> Bool {
        guard let session else { return false }
        return session.isBound(intent) && !session.isOrderConsumed
    }

    func prepare(
        intent: PaymentIntent,
        origin: BindOrigin = .merchant,
        onEvent: ((EmbeddedEvent) -> Void)? = nil
    ) async throws {
        if let onEvent {
            self.onEvent = onEvent
        }
        paymentConfig = liveConfiguration
        if session?.isProcessing == true {
            if session?.isBound(intent) == true { return }
            throw PaymentError.paymentInProgress
        }
        if origin != .merchant, isBoundAndPayable(intent) {
            if origin == .surfaceUpdate {
                isStaleOrder = false
            }
            return
        }
        prepareGeneration += 1
        let generation = prepareGeneration
        createOrderTask?.cancel()
        createOrderTask = nil
        if isBoundAndPayable(intent) {
            isStaleOrder = false
            isUpdatingOrder = false
            return
        }
        isUpdatingOrder = true
        try await bindLocked(intent: intent, generation: generation)
    }

    @discardableResult
    func updateOrder(
        onEvent: ((EmbeddedEvent) -> Void)? = nil,
        createOrder: @escaping @MainActor () async throws -> PaymentIntent
    ) async throws -> PaymentIntent {
        if let onEvent {
            self.onEvent = onEvent
        }
        guard !(session?.isProcessing ?? false) else {
            throw PaymentError.paymentInProgress
        }
        paymentConfig = liveConfiguration
        prepareGeneration += 1
        let generation = prepareGeneration
        isUpdatingOrder = true

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
            guard generation == prepareGeneration else {
                throw CancellationError()
            }
            createOrderTask = nil
            isUpdatingOrder = false
            throw error
        }

        guard generation == prepareGeneration else {
            throw CancellationError()
        }
        createOrderTask = nil
        if isBoundAndPayable(intent) {
            isStaleOrder = false
            isUpdatingOrder = false
            return intent
        }
        try await bindLocked(intent: intent, generation: generation)
        return intent
    }

    private func bindLocked(intent: PaymentIntent, generation: Int) async throws {
        let initial = !(session?.isBound ?? false)
        do {
            let session = try self.session ?? makeSession(intent: intent)
            self.session = session
            let candidate = try await session.load(intent: intent)
            guard generation == prepareGeneration else {
                throw CancellationError()
            }
            let state = session.commit(candidate)
            initialFailureReported = false
            isStaleOrder = false
            isUpdatingOrder = false
            onOrderBound?(state)
        } catch {
            let superseded = generation != prepareGeneration
            if superseded || error is CancellationError || Task.isCancelled {
                if !superseded {
                    isUpdatingOrder = false
                }
                throw CancellationError()
            }
            let mapped = (error as? PaymentError) ?? PaymentError.load(error.localizedDescription)
            if initial {
                isUpdatingOrder = false
                if !initialFailureReported {
                    initialFailureReported = true
                    onResult(.failed(mapped.merchantFacing()))
                }
            } else {
                isStaleOrder = true
                isUpdatingOrder = false
                emit(.updateFailed(mapped.merchantFacing()))
            }
            throw error
        }
    }

    private func makeSession(intent: PaymentIntent) throws -> PaymentSession {
        let session = try PaymentSession(configuration: liveConfiguration, intent: intent)
        #if DEBUG
        session.testingLoad = testingLoad
        #endif
        return session
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

    func payWithCard(_ input: CardInput, customerDetails: CustomerDetails?) {
        guard isInteractionEnabled, let session else { return }

        let numberInvalid = CardFieldValidators.validateCardNumber(input.number) != nil
        let expiryInvalid = CardFieldValidators.validateExpiry(month: input.expiryMonth, year: input.expiryYear) != nil
        let cvvInvalid = CardFieldValidators.validateCVV(input.cvv) != nil
        let holderInvalid = CardFieldValidators.validateHolderName(input.holderName) != nil
        if numberInvalid || expiryInvalid || cvvInvalid || holderInvalid { return }

        emit(.processing(true))
        operationTask?.cancel()
        operationTask = Task { @MainActor in
            let result = await session.submitNewCard(input, presenter: self, customerDetails: customerDetails)
            self.deliver(result)
        }
    }

    func paySavedCard(_ card: SavedCard, customerDetails: CustomerDetails?) {
        guard isInteractionEnabled, let session else { return }
        emit(.processing(true))
        operationTask?.cancel()
        operationTask = Task { @MainActor in
            let result = await session.submitSavedCard(cardId: card.id, presenter: self, customerDetails: customerDetails)
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
    /// Replaces the network load for every session this controller creates.
    var testingLoad: ((PaymentIntent) async throws -> SheetState)? {
        didSet { session?.testingLoad = testingLoad }
    }

    func testingInstallBound(
        _ intent: PaymentIntent,
        state: SheetState,
        processing: Bool = false
    ) throws {
        if session == nil {
            session = try makeSession(intent: intent)
        }
        try session?.testingInstall(intent: intent, state: state, processing: processing)
    }

    func testingFailNextBind(_ error: Error) {
        session?.testingBindError = error
    }
    #endif
}
