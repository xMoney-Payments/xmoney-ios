import UIKit
import PassKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

package final class PaymentFormView: UIView {
    package struct ContentInsets: Equatable {
        package var horizontal: CGFloat
        package var top: CGFloat
        package var bottom: CGFloat

        package init(horizontal: CGFloat, top: CGFloat, bottom: CGFloat) {
            self.horizontal = horizontal
            self.top = top
            self.bottom = bottom
        }

        package static let embedded = ContentInsets(horizontal: 0, top: 0, bottom: 0)
        package static let sheet = ContentInsets(horizontal: 22, top: 16, bottom: 12)
    }

    package enum MethodSelection: Equatable {
        case saved(String)
        case newCard
    }

    package var onPayCard: ((CardInput, CustomerDetails?) -> Void)?
    package var onSelectSaved: ((SavedCard, CustomerDetails?) -> Void)?
    package var onDeleteSaved: ((SavedCard) async throws -> Void)?
    package var onApplePay: (() -> Void)?
    package var onOpenPersonalDetails: (() -> Void)?
    package var onContentSizeChange: (() -> Void)?

    private var config: PaymentConfig
    private var state: SheetState
    private let contentInsets: ContentInsets
    private let contentStack = UIStackView()
    private let rootStack = UIStackView()
    private let payButton = PayCTAButton()
    private var cardForm: CardFormView?
    private var walletButton: PKPaymentButton?
    private var personalDetailsRow: PersonalDetailsEntryRow?
    private var methodContainer: PaymentMethodContainerView?
    private var selection: MethodSelection
    private var isProcessing = false
    private var isUpdatingOrder = false
    private var isOrderConsumed = false
    private var isEditingSavedCards = false
    private var pendingDeleteId: String?
    private var isDeletingSavedCard = false
    private var poweredFooter: PoweredByFooterView?
    private var rootBottomConstraint: NSLayoutConstraint?
    /// Cached content height — never measure via `systemLayoutSizeFitting` inside
    /// `intrinsicContentSize` (re-entrant Auto Layout → EXC_BAD_ACCESS).
    private var cachedContentHeight: CGFloat = 280
    private var isMeasuringHeight = false

    private var theme: CheckoutTheme {
        CheckoutTheme.resolve(
            config: config,
            isDark: UIHelpers.isDarkMode(config: config, traitCollection: traitCollection)
        )
    }

    package init(
        config: PaymentConfig,
        state: SheetState,
        contentInsets: ContentInsets = .embedded
    ) {
        self.config = config
        self.state = state
        self.contentInsets = contentInsets
        if let first = state.savedCards.first {
            selection = .saved(first.id)
        } else {
            selection = .newCard
        }
        super.init(frame: .zero)
        buildLayout()
        applySelection(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    package override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            rebuild()
        }
    }

    package func update(state: SheetState) {
        self.state = state
        if case let .saved(id) = selection, !state.savedCards.contains(where: { $0.id == id }) {
            if let first = state.savedCards.first {
                selection = .saved(first.id)
            } else {
                selection = .newCard
                isEditingSavedCards = false
            }
        }
        if state.savedCards.isEmpty {
            isEditingSavedCards = false
            pendingDeleteId = nil
        } else if let pending = pendingDeleteId, !state.savedCards.contains(where: { $0.id == pending }) {
            pendingDeleteId = nil
        }
        rebuild()
    }

    package func applyConfig(_ config: PaymentConfig) {
        self.config = config
        applyPageFill()
        poweredFooter?.apply(theme: theme, locale: config.options.locale)
        rebuild()
        updatePayButtonAppearance()
    }

    package func setProcessing(_ processing: Bool) {
        isProcessing = processing
        syncInteractionEnabled()
        updatePayButtonAppearance()
    }

    /// Locks Pay / wallet without swapping the title to “Processing...”.
    /// Charge in flight uses ``setProcessing(_:)`` instead.
    package func setUpdatingOrder(_ updating: Bool) {
        isUpdatingOrder = updating
        syncInteractionEnabled()
        updatePayButtonAppearance()
    }

    package func setOrderConsumed(_ consumed: Bool) {
        isOrderConsumed = consumed
        syncInteractionEnabled()
        updatePayButtonAppearance()
    }

    private var interactionEnabled: Bool {
        !isProcessing && !isUpdatingOrder && !isOrderConsumed
    }

    private func syncInteractionEnabled() {
        isUserInteractionEnabled = interactionEnabled
    }

    package func preferredHeight(forWidth width: CGFloat) -> CGFloat {
        refreshCachedHeight(forWidth: width)
        return cachedContentHeight
    }

    package var contentHeight: CGFloat { cachedContentHeight }

    /// Card form has a real size, and the Apple Pay button has drawn when the
    /// order offers it. Returns after a short cap if PassKit never paints.
    /// Returns `false` when the form or the wallet button is not in a window,
    /// including when a rebuild replaced the button during the wait.
    @discardableResult
    package func waitUntilSurfaceDrawn(timeout: TimeInterval = 2) async -> Bool {
        layoutIfNeeded()
        if let walletButton {
            return await SurfacePaint.waitUntilButtonDrawn(walletButton, timeout: timeout)
        }
        return await SurfacePaint.waitUntilLaidOut(self, timeout: timeout)
    }

    var isLockedForTesting: Bool { !interactionEnabled }
    var walletButtonForTesting: UIView? { walletButton }

    package override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: cachedContentHeight)
    }

    package override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        let previous = cachedContentHeight
        refreshCachedHeight(forWidth: bounds.width)
        if abs(cachedContentHeight - previous) > 1 {
            // Defer invalidation — never invalidate during an active layout pass.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.invalidateIntrinsicContentSize()
                self.onContentSizeChange?()
            }
        }
    }

    private func refreshCachedHeight(forWidth width: CGFloat) {
        guard !isMeasuringHeight else { return }
        isMeasuringHeight = true
        defer { isMeasuringHeight = false }

        let rootHeight = rootStack.systemLayoutSizeFitting(
            CGSize(width: max(width, 1), height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        cachedContentHeight = max(ceil(rootHeight + contentInsets.top + contentInsets.bottom), 160)
    }

    private func rebuild() {
        let draft = cardForm?.draft
        let showingErrors = cardForm?.hasVisibleErrors ?? false
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        cardForm = nil
        walletButton = nil
        personalDetailsRow = nil
        methodContainer = nil
        buildContent()
        if let draft {
            cardForm?.restore(draft)
        }
        if showingErrors {
            cardForm?.relocalizeVisibleErrors()
        }
        applySelection(animated: false)
    }

    private var isEmbedded: Bool { contentInsets == .embedded }

    private func applyPageFill() {
        if isEmbedded {
            backgroundColor = .clear
            isOpaque = false
        } else {
            backgroundColor = theme.background
            isOpaque = true
        }
    }

    private func buildLayout() {
        let t = theme
        applyPageFill()

        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        payButton.translatesAutoresizingMaskIntoConstraints = false
        payButton.onTap = { [weak self] in self?.payTapped() }
        payButton.isHidden = hidesPayButton
        payButton.apply(theme: t, title: "", processing: false, enabled: true)

        let powered = PoweredByFooterView(theme: t, locale: config.options.locale)
        poweredFooter = powered

        let contentWrap = UIView()
        contentWrap.translatesAutoresizingMaskIntoConstraints = false
        contentWrap.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentWrap.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: contentWrap.leadingAnchor, constant: contentInsets.horizontal),
            contentStack.trailingAnchor.constraint(equalTo: contentWrap.trailingAnchor, constant: -contentInsets.horizontal),
            contentStack.bottomAnchor.constraint(equalTo: contentWrap.bottomAnchor),
        ])

        let footerInner = UIStackView(arrangedSubviews: [payButton, powered])
        footerInner.axis = .vertical
        footerInner.spacing = 10
        footerInner.translatesAutoresizingMaskIntoConstraints = false

        let footerWrap = UIView()
        footerWrap.translatesAutoresizingMaskIntoConstraints = false
        footerWrap.addSubview(footerInner)

        var footerConstraints: [NSLayoutConstraint] = [
            footerInner.leadingAnchor.constraint(equalTo: footerWrap.leadingAnchor, constant: contentInsets.horizontal),
            footerInner.trailingAnchor.constraint(equalTo: footerWrap.trailingAnchor, constant: -contentInsets.horizontal),
            footerInner.bottomAnchor.constraint(equalTo: footerWrap.bottomAnchor),
        ]
        if isEmbedded {
            // Compact: no hairline; 8pt above Pay / powered-by (matches Android).
            footerConstraints.append(
                footerInner.topAnchor.constraint(equalTo: footerWrap.topAnchor, constant: 8)
            )
        } else {
            let footerHairline = UIView()
            footerHairline.backgroundColor = t.footerBorder
            footerHairline.translatesAutoresizingMaskIntoConstraints = false
            footerWrap.addSubview(footerHairline)
            footerConstraints.append(contentsOf: [
                footerHairline.topAnchor.constraint(equalTo: footerWrap.topAnchor),
                footerHairline.leadingAnchor.constraint(equalTo: footerWrap.leadingAnchor),
                footerHairline.trailingAnchor.constraint(equalTo: footerWrap.trailingAnchor),
                footerHairline.heightAnchor.constraint(equalToConstant: 1),
                footerInner.topAnchor.constraint(equalTo: footerHairline.bottomAnchor, constant: 12),
            ])
        }
        NSLayoutConstraint.activate(footerConstraints)

        rootStack.axis = .vertical
        rootStack.spacing = 0
        rootStack.alignment = .fill
        rootStack.addArrangedSubview(contentWrap)
        rootStack.addArrangedSubview(footerWrap)
        rootStack.setCustomSpacing(isEmbedded ? 0 : 16, after: contentWrap)
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rootStack)

        let bottom = rootStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -contentInsets.bottom)
        // Embedded hosts own the height and apply it a frame later. A required bottom pin
        // squeezes the details row while that height is still the previous one.
        if isEmbedded { bottom.priority = .defaultLow - 1 }
        rootBottomConstraint = bottom
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top),
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottom,
        ])

        buildContent()
    }

    package func applyBottomSafeArea(_ safeAreaBottom: CGFloat) {
        let inset = contentInsets.bottom + safeAreaBottom
        let constant = -inset
        guard rootBottomConstraint?.constant != constant else { return }
        rootBottomConstraint?.constant = constant
        setNeedsLayout()
    }

    private func buildContent() {
        let t = theme
        walletButton = nil

        if state.applePayAvailable, state.applePayReady {
            #if DEBUG
            if config.paymentMethods.applePay.enabled, DigitalWalletFactory.makeApplePay == nil {
                assertionFailure(
                    "Apple Pay is enabled but XMoneyApplePay is not linked. Link the XMoneyApplePay module so Apple Pay installs on load."
                )
            }
            #endif
            let isDark = UIHelpers.isDarkMode(config: config, traitCollection: traitCollection)
            let style = ApplePayButtonFactory.style(
                appearance: config.paymentMethods.applePay.appearance,
                isDarkBackground: isDark
            )
            let type = ApplePayButtonFactory.type(from: config.paymentMethods.applePay.appearance.type)
            let applePayButton = ApplePayButtonFactory.make(type: type, style: style)
            applePayButton.addTarget(self, action: #selector(applePayTapped), for: .touchUpInside)
            applePayButton.translatesAutoresizingMaskIntoConstraints = false
            applePayButton.heightAnchor.constraint(equalToConstant: t.walletButtonHeight).isActive = true
            if let radius = config.paymentMethods.applePay.appearance.radius {
                applePayButton.cornerRadius = CGFloat(radius)
            } else {
                applePayButton.cornerRadius = t.walletButtonHeight / 2
            }
            if t.isDark {
                applePayButton.layer.shadowOpacity = 0
            } else {
                applePayButton.layer.shadowColor = UIColor(red: 22 / 255, green: 20 / 255, blue: 26 / 255, alpha: 1).cgColor
                applePayButton.layer.shadowOpacity = 0.18
                applePayButton.layer.shadowOffset = CGSize(width: 0, height: 6)
                applePayButton.layer.shadowRadius = 9
                applePayButton.layer.masksToBounds = false
            }
            walletButton = applePayButton
            contentStack.addArrangedSubview(applePayButton)
            contentStack.addArrangedSubview(
                OrDividerView(theme: t, label: Strings.text("sheet.or", locale: config.options.locale))
            )
        }

        if collectsPersonalDetails {
            let row = PersonalDetailsEntryRow(theme: t, locale: config.options.locale)
            row.onTap = { [weak self] in self?.onOpenPersonalDetails?() }
            row.apply(
                completed: state.personalDetails.isComplete,
                showsError: state.personalDetails.showsIncompleteError && !state.personalDetails.isComplete
            )
            personalDetailsRow = row
            contentStack.addArrangedSubview(row)
        }

        let formConfig = CardFormView.Configuration(
            showSaveOptIn: config.card.savedCards.optInVisible && !state.orderInfo.isVerifyCard,
            showCardDetailsCaption: !config.card.inputs.isSpaced,
            validationMode: config.card.validationMode,
            locale: config.options.locale,
            grouping: config.card.inputs.grouping
        )
        let form = CardFormView(theme: t, config: formConfig)
        form.onContentSizeChange = { [weak self] in
            guard let self else { return }
            let width = self.bounds.width > 0 ? self.bounds.width : UIScreen.main.bounds.width
            self.refreshCachedHeight(forWidth: width)
            self.invalidateIntrinsicContentSize()
            self.onContentSizeChange?()
        }
        cardForm = form

        if !state.savedCards.isEmpty {
            let container = PaymentMethodContainerView(theme: t, cards: state.savedCards, locale: config.options.locale)
            container.onSelectSaved = { [weak self] card in
                self?.setSelection(.saved(card.id), animated: true)
            }
            container.onUseOtherCard = { [weak self] in
                self?.setSelection(.newCard, animated: true)
            }
            container.onExpandSaved = { [weak self] in
                guard let self, let first = self.state.savedCards.first else { return }
                self.setSelection(.saved(first.id), animated: true)
            }
            container.onToggleEdit = { [weak self] in
                guard let self else { return }
                self.isEditingSavedCards.toggle()
                self.pendingDeleteId = nil
                self.applySelection(animated: true)
            }
            container.onAskDelete = { [weak self] card in
                self?.pendingDeleteId = card.id
                self?.applySelection(animated: true)
            }
            container.onCancelDelete = { [weak self] in
                self?.pendingDeleteId = nil
                self?.applySelection(animated: true)
            }
            container.onConfirmDelete = { [weak self] card in
                self?.confirmDelete(card)
            }
            methodContainer = container
            contentStack.addArrangedSubview(container)
        } else {
            contentStack.addArrangedSubview(form)
        }

        updatePayButtonAppearance()
    }

    private func applySelection(animated: Bool, reportHeightImmediately: Bool = false) {
        if let container = methodContainer, let form = cardForm {
            container.apply(
                selection: mapSelection(),
                formView: selection == .newCard ? form : nil,
                isEditing: isEditingSavedCards,
                pendingDeleteId: pendingDeleteId,
                isDeleting: isDeletingSavedCard,
                animated: animated
            )
        }
        updatePayButtonAppearance()
        if reportHeightImmediately {
            layoutIfNeeded()
            let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
            refreshCachedHeight(forWidth: width)
            invalidateIntrinsicContentSize()
            onContentSizeChange?()
            return
        }
        setNeedsLayout()
        // Defer measurement + callbacks until after the current layout pass.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.layoutIfNeeded()
            let width = self.bounds.width > 0 ? self.bounds.width : UIScreen.main.bounds.width
            self.refreshCachedHeight(forWidth: width)
            self.invalidateIntrinsicContentSize()
            self.onContentSizeChange?()
        }
    }

    private func mapSelection() -> PaymentMethodContainerView.Selection {
        switch selection {
        case let .saved(id): return .saved(id)
        case .newCard: return .newCard
        }
    }

    private func setSelection(_ newSelection: MethodSelection, animated: Bool) {
        guard selection != newSelection else { return }
        if newSelection == .newCard {
            cardForm?.resetErrors()
            isEditingSavedCards = false
            pendingDeleteId = nil
        }
        selection = newSelection
        applySelection(animated: animated, reportHeightImmediately: true)
    }

    private func confirmDelete(_ card: SavedCard) {
        isDeletingSavedCard = true
        applySelection(animated: false)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.onDeleteSaved?(card)
            } catch {
                // Keep the confirm open; the card is still present.
            }
            self.isDeletingSavedCard = false
            self.applySelection(animated: false)
        }
    }

    private var hidesPayButton: Bool {
        // Sheet always shows Pay. `submitButton.visible` is Embedded-only.
        isEmbedded && !config.card.submitButton.visible
    }

    private func updatePayButtonAppearance() {
        let t = theme
        payButton.isHidden = hidesPayButton
        if isProcessing {
            let processing = Strings.text("button.processing", locale: config.options.locale)
            payButton.apply(theme: t, title: processing, processing: true, enabled: false)
            return
        }
        let amount = Strings.formatAmount(
            state.orderInfo.amount,
            currency: state.orderInfo.currency,
            locale: config.options.locale
        )
        let title = Strings.submitButtonTitle(
            type: config.card.submitButton.type.rawValue,
            locale: config.options.locale,
            amount: amount
        )
        payButton.apply(theme: t, title: title, processing: false, enabled: interactionEnabled)
    }

    package func confirm() {
        payTapped()
    }

    package func refreshPersonalDetailsRow() {
        personalDetailsRow?.apply(
            completed: state.personalDetails.isComplete,
            showsError: state.personalDetails.showsIncompleteError && !state.personalDetails.isComplete
        )
        publishHeightChange()
    }

    private var collectsPersonalDetails: Bool {
        config.customerDetails.card && state.customerDetailsVisibility.isActive
    }

    private func personalDetailsPayload() -> CustomerDetails? {
        guard collectsPersonalDetails else { return nil }
        return state.personalDetails.committed?.makeCustomerDetails(visibility: state.customerDetailsVisibility)
    }

    private func ensurePersonalDetails() -> Bool {
        guard collectsPersonalDetails else { return true }
        if state.personalDetails.isComplete {
            if state.personalDetails.showsIncompleteError {
                state.personalDetails.showsIncompleteError = false
                refreshPersonalDetailsRow()
            }
            return true
        }
        state.personalDetails.showsIncompleteError = true
        refreshPersonalDetailsRow()
        scrollIncompletePersonalDetailsIntoView()
        return false
    }

    /// The entry row sits at the top. A Pay tap lower on the sheet can leave the error off screen.
    private func scrollIncompletePersonalDetailsIntoView() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let row = self.personalDetailsRow else { return }
            self.layoutIfNeeded()
            guard let scrollView = Self.ancestorScrollView(from: row) else { return }
            scrollView.layoutIfNeeded()
            let fieldRect = row.convert(row.bounds, to: scrollView)
            let visibleBottom = CGRect(
                x: scrollView.bounds.minX,
                y: scrollView.bounds.maxY,
                width: scrollView.bounds.width,
                height: 0
            )
            guard let target = KeyboardScroll.targetOffset(
                fieldRect: fieldRect,
                bounds: scrollView.bounds,
                contentSize: scrollView.contentSize,
                contentOffset: scrollView.contentOffset,
                keyboardFrame: visibleBottom,
                padding: 16
            ) else { return }
            scrollView.setContentOffset(target, animated: true)
        }
    }

    private static func ancestorScrollView(from view: UIView) -> UIScrollView? {
        var current = view.superview
        while let candidate = current {
            if let scroll = candidate as? UIScrollView { return scroll }
            current = candidate.superview
        }
        return nil
    }

    private func publishHeightChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.layoutIfNeeded()
            let width = self.bounds.width > 0 ? self.bounds.width : UIScreen.main.bounds.width
            self.refreshCachedHeight(forWidth: width)
            self.invalidateIntrinsicContentSize()
            self.onContentSizeChange?()
        }
    }

    @objc private func payTapped() {
        guard !isProcessing, !isOrderConsumed, isUserInteractionEnabled else { return }
        switch selection {
        case let .saved(id):
            guard let card = state.savedCards.first(where: { $0.id == id }) else { return }
            guard ensurePersonalDetails() else { return }
            onSelectSaved?(card, personalDetailsPayload())
        case .newCard:
            guard let form = cardForm else { return }
            let cardOK = form.validateAndShowErrors()
            let detailsOK = ensurePersonalDetails()
            guard cardOK, detailsOK else { return }
            onPayCard?(form.currentInput, personalDetailsPayload())
        }
    }

    @objc private func applePayTapped() {
        guard !isProcessing, !isOrderConsumed, isUserInteractionEnabled else { return }
        onApplePay?()
    }

}
