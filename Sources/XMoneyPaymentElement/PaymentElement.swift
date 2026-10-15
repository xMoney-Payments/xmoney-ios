import UIKit
import SwiftUI
#if DEBUG
import OSLog
#endif
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
    private var formConstraints: [NSLayoutConstraint] = []
    private var personalDetails: PersonalDetailsViewController?
    private var personalDetailsConstraints: [NSLayoutConstraint] = []
    private var readyEmitted = false
    private var revealTask: Task<Void, Never>?
    /// The form is rendered under the cover but the Element is not in a window,
    /// so the draw wait resumes from `didMoveToWindow`.
    private var pendingReveal = false

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
        payment._controller.setOnOrderLockChange { [weak self] locked in
            self?.formView?.setUpdatingOrder(locked)
        }
        payment._controller.setOnOrderBound { [weak self] state in
            self?.orderBound(state)
        }
        setupLoader()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var controller: EmbeddedPaymentController { payment._controller }

    /// Binds `intent` and renders the form. Returns once the surface has drawn
    /// (or the draw cap passed). A superseded call throws `CancellationError`
    /// and leaves the loader for the newer bind.
    @MainActor
    public func prepare(intent: PaymentIntent) async throws {
        try await bind(intent: intent, origin: .merchant)
    }

    /// Rebinds a new signed order in place. The form stays mounted; Pay is
    /// locked with its current title until bind finishes. Does not show
    /// “Processing...”. The newest call wins, even for the bound intent.
    @MainActor
    public func updateOrder(intent: PaymentIntent) async throws {
        try await bind(intent: intent, origin: .merchant)
    }

    /// Locks Pay immediately, creates the next signed order, binds it in
    /// place, and returns it. If `createOrder` throws, the previous order
    /// remains payable.
    @MainActor
    @discardableResult
    public func updateOrder(
        createOrder: @escaping @MainActor () async throws -> PaymentIntent
    ) async throws -> PaymentIntent {
        let hadForm = formView != nil
        if !hadForm, failureLabel == nil {
            showLoader()
        }
        do {
            let intent = try await payment.updateOrder(onEvent: forwarder(), createOrder: createOrder)
            if formView == nil {
                renderForm()
            }
            await refreshForm()
            return intent
        } catch {
            syncFormState()
            if formView == nil {
                showFailureIfNeeded(error)
            } else {
                await revealIfCovered()
            }
            throw error
        }
    }

    /// Binds on behalf of `origin`. The SwiftUI host uses a surface origin so that
    /// re-asserting the bound intent never cancels a merchant update.
    @MainActor
    func bind(intent: PaymentIntent, origin: BindOrigin) async throws {
        if formView == nil {
            try await initialBind(intent: intent, origin: origin)
        } else {
            try await rebind(intent: intent, origin: origin)
        }
    }

    private func initialBind(intent: PaymentIntent, origin: BindOrigin) async throws {
        if failureLabel == nil {
            showLoader()
        }
        do {
            try await controller.prepare(intent: intent, origin: origin, onEvent: forwarder())
        } catch {
            if formView == nil {
                showFailureIfNeeded(error)
            }
            throw error
        }
        if formView == nil {
            renderForm()
        }
        await revealIfCovered()
    }

    private func rebind(intent: PaymentIntent, origin: BindOrigin) async throws {
        do {
            try await controller.prepare(intent: intent, origin: origin, onEvent: forwarder())
            await refreshForm()
        } catch {
            syncFormState()
            await revealIfCovered()
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
    /// No-op while `isInteractionEnabled` is false. An open personal-details page is
    /// validated first: errors stay on that page, and a valid page is saved and paid.
    /// The in-page Continue button only saves and returns.
    @MainActor
    public func confirm() {
        payment.confirm()
    }

    public var isOrderConsumed: Bool { payment.isOrderConsumed }

    private func forwarder() -> (EmbeddedEvent) -> Void {
        { [weak self] event in
            Task { @MainActor in
                self?.forward(event)
            }
        }
    }

    /// Charge and update events always reach the merchant: they describe the
    /// charge or the bind, not a particular `updateOrder` call. `.ready` is
    /// emitted by the Element itself after the first draw.
    private func forward(_ event: EmbeddedEvent) {
        switch event {
        case .ready:
            break
        case let .processing(isProcessing):
            onEvent(event)
            formView?.setProcessing(isProcessing)
            formView?.setOrderConsumed(payment.isOrderConsumed)
        case .updateFailed:
            onEvent(event)
        }
    }

    private func orderBound(_ state: SheetState) {
        if let formView {
            formView.update(state: state)
        } else if !loaderHost.isHidden {
            renderForm()
            Task { @MainActor [weak self] in
                await self?.revealIfCovered()
            }
        }
    }

    private func syncFormState() {
        formView?.setUpdatingOrder(controller.isOrderLocked)
        formView?.setProcessing(controller.isProcessing)
        formView?.setOrderConsumed(controller.isOrderConsumed)
    }

    private func refreshForm() async {
        syncFormState()
        if !loaderHost.isHidden {
            await revealIfCovered()
        }
        invalidateIntrinsicContentSize()
        onContentSizeChange?()
    }

    /// Lifts the cover once the current form has drawn. Owned by the view, not
    /// the caller: cancelling the caller's task does not leave the cover up.
    private func revealIfCovered() async {
        guard formView != nil, !loaderHost.isHidden else { return }
        if revealTask == nil {
            guard window != nil else {
                pendingReveal = true
                return
            }
            startRevealTask()
        }
        await revealTask?.value
    }

    private func startRevealTask() {
        guard let form = formView else { return }
        pendingReveal = false
        layoutIfNeeded()
        revealTask = Task { @MainActor [weak self] in
            guard let outcome = await self?.waitForSurface(form) else { return }
            guard let self, self.formView === form, !Task.isCancelled else { return }
            self.revealTask = nil
            if outcome {
                self.revealIfNeeded()
            } else {
                self.pendingReveal = true
            }
        }
    }

    private static let revealTimeout: TimeInterval = 2

    /// `true` once `form` has drawn or the cap passed; `false` when the Element
    /// left its window; `nil` when the form was replaced or the task cancelled.
    /// A rebuild that replaces the wallet button restarts the wait on the new
    /// button, under the same deadline.
    private func waitForSurface(_ form: PaymentFormView) async -> Bool? {
        let deadline = ProcessInfo.processInfo.systemUptime + Self.revealTimeout
        while true {
            let remaining = max(deadline - ProcessInfo.processInfo.systemUptime, 0)
            #if DEBUG
            if let hook = testingOnRevealWaitStarted {
                testingOnRevealWaitStarted = nil
                Task { @MainActor in hook() }
            }
            #endif
            let drawn = await form.waitUntilSurfaceDrawn(timeout: remaining)
            guard formView === form, !Task.isCancelled else { return nil }
            if drawn { return true }
            guard window != nil, form.window != nil else { return false }
            if ProcessInfo.processInfo.systemUptime >= deadline { return true }
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            if revealTask != nil {
                revealTask?.cancel()
                revealTask = nil
                pendingReveal = formView != nil && !loaderHost.isHidden
            }
        } else if pendingReveal {
            startRevealTask()
        }
        guard let personalDetails, personalDetails.parent == nil, let parent = nearestViewController() else { return }
        parent.addChild(personalDetails)
        personalDetails.didMove(toParent: parent)
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

    private var locale: String {
        controller.paymentConfig?.options.locale ?? "en"
    }

    private func showLoader() {
        controller.bindSubmitHandler(nil)
        revealTask?.cancel()
        revealTask = nil
        pendingReveal = false
        preserveOpenDetails()
        detachPersonalDetails(refreshRow: false)
        formView?.removeFromSuperview()
        formView = nil
        formConstraints = []
        loaderHost.isHidden = false
        failureLabel?.removeFromSuperview()
        failureLabel = nil
        installLoaderIfNeeded()
    }

    private func installLoaderIfNeeded() {
        guard loader == nil else { return }
        let flip = XCoinFlipLoaderView()
        flip.translatesAutoresizingMaskIntoConstraints = false
        flip.accessibilityLabel = Strings.text("element.loading", locale: locale)
        flip.accessibilityTraits = .updatesFrequently
        loaderHost.addSubview(flip)
        NSLayoutConstraint.activate([
            flip.centerXAnchor.constraint(equalTo: loaderHost.centerXAnchor),
            flip.centerYAnchor.constraint(equalTo: loaderHost.centerYAnchor),
        ])
        loader = flip
        if UIAccessibility.isVoiceOverRunning, window != nil {
            UIAccessibility.post(notification: .announcement, argument: flip.accessibilityLabel)
        }
    }

    /// The initial bind failed. A superseded bind and a charge in flight are
    /// not failures: the loader stays for the newer bind or the retry.
    private func showFailureIfNeeded(_ error: Error) {
        if error is CancellationError { return }
        if let paymentError = error as? PaymentError, paymentError == .paymentInProgress { return }
        showFailure(error)
    }

    func showFailure(_ error: Error) {
        loader?.stopAnimating()
        loader?.removeFromSuperview()
        loader = nil
        failureLabel?.removeFromSuperview()

        let config = controller.paymentConfig
        if let config {
            overrideUserInterfaceStyle = UIHelpers.overrideStyle(for: config)
        }
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityTraits = .staticText
        label.text = Strings.text("element.loadFailed", locale: locale)
        if let config {
            let theme = CheckoutTheme.resolve(
                config: config,
                isDark: UIHelpers.isDarkMode(config: config, traitCollection: traitCollection)
            )
            label.textColor = theme.text
            loaderHost.backgroundColor = theme.background
        } else {
            label.textColor = .label
        }
        loaderHost.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: loaderHost.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: loaderHost.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: loaderHost.centerYAnchor),
        ])
        loaderHost.isHidden = false
        failureLabel = label
        if UIAccessibility.isVoiceOverRunning, window != nil {
            UIAccessibility.post(notification: .announcement, argument: label.text)
        }
    }

    /// Mounts the form from the controller's current config and state. Tests use this with a preview state.
    package func mountPreview() {
        renderForm()
        revealIfNeeded()
    }

    private func renderForm() {
        let reopenDetails = personalDetails != nil
        preserveOpenDetails()
        detachPersonalDetails(refreshRow: false)
        guard let config = controller.paymentConfig, let state = controller.sheetState else { return }

        revealTask?.cancel()
        revealTask = nil
        formView?.removeFromSuperview()
        failureLabel?.removeFromSuperview()
        failureLabel = nil
        installLoaderIfNeeded()
        #if DEBUG
        let visibility = state.customerDetailsVisibility
        Logger(subsystem: "com.xmoney.paymentsheet", category: "customer-details").debug(
            "renderForm card=\(config.customerDetails.card, privacy: .public) applePay=\(config.customerDetails.applePay, privacy: .public) name=\(visibility.showFullName, privacy: .public) email=\(visibility.showEmail, privacy: .public) phone=\(visibility.showPhone, privacy: .public) address=\(visibility.showAddressSection, privacy: .public)"
        )
        #endif
        let form = PaymentFormView(config: config, state: state)
        form.translatesAutoresizingMaskIntoConstraints = false
        form.onPayCard = { [weak self] input, details in
            self?.payment._controller.payWithCard(input, customerDetails: details)
        }
        form.onSelectSaved = { [weak self] card, details in
            self?.payment._controller.paySavedCard(card, customerDetails: details)
        }
        form.onOpenPersonalDetails = { [weak self] in
            self?.showPersonalDetails()
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
        controller.bindSubmitHandler { [weak self, weak form] in
            guard let self else { return }
            if let personalDetails = self.personalDetails, !personalDetails.commitIfValid() {
                return
            }
            form?.confirm()
        }
        form.setProcessing(controller.isProcessing)
        form.setUpdatingOrder(controller.isOrderLocked)
        form.setOrderConsumed(controller.isOrderConsumed)
        form.accessibilityElementsHidden = true
        overrideUserInterfaceStyle = UIHelpers.overrideStyle(for: config)
        addSubview(form)
        let constraints = [
            form.topAnchor.constraint(equalTo: topAnchor),
            form.leadingAnchor.constraint(equalTo: leadingAnchor),
            form.trailingAnchor.constraint(equalTo: trailingAnchor),
            form.bottomAnchor.constraint(equalTo: bottomAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
        formConstraints = constraints
        formView = form
        bringSubviewToFront(loaderHost)
        let theme = CheckoutTheme.resolve(
            config: config,
            isDark: UIHelpers.isDarkMode(config: config, traitCollection: traitCollection)
        )
        loaderHost.backgroundColor = theme.background
        loaderHost.isHidden = false
        if reopenDetails {
            presentInlineDetails()
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        onContentSizeChange?()
    }

    private func revealForm() {
        formView?.accessibilityElementsHidden = false
        loader?.stopAnimating()
        loader?.removeFromSuperview()
        loader = nil
        loaderHost.backgroundColor = .clear
        loaderHost.isHidden = true
        UIAccessibility.post(notification: .layoutChanged, argument: personalDetails?.view ?? formView)
    }

    /// Reveals the drawn form and emits `.ready` once per mounted Element.
    /// The failure state never reveals and never emits `.ready`.
    func revealIfNeeded() {
        guard formView != nil, failureLabel == nil, !loaderHost.isHidden else { return }
        revealForm()
        if !readyEmitted {
            readyEmitted = true
            onEvent(.ready)
        }
    }

    var isLoaderVisible: Bool { loader != nil && !loaderHost.isHidden }
    var isFailureVisible: Bool { failureLabel != nil && !loaderHost.isHidden }
    var isFormVisible: Bool { formView != nil && loaderHost.isHidden }
    var isPayLockedForTesting: Bool { formView?.isLockedForTesting ?? true }
    var walletButtonForTesting: UIView? { formView?.walletButtonForTesting }
    var failureMessage: String? { failureLabel?.text }

    #if DEBUG
    /// Runs once, at the first suspension of the next reveal wait.
    var testingOnRevealWaitStarted: (() -> Void)?

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
        if personalDetails != nil {
            preserveOpenDetails()
            detachPersonalDetails(refreshRow: false)
            presentInlineDetails()
        }
        invalidateIntrinsicContentSize()
        onContentSizeChange?()
    }

    public override var intrinsicContentSize: CGSize {
        if let personalDetails {
            return CGSize(width: UIView.noIntrinsicMetric, height: max(personalDetails.contentHeight, 160))
        }
        if let formView {
            return CGSize(width: UIView.noIntrinsicMetric, height: max(formView.contentHeight, 160))
        }
        return CGSize(width: UIView.noIntrinsicMetric, height: 160)
    }

    private func showPersonalDetails() {
        guard personalDetails == nil, payment.isInteractionEnabled else { return }
        presentInlineDetails()
    }

    private func presentInlineDetails() {
        guard personalDetails == nil else { return }
        guard let config = payment._controller.paymentConfig,
              let state = payment._controller.sheetState else { return }
        let details = PersonalDetailsFlow.make(
            config: config,
            visibility: state.customerDetailsVisibility,
            progress: state.personalDetails,
            presentation: .inline,
            onFinished: { [weak self] in
                self?.detachPersonalDetails(refreshRow: true)
            }
        )
        details.onContentSizeChange = { [weak self] in
            self?.invalidateIntrinsicContentSize()
            self?.onContentSizeChange?()
        }
        attach(details)
    }

    private func attach(_ details: PersonalDetailsViewController) {
        if let parent = nearestViewController() {
            parent.addChild(details)
        }
        details.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.deactivate(formConstraints)
        formView?.removeFromSuperview()
        addSubview(details.view)
        let constraints = [
            details.view.topAnchor.constraint(equalTo: topAnchor),
            details.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            details.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            details.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
        personalDetailsConstraints = constraints
        if details.parent != nil {
            details.didMove(toParent: details.parent)
        }
        personalDetails = details
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        details.prepareForPresentation(width: width, safeAreaBottom: 0)
        invalidateIntrinsicContentSize()
        onContentSizeChange?()
    }

    private func detachPersonalDetails(refreshRow: Bool) {
        guard let details = personalDetails else { return }
        endEditing(true)
        details.willMove(toParent: nil)
        NSLayoutConstraint.deactivate(personalDetailsConstraints)
        personalDetailsConstraints.removeAll()
        details.view.removeFromSuperview()
        details.removeFromParent()
        personalDetails = nil
        if let formView {
            addSubview(formView)
            NSLayoutConstraint.activate(formConstraints)
        }
        if refreshRow {
            formView?.refreshPersonalDetailsRow()
        }
        invalidateIntrinsicContentSize()
        onContentSizeChange?()
    }

    /// Applies the Back rules before a rebuild. A valid edit stays committed; an invalid one does not.
    private func preserveOpenDetails() {
        guard let personalDetails, let state = payment._controller.sheetState else { return }
        state.personalDetails.leave(
            with: personalDetails.currentValues(),
            visibility: state.customerDetailsVisibility
        )
    }

    private func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
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
        coordinator.element = element
        coordinator.payment = payment
        coordinator.bind(intent: intent, key: orderKey, origin: .surfaceMount, to: element)
        return element
    }

    public func updateUIView(_ uiView: PaymentElement, context: Context) {
        context.coordinator.onEvent = onEvent
        if let bound = context.coordinator.payment, bound !== payment {
            assertionFailure("PaymentElementView kept its element after EmbeddedPayment was replaced.")
        }
        let key = orderKey
        guard context.coordinator.lastOrderKey != key else { return }
        context.coordinator.bind(intent: intent, key: key, origin: .surfaceUpdate, to: uiView)
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
        Self.key(for: intent)
    }

    static func key(for intent: PaymentIntent) -> String {
        "\(intent.orderPayload):\(intent.orderChecksum)"
    }

    public final class Coordinator {
        var element: PaymentElement?
        var payment: EmbeddedPayment?
        /// The last intent handed to the Element. Kept after a failed bind so a
        /// re-render does not retry; only a new intent (or a pending retry) rebinds.
        var lastOrderKey: String?
        var prepareTask: Task<Void, Never>?
        var pendingIntent: PaymentIntent?
        var onEvent: (EmbeddedEvent) -> Void = { _ in }

        @MainActor
        func bind(intent: PaymentIntent, key: String, origin: BindOrigin, to element: PaymentElement) {
            lastOrderKey = key
            pendingIntent = nil
            prepareTask?.cancel()
            prepareTask = Task { @MainActor [weak self, weak element] in
                guard !Task.isCancelled, let element else { return }
                do {
                    try await element.bind(intent: intent, origin: origin)
                } catch {
                    self?.handle(error, intent: intent, key: key)
                }
            }
        }

        @MainActor
        func handle(_ error: Error, intent: PaymentIntent, key: String) {
            guard lastOrderKey == key else { return }
            if let paymentError = error as? PaymentError, paymentError == .paymentInProgress {
                pendingIntent = intent
            }
        }

        @MainActor
        func retryPendingOrder() {
            guard let element, let intent = pendingIntent else { return }
            bind(intent: intent, key: PaymentElementView.key(for: intent), origin: .surfaceUpdate, to: element)
        }
    }
}
