import UIKit
import SwiftUI
#if canImport(XMoneyCore)
import XMoneyCore
#endif

public final class PaymentElement: UIView {
    private let payment: EmbeddedPayment
    private let onEvent: (EmbeddedEvent) -> Void
    private let loaderHost = UIView()
    private var loader: XCoinFlipLoaderView?
    private var failureLabel: UILabel?
    private var formView: PaymentFormView?
    /// Bumps on each ``prepare(intent:)`` so overlapping async prepares discard stale results.
    private var prepareGeneration = 0
    private var readyEmitted = false

    /// Fired when the form’s measured height changes (saved-card expand, errors, locale).
    public var onContentSizeChange: (() -> Void)?

    public init(
        payment: EmbeddedPayment,
        onEvent: @escaping (EmbeddedEvent) -> Void = { _ in }
    ) {
        self.payment = payment
        self.onEvent = onEvent
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        payment._controller.attachHostView(self)
        payment._controller.setOnLiveConfigChange { [weak self] in
            self?.applyLiveConfig()
        }
        payment._controller.setOnUpdatingOrderChange { [weak self] updating in
            self?.formView?.setUpdatingOrder(updating)
        }
        payment._controller.setOnOrderBound { [weak self] state in
            self?.formView?.update(state: state)
        }
        setupLoader()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @MainActor
    public func prepare(intent: PaymentIntent) async throws {
        if formView != nil {
            try await updateOrder(intent: intent)
            return
        }
        prepareGeneration += 1
        let generation = prepareGeneration
        showLoader()
        do {
            try await payment.prepare(intent: intent) { [weak self] event in
                Task { @MainActor in
                    self?.forward(event, generation: generation)
                }
            }
        } catch let error as PaymentError {
            guard !Task.isCancelled, prepareGeneration == generation else { throw error }
            if case let .payment(message) = error, message == "Payment in progress" {
                throw error
            }
            showFailure(error)
            layoutIfNeeded()
            if let failureLabel {
                await SurfacePaint.waitUntilLaidOut(failureLabel)
            }
            guard !Task.isCancelled, prepareGeneration == generation else { throw error }
            revealIfNeeded()
            throw error
        } catch {
            guard !Task.isCancelled, prepareGeneration == generation else { throw error }
            showFailure(error)
            layoutIfNeeded()
            if let failureLabel {
                await SurfacePaint.waitUntilLaidOut(failureLabel)
            }
            guard !Task.isCancelled, prepareGeneration == generation else { throw error }
            revealIfNeeded()
            throw error
        }
        guard !Task.isCancelled, prepareGeneration == generation else { return }
        renderForm()
        guard formView != nil else { return }
        layoutIfNeeded()
        await formView?.waitUntilSurfaceDrawn()
        guard !Task.isCancelled, prepareGeneration == generation else { return }
        revealIfNeeded()
    }

    /// Rebinds a new signed order in place. The form stays mounted; Pay is
    /// locked with its current title until bind finishes. Does not show
    /// “Processing...”.
    @MainActor
    public func updateOrder(intent: PaymentIntent) async throws {
        if formView == nil {
            try await prepare(intent: intent)
            return
        }
        prepareGeneration += 1
        let generation = prepareGeneration
        formView?.setUpdatingOrder(true)
        do {
            try await payment.updateOrder(intent: intent) { [weak self] event in
                Task { @MainActor in
                    self?.forward(event, generation: generation)
                }
            }
            await refreshForm(generation: generation)
        } catch {
            guard prepareGeneration == generation else { throw error }
            formView?.setUpdatingOrder(false)
            await revealAfterUpdateFailure(generation: generation)
            throw error
        }
    }

    /// Locks Pay immediately, creates the next signed order, and binds it in
    /// place. If `createOrder` throws, the previous order remains payable.
    @MainActor
    public func updateOrder(
        createOrder: @escaping () async throws -> PaymentIntent
    ) async throws {
        if formView == nil {
            let intent = try await createOrder()
            try await prepare(intent: intent)
            return
        }
        prepareGeneration += 1
        let generation = prepareGeneration
        formView?.setUpdatingOrder(true)
        do {
            try await payment.updateOrder(
                onEvent: { [weak self] event in
                    Task { @MainActor in
                        self?.forward(event, generation: generation)
                    }
                },
                createOrder: createOrder
            )
            await refreshForm(generation: generation)
        } catch {
            guard prepareGeneration == generation else { throw error }
            formView?.setUpdatingOrder(false)
            await revealAfterUpdateFailure(generation: generation)
            throw error
        }
    }

    @MainActor
    public func updateAppearance(_ appearance: PaymentConfig.AppearanceConfig) {
        payment.updateAppearance(appearance)
    }

    @MainActor
    public func updateLocale(_ locale: String) {
        payment.updateLocale(locale)
    }

    @MainActor
    public func updateStyle(_ style: PaymentConfig.UserInterfaceStyle) {
        payment.updateStyle(style)
    }

    @MainActor
    public func updateWalletAppearance(_ appearance: PaymentConfig.WalletAppearance) {
        payment.updateWalletAppearance(appearance)
    }

    /// Submit the currently selected method (new card or saved card).
    /// Use with `SubmitButtonConfig.visible = false` so the merchant owns the Pay CTA.
    /// No-op while `isInteractionEnabled` is false.
    @MainActor
    public func confirm() {
        payment.confirm()
    }

    public var isOrderConsumed: Bool { payment.isOrderConsumed }

    /// Bind emits `.ready` only after the form has drawn. Processing still
    /// forwards immediately.
    private func forward(_ event: EmbeddedEvent, generation: Int) {
        guard prepareGeneration == generation else { return }
        switch event {
        case .ready:
            break
        case let .processing(isProcessing):
            onEvent(event)
            formView?.setProcessing(isProcessing)
            formView?.setOrderConsumed(payment.isOrderConsumed)
        }
    }

    private func refreshForm(generation: Int) async {
        guard !Task.isCancelled, prepareGeneration == generation else { return }
        formView?.setUpdatingOrder(false)
        formView?.setProcessing(payment.isProcessing)
        formView?.setOrderConsumed(payment.isOrderConsumed)
        layoutIfNeeded()
        await formView?.waitUntilSurfaceDrawn()
        guard !Task.isCancelled, prepareGeneration == generation else { return }
        revealIfNeeded()
        invalidateIntrinsicContentSize()
        onContentSizeChange?()
    }

    private func revealAfterUpdateFailure(generation: Int) async {
        guard prepareGeneration == generation, !loaderHost.isHidden, formView != nil else { return }
        await formView?.waitUntilSurfaceDrawn()
        guard !Task.isCancelled, prepareGeneration == generation else { return }
        revealIfNeeded()
    }

    private func setupLoader() {
        loaderHost.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loaderHost)
        NSLayoutConstraint.activate([
            loaderHost.topAnchor.constraint(equalTo: topAnchor),
            loaderHost.leadingAnchor.constraint(equalTo: leadingAnchor),
            loaderHost.trailingAnchor.constraint(equalTo: trailingAnchor),
            loaderHost.bottomAnchor.constraint(equalTo: bottomAnchor),
            loaderHost.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),
        ])
        showLoader()
    }

    private func showLoader() {
        payment._controller.bindSubmitHandler(nil)
        formView?.removeFromSuperview()
        formView = nil
        loaderHost.isHidden = false
        loader?.removeFromSuperview()
        failureLabel?.removeFromSuperview()
        failureLabel = nil
        let flip = XCoinFlipLoaderView()
        flip.translatesAutoresizingMaskIntoConstraints = false
        loaderHost.addSubview(flip)
        NSLayoutConstraint.activate([
            flip.centerXAnchor.constraint(equalTo: loaderHost.centerXAnchor),
            flip.centerYAnchor.constraint(equalTo: loaderHost.centerYAnchor),
        ])
        loader = flip
    }

    func showFailure(_ error: Error) {
        loader?.stopAnimating()
        loader?.removeFromSuperview()
        loader = nil
        failureLabel?.removeFromSuperview()

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .label
        label.accessibilityTraits = .staticText
        if let paymentError = error as? PaymentError {
            label.text = paymentError.merchantMessage()
        } else {
            label.text = PaymentError.genericLoad
        }
        loaderHost.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: loaderHost.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: loaderHost.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: loaderHost.centerYAnchor),
        ])
        failureLabel = label
    }

    private func renderForm() {
        let controller = payment._controller
        guard let config = controller.paymentConfig, let state = controller.sheetState else { return }

        formView?.removeFromSuperview()
        let form = PaymentFormView(config: config, state: state)
        form.translatesAutoresizingMaskIntoConstraints = false
        form.onPayCard = { [weak self] input in
            self?.payment._controller.payWithCard(input)
        }
        form.onSelectSaved = { [weak self] card in
            self?.payment._controller.paySavedCard(card)
        }
        form.onDeleteSaved = { [weak self] card in
            try await self?.payment._controller.deleteSavedCardAndReload(card)
            if let state = self?.payment._controller.sheetState {
                self?.formView?.update(state: state)
            }
        }
        form.onApplePay = { [weak self] in
            self?.payment._controller.startApplePay()
        }
        form.onContentSizeChange = { [weak self] in
            self?.invalidateIntrinsicContentSize()
            self?.onContentSizeChange?()
        }
        controller.bindSubmitHandler { [weak form] in
            form?.confirm()
        }
        form.setProcessing(controller.isProcessing)
        form.setUpdatingOrder(controller.isUpdatingOrder)
        form.setOrderConsumed(controller.isOrderConsumed)
        form.accessibilityElementsHidden = true
        overrideUserInterfaceStyle = UIHelpers.overrideStyle(for: config)
        addSubview(form)
        NSLayoutConstraint.activate([
            form.topAnchor.constraint(equalTo: topAnchor),
            form.leadingAnchor.constraint(equalTo: leadingAnchor),
            form.trailingAnchor.constraint(equalTo: trailingAnchor),
            form.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        formView = form
        bringSubviewToFront(loaderHost)
        let theme = CheckoutTheme.resolve(
            config: config,
            isDark: UIHelpers.isDarkMode(config: config, traitCollection: traitCollection)
        )
        loaderHost.backgroundColor = theme.background
        loaderHost.isHidden = false
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        onContentSizeChange?()
    }

    private func revealForm() {
        formView?.accessibilityElementsHidden = false
        loader?.stopAnimating()
        loader?.removeFromSuperview()
        loader = nil
        if failureLabel == nil {
            loaderHost.backgroundColor = .clear
            loaderHost.isHidden = true
        }
    }

    func revealIfNeeded() {
        guard !loaderHost.isHidden else { return }
        revealForm()
        if !readyEmitted {
            readyEmitted = true
            onEvent(.ready)
        }
    }

    var isLoaderVisible: Bool { loader != nil && !loaderHost.isHidden }
    var isFailureVisible: Bool { failureLabel != nil && !loaderHost.isHidden }
    var failureMessage: String? { failureLabel?.text }

    #if DEBUG
    func _installFormForTesting(
        config: PaymentConfig,
        state: SheetState
    ) {
        let form = PaymentFormView(config: config, state: state)
        form.translatesAutoresizingMaskIntoConstraints = false
        addSubview(form)
        NSLayoutConstraint.activate([
            form.topAnchor.constraint(equalTo: topAnchor),
            form.leadingAnchor.constraint(equalTo: leadingAnchor),
            form.trailingAnchor.constraint(equalTo: trailingAnchor),
            form.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        formView = form
        bringSubviewToFront(loaderHost)
    }
    #endif

    private func applyLiveConfig() {
        guard let config = payment._controller.paymentConfig else { return }
        overrideUserInterfaceStyle = UIHelpers.overrideStyle(for: config)
        formView?.applyConfig(config)
        invalidateIntrinsicContentSize()
        onContentSizeChange?()
    }

    public override var intrinsicContentSize: CGSize {
        if let formView {
            return CGSize(width: UIView.noIntrinsicMetric, height: max(formView.contentHeight, 160))
        }
        return CGSize(width: UIView.noIntrinsicMetric, height: 160)
    }
}

public struct PaymentElementView: UIViewRepresentable {
    public let payment: EmbeddedPayment
    public let intent: PaymentIntent
    public var onEvent: (EmbeddedEvent) -> Void

    public init(
        payment: EmbeddedPayment,
        intent: PaymentIntent,
        onEvent: @escaping (EmbeddedEvent) -> Void = { _ in }
    ) {
        self.payment = payment
        self.intent = intent
        self.onEvent = onEvent
    }

    public func makeUIView(context: Context) -> PaymentElement {
        let coordinator = context.coordinator
        coordinator.onEvent = onEvent
        let element = PaymentElement(payment: payment) { [weak coordinator] event in
            coordinator?.onEvent(event)
            if case .processing(false) = event {
                coordinator?.retryPendingOrder()
            }
        }
        context.coordinator.element = element
        let key = orderKey
        context.coordinator.lastOrderKey = key
        context.coordinator.prepareTask?.cancel()
        context.coordinator.prepareTask = Task { @MainActor [weak coordinator] in
            guard !Task.isCancelled else { return }
            do {
                try await element.prepare(intent: intent)
            } catch {
                if coordinator?.lastOrderKey == key {
                    coordinator?.lastOrderKey = nil
                }
            }
        }
        return element
    }

    public func updateUIView(_ uiView: PaymentElement, context: Context) {
        context.coordinator.onEvent = onEvent
        let key = orderKey
        guard context.coordinator.lastOrderKey != key else { return }
        context.coordinator.bind(intent: intent, key: key, to: uiView)
    }

    @available(iOS 16.0, *)
    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: PaymentElement,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let height = uiView.intrinsicContentSize.height
        return CGSize(width: width, height: height > 0 ? height : 160)
    }

    public static func dismantleUIView(_ uiView: PaymentElement, coordinator: Coordinator) {
        coordinator.prepareTask?.cancel()
        coordinator.prepareTask = nil
        coordinator.element = nil
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private var orderKey: String {
        "\(intent.orderPayload):\(intent.orderChecksum)"
    }

    public final class Coordinator {
        var element: PaymentElement?
        var lastOrderKey: String?
        var prepareTask: Task<Void, Never>?
        var pendingIntent: PaymentIntent?
        var onEvent: (EmbeddedEvent) -> Void = { _ in }

        func bind(intent: PaymentIntent, key: String, to element: PaymentElement) {
            lastOrderKey = key
            pendingIntent = nil
            prepareTask?.cancel()
            prepareTask = Task { @MainActor [weak self, weak element] in
                guard !Task.isCancelled, let element else { return }
                do {
                    try await element.updateOrder(intent: intent)
                } catch let error as PaymentError {
                    guard let self, self.lastOrderKey == key else { return }
                    if case let .payment(message) = error, message == "Payment in progress" {
                        self.pendingIntent = intent
                    }
                    self.lastOrderKey = nil
                } catch {
                    if self?.lastOrderKey == key {
                        self?.lastOrderKey = nil
                    }
                }
            }
        }

        func retryPendingOrder() {
            guard let element, let intent = pendingIntent else { return }
            let key = "\(intent.orderPayload):\(intent.orderChecksum)"
            bind(intent: intent, key: key, to: element)
        }
    }
}
