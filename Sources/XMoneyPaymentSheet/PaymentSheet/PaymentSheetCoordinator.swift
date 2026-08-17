import UIKit
import XMoneyCore
import XMoneyPaymentElement
import XMoneyApplePay

@MainActor
package final class PaymentSheetCoordinator: NSObject, PaymentSheetViewControllerDelegate, ThreeDSPresenter {
    private let session: PaymentSession
    private let config: PaymentConfig
    private let onEvent: (PaymentSheetEvent) -> Void
    private let completion: (EngineResult) -> Void

    private weak var presenter: UIViewController?
    private weak var sheetVC: PaymentSheetViewController?
    private weak var presentedNav: UINavigationController?
    private weak var threeDSController: UIViewController?
    private var didComplete = false
    private var isClosing = false
    private var sheetTransitioningDelegate: PaymentSheetTransitioningDelegate?
    private var loadTask: Task<Void, Never>?
    private var paymentTask: Task<Void, Never>?
    private let threeDSResume = ThreeDSResume()

    package var isProcessing: Bool { session.isProcessing }

    package init(
        configuration: PaymentConfig,
        intent: PaymentIntent,
        onEvent: @escaping (PaymentSheetEvent) -> Void,
        completion: @escaping (EngineResult) -> Void
    ) throws {
        ApplePay.register()
        self.config = configuration
        self.session = try PaymentSession(configuration: configuration, intent: intent)
        self.onEvent = onEvent
        self.completion = completion
    }

    package func present(from presenter: UIViewController) {
        self.presenter = presenter

        let loading = PaymentSheetLoadingViewController(config: config)

        let nav = UINavigationController(rootViewController: loading)
        nav.setNavigationBarHidden(true, animated: false)
        nav.overrideUserInterfaceStyle = UIHelpers.overrideStyle(for: config)

        let theme = CheckoutTheme.resolve(
            config: config,
            isDark: UIHelpers.isDarkMode(config: config, traitCollection: presenter.traitCollection)
        )
        let transitioning = PaymentSheetTransitioningDelegate()
        transitioning.heightProvider = loading
        transitioning.cornerRadius = theme.sheetCornerRadius
        transitioning.canDismiss = { [weak self] in
            guard let self else { return false }
            return !self.session.isProcessing
        }
        transitioning.onRequestClose = { [weak self] in
            self?.requestClose()
        }
        self.sheetTransitioningDelegate = transitioning

        loading.onContentSizeChange = { [weak transitioning] in
            transitioning?.presentationController?.updateLayout(animated: true)
        }

        nav.modalPresentationStyle = .custom
        nav.transitioningDelegate = transitioning
        self.presentedNav = nav
        presenter.present(nav, animated: true)
        nav.presentationController?.delegate = self

        loadTask?.cancel()
        loadTask = Task { @MainActor in
            do {
                let state = try await session.bind(intent: session.intent)
                guard self.presentedNav === nav, nav.presentingViewController != nil else { return }
                let sheet = PaymentSheetViewController(config: config, state: state)
                sheet.delegate = self
                self.sheetVC = sheet
                sheet.onContentSizeChange = { [weak transitioning] in
                    transitioning?.presentationController?.updateLayout(animated: true)
                }
                transitioning.heightProvider = sheet
                nav.setViewControllers([sheet], animated: false)
                nav.view.layoutIfNeeded()
                sheet.view.layoutIfNeeded()
                transitioning.presentationController?.updateLayout(animated: true)
                self.onEvent(.ready)
            } catch is CancellationError {
                return
            } catch let error as PaymentError {
                nav.dismiss(animated: true) {
                    self.finish(.failed(error))
                }
            } catch {
                nav.dismiss(animated: true) {
                    self.finish(.failed(.load(error.localizedDescription)))
                }
            }
        }
    }

    package func dismiss() {
        requestClose()
    }

    package func requestClose() {
        if session.isProcessing || didComplete || isClosing {
            return
        }
        isClosing = true
        loadTask?.cancel()
        dismissSheet(
            animated: true,
            result: .init(status: .canceled, transaction: nil, errorCode: nil, errorMessage: nil)
        )
    }

    private func dismissSheet(animated: Bool, result: EngineResult?, completion: (() -> Void)? = nil) {
        let finishAfter: () -> Void = { [weak self] in
            self?.presentedNav = nil
            self?.sheetVC = nil
            self?.sheetTransitioningDelegate = nil
            if let result {
                self?.finish(result)
            }
            completion?()
        }
        let host = presentedNav ?? sheetVC?.navigationController ?? sheetVC
        guard let host, host.presentingViewController != nil else {
            finishAfter()
            return
        }
        host.dismiss(animated: animated, completion: finishAfter)
    }

    private func finish(_ result: EngineResult) {
        guard !didComplete else { return }
        didComplete = true
        Task { @MainActor in
            self.completion(result)
        }
    }

    private func run(_ operation: @escaping () async -> EngineResult) {
        guard !didComplete, session.isInteractionEnabled else { return }
        onEvent(.processing(true))
        sheetVC?.setProcessing(true)
        presentedNav?.isModalInPresentation = true
        paymentTask?.cancel()
        paymentTask = Task { @MainActor in
            let result = await operation()
            if result.status == .canceled && !session.isOrderConsumed {
                self.onEvent(.processing(false))
                self.sheetVC?.setProcessing(false)
                self.presentedNav?.isModalInPresentation = false
                return
            }
            self.dismissSheet(animated: true, result: result)
        }
    }

    // MARK: - PaymentSheetViewControllerDelegate

    package func sheetDidTapPayWithCard(_ input: CardInput) {
        run { await self.session.submitNewCard(input, presenter: self) }
    }

    package func sheetDidSelectSavedCard(_ card: SavedCard) {
        run { await self.session.submitSavedCard(cardId: card.id, presenter: self) }
    }

    package func sheetDidTapApplePay() {
        guard let authorizer = session.makeWalletAuthorizer(presenter: self) else { return }
        run { await self.session.startWallet(authorizer) }
    }

    package func sheetDidTapDeleteSavedCard(_ card: SavedCard) async throws {
        guard session.isInteractionEnabled else { return }
        let state = try await session.deleteSavedCard(cardId: card.id)
        self.sheetVC?.update(state: state)
    }

    package func sheetDidCancel() {
        requestClose()
    }

    // MARK: - ThreeDSPresenter

    package func presentThreeDS(url: URL, returnURLMatcher: @escaping (URL) -> Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                guard let top = self.sheetVC else {
                    continuation.resume(returning: false)
                    return
                }
                self.threeDSResume.arm(continuation)
                let threeDS = ThreeDSViewController(
                    url: url,
                    returnURLMatcher: returnURLMatcher,
                    completion: { [weak self] success in
                        self?.threeDSResume.resume(success)
                        self?.threeDSController = nil
                    },
                    locale: self.config.options.locale
                )
                threeDS.modalPresentationStyle = .fullScreen
                self.threeDSController = threeDS
                top.present(threeDS, animated: true)
            }
        }
    }

    package func dismissThreeDS() {
        Task { @MainActor in
            self.threeDSController?.dismiss(animated: true)
            self.threeDSController = nil
            self.threeDSResume.resume(true)
        }
    }
}

extension PaymentSheetCoordinator: UIAdaptivePresentationControllerDelegate {
    package func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        requestClose()
    }

    package func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        !session.isProcessing
    }
}
