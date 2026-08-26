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
    private var threeDSController: UIViewController?
    private let threeDSResume = ThreeDSResume()
    private weak var hostView: UIView?
    private var prepareGeneration = 0
    private var operationTask: Task<Void, Never>?
    private var submitHandler: (() -> Void)?
    private(set) var isUpdatingOrder = false

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
        paymentConfig = liveConfiguration
    }

    func updateLocale(_ locale: String) {
        liveConfiguration.options.locale = locale
        paymentConfig = liveConfiguration
    }

    func prepare(intent: PaymentIntent, onEvent: @escaping (EmbeddedEvent) -> Void = { _ in }) async throws {
        self.onEvent = onEvent
        paymentConfig = liveConfiguration
        prepareGeneration += 1
        let generation = prepareGeneration
        operationTask?.cancel()
        isUpdatingOrder = true

        do {
            if session == nil {
                session = try PaymentSession(configuration: liveConfiguration, intent: intent)
            }
            guard let session else { return }
            let state = try await session.bind(intent: intent)
            guard generation == prepareGeneration else { return }
            _ = state
            isUpdatingOrder = false
            onEvent(.ready)
        } catch is CancellationError {
            guard generation == prepareGeneration else { return }
            isUpdatingOrder = false
            throw CancellationError()
        } catch let error as PaymentError {
            guard generation == prepareGeneration else { return }
            isUpdatingOrder = false
            onResult(.failed(error.merchantFacing()))
            throw error
        } catch {
            guard generation == prepareGeneration else { return }
            isUpdatingOrder = false
            let mapped = PaymentError.load(error.localizedDescription)
            onResult(.failed(mapped.merchantFacing()))
            throw error
        }
    }

    func startApplePay() {
        guard isInteractionEnabled, let session,
              let authorizer = session.makeWalletAuthorizer(presenter: self) else { return }
        onEvent(.processing(true))
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

        onEvent(.processing(true))
        operationTask?.cancel()
        operationTask = Task { @MainActor in
            let result = await session.submitNewCard(input, presenter: self)
            self.deliver(result)
        }
    }

    func paySavedCard(_ card: SavedCard) {
        guard isInteractionEnabled, let session else { return }
        onEvent(.processing(true))
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
        onEvent(.processing(false))
        onResult(OrderConsumption.merchantResult(result))
    }

    // MARK: - ThreeDSPresenter

    func presentThreeDS(url: URL, returnURLMatcher: @escaping (URL) -> Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                guard let presenter = self.topViewController() else {
                    continuation.resume(returning: false)
                    return
                }
                self.threeDSResume.arm(continuation)
                let locale = self.paymentConfig?.options.locale ?? "en-US"
                let threeDS = ThreeDSViewController(
                    url: url,
                    returnURLMatcher: returnURLMatcher,
                    completion: { [weak self] success in
                        self?.threeDSResume.resume(success)
                        self?.threeDSController = nil
                    },
                    locale: locale
                )
                self.threeDSController = threeDS
                presenter.present(threeDS, animated: true)
            }
        }
    }

    func dismissThreeDS() {
        Task { @MainActor in
            self.threeDSController?.dismiss(animated: true)
            self.threeDSController = nil
            self.threeDSResume.resume(true)
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
}
