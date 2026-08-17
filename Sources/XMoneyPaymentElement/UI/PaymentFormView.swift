import UIKit
import PassKit
#if !COCOAPODS
import XMoneyCore
#endif

package final class PaymentFormView: UIView {
    package struct ContentInsets {
        package var horizontal: CGFloat
        package var top: CGFloat
        package var bottom: CGFloat

        package init(horizontal: CGFloat, top: CGFloat, bottom: CGFloat) {
            self.horizontal = horizontal
            self.top = top
            self.bottom = bottom
        }

        package static let embedded = ContentInsets(horizontal: 16, top: 12, bottom: 8)
        package static let sheet = ContentInsets(horizontal: 22, top: 16, bottom: 16)
    }

    package enum MethodSelection: Equatable {
        case saved(String)
        case newCard
    }

    package var onPayCard: ((CardInput) -> Void)?
    package var onSelectSaved: ((SavedCard) -> Void)?
    package var onDeleteSaved: ((SavedCard) async throws -> Void)?
    package var onApplePay: (() -> Void)?
    package var onContentSizeChange: (() -> Void)?

    private let config: PaymentConfig
    private var state: SheetState
    private let contentInsets: ContentInsets
    private let contentStack = UIStackView()
    private let rootStack = UIStackView()
    private let payButton = UIButton(type: .system)
    private let payTitleLabel = UILabel()
    private let coinMarkContainer = UIView()
    private var coinMark: XCoinButtonMarkView?
    private var cardForm: CardFormView?
    private var methodContainer: PaymentMethodContainerView?
    private var selection: MethodSelection
    private var isProcessing = false
    private var isOrderConsumed = false
    private var isEditingSavedCards = false
    private var pendingDeleteId: String?
    private var isDeletingSavedCard = false
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

    package func setProcessing(_ processing: Bool) {
        isProcessing = processing
        isUserInteractionEnabled = !processing && !isOrderConsumed
        updatePayButtonAppearance()
    }

    package func setOrderConsumed(_ consumed: Bool) {
        isOrderConsumed = consumed
        isUserInteractionEnabled = !isProcessing && !consumed
        updatePayButtonAppearance()
    }

    package func preferredHeight(forWidth width: CGFloat) -> CGFloat {
        refreshCachedHeight(forWidth: width)
        return cachedContentHeight
    }

    package var contentHeight: CGFloat { cachedContentHeight }

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

        let inner = max(width - contentInsets.horizontal * 2, 1)
        let rootHeight = rootStack.systemLayoutSizeFitting(
            CGSize(width: inner, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        cachedContentHeight = max(ceil(rootHeight + contentInsets.top + contentInsets.bottom), 160)
    }

    private func rebuild() {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        cardForm = nil
        methodContainer = nil
        buildContent()
        applySelection(animated: false)
    }

    private func buildLayout() {
        let t = theme
        backgroundColor = t.background

        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        payButton.translatesAutoresizingMaskIntoConstraints = false
        payButton.layer.cornerRadius = t.payButtonHeight / 2
        payButton.heightAnchor.constraint(equalToConstant: t.payButtonHeight).isActive = true
        payButton.addTarget(self, action: #selector(payTapped), for: .touchUpInside)
        payButton.isHidden = !config.card.submitButton.visible
        payButton.clipsToBounds = true

        payTitleLabel.font = t.font(ofSize: 16, weight: .bold)
        payTitleLabel.textAlignment = .center
        payTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        payButton.addSubview(payTitleLabel)

        coinMarkContainer.translatesAutoresizingMaskIntoConstraints = false
        coinMarkContainer.isHidden = true
        payButton.addSubview(coinMarkContainer)

        NSLayoutConstraint.activate([
            payTitleLabel.centerXAnchor.constraint(equalTo: payButton.centerXAnchor, constant: 12),
            payTitleLabel.centerYAnchor.constraint(equalTo: payButton.centerYAnchor),

            coinMarkContainer.trailingAnchor.constraint(equalTo: payTitleLabel.leadingAnchor, constant: -12),
            coinMarkContainer.centerYAnchor.constraint(equalTo: payButton.centerYAnchor),
            coinMarkContainer.widthAnchor.constraint(equalToConstant: 17),
            coinMarkContainer.heightAnchor.constraint(equalToConstant: 17 * 418 / 539),
        ])

        let powered = PoweredByFooterView(theme: t, locale: config.options.locale)
        let footerHairline = UIView()
        footerHairline.backgroundColor = t.footerBorder
        footerHairline.translatesAutoresizingMaskIntoConstraints = false
        footerHairline.heightAnchor.constraint(equalToConstant: 1).isActive = true

        rootStack.axis = .vertical
        rootStack.spacing = 0
        rootStack.alignment = .fill
        [contentStack, footerHairline, payButton, powered].forEach { rootStack.addArrangedSubview($0) }
        rootStack.setCustomSpacing(12, after: contentStack)
        rootStack.setCustomSpacing(0, after: footerHairline)
        rootStack.setCustomSpacing(10, after: payButton)
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rootStack)

        let bottom = rootStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -contentInsets.bottom)
        rootBottomConstraint = bottom
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top),
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentInsets.horizontal),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentInsets.horizontal),
            bottom,
        ])

        buildContent()
    }

    package func applyBottomSafeArea(_ safeAreaBottom: CGFloat) {
        let inset = max(contentInsets.bottom, safeAreaBottom)
        let constant = -inset
        guard rootBottomConstraint?.constant != constant else { return }
        rootBottomConstraint?.constant = constant
        setNeedsLayout()
    }

    private func buildContent() {
        let t = theme

        if state.applePayAvailable {
            #if DEBUG
            if config.paymentMethods.applePay.enabled, DigitalWalletFactory.makeApplePay == nil {
                assertionFailure(
                    "Apple Pay is enabled but XMoneyApplePay is not linked. Link the XMoneyApplePay module so Apple Pay installs on load."
                )
            }
            #endif
            let isDark = UIHelpers.isDarkMode(config: config, traitCollection: traitCollection)
            let style = Self.applePayButtonStyle(
                appearance: config.paymentMethods.applePay.appearance,
                isDarkBackground: isDark
            )
            let type = Self.applePayButtonType(from: config.paymentMethods.applePay.appearance.type)
            let applePayButton = PKPaymentButton(paymentButtonType: type, paymentButtonStyle: style)
            applePayButton.addTarget(self, action: #selector(applePayTapped), for: .touchUpInside)
            applePayButton.translatesAutoresizingMaskIntoConstraints = false
            applePayButton.heightAnchor.constraint(equalToConstant: t.walletButtonHeight).isActive = true
            if let radius = config.paymentMethods.applePay.appearance.radius {
                applePayButton.cornerRadius = CGFloat(radius)
            } else {
                applePayButton.cornerRadius = t.walletButtonHeight / 2
            }
            contentStack.addArrangedSubview(applePayButton)
            contentStack.addArrangedSubview(
                OrDividerView(theme: t, label: Strings.text("sheet.or", locale: config.options.locale))
            )
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

    private func applySelection(animated: Bool) {
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
        applySelection(animated: animated)
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

    private func updatePayButtonAppearance() {
        let t = theme

        if isProcessing {
            let processing = Strings.text("button.processing", locale: config.options.locale)
            payTitleLabel.text = processing
            payTitleLabel.textColor = t.primaryButtonText
            payButton.backgroundColor = t.primaryButtonBackground
            payButton.layer.borderWidth = t.primaryButtonBorderWidth
            payButton.layer.borderColor = t.primaryButtonBorder.cgColor
            payButton.isEnabled = false
            payButton.alpha = 0.9
            showCoinMark(color: t.primaryButtonText)
            return
        }

        coinMarkContainer.isHidden = true
        coinMark?.stopAnimating()
        coinMark?.removeFromSuperview()
        coinMark = nil

        let amount = Strings.formatAmount(state.orderInfo.amount, currency: state.orderInfo.currency)
        let title = Strings.submitButtonTitle(type: config.card.submitButton.type.rawValue, locale: config.options.locale, amount: amount)
        payTitleLabel.text = title
        payTitleLabel.textColor = t.primaryButtonText
        payButton.backgroundColor = t.primaryButtonBackground
        payButton.layer.borderWidth = t.primaryButtonBorderWidth
        payButton.layer.borderColor = t.primaryButtonBorder.cgColor
        payButton.isEnabled = !isOrderConsumed
        payButton.alpha = isOrderConsumed ? 0.5 : 1.0
    }

    private func showCoinMark(color: UIColor) {
        coinMark?.removeFromSuperview()
        let mark = XCoinButtonMarkView(color: color)
        mark.translatesAutoresizingMaskIntoConstraints = false
        coinMarkContainer.addSubview(mark)
        NSLayoutConstraint.activate([
            mark.centerXAnchor.constraint(equalTo: coinMarkContainer.centerXAnchor),
            mark.centerYAnchor.constraint(equalTo: coinMarkContainer.centerYAnchor),
        ])
        coinMarkContainer.isHidden = false
        coinMark = mark
        mark.startAnimating()
    }

    @objc private func payTapped() {
        guard !isProcessing, !isOrderConsumed else { return }
        switch selection {
        case let .saved(id):
            guard let card = state.savedCards.first(where: { $0.id == id }) else { return }
            onSelectSaved?(card)
        case .newCard:
            guard let form = cardForm else { return }
            guard form.validateAndShowErrors() else { return }
            onPayCard?(form.currentInput)
        }
    }

    @objc private func applePayTapped() {
        guard !isProcessing, !isOrderConsumed else { return }
        onApplePay?()
    }

    private static func applePayButtonStyle(
        appearance: PaymentConfig.WalletAppearance,
        isDarkBackground: Bool
    ) -> PKPaymentButtonStyle {
        switch appearance.color {
        case .white: return .white
        case .whiteOutline: return .whiteOutline
        case .black: return .black
        case nil: return isDarkBackground ? .white : .black
        }
    }

    private static func applePayButtonType(from type: PaymentConfig.WalletButtonType?) -> PKPaymentButtonType {
        switch type {
        case .buy: return .buy
        case .checkout: return .checkout
        case .donate: return .donate
        case .order: return .order
        case .pay: return .inStore
        case .subscribe: return .subscribe
        case .book: return .book
        case .topUp: return .topUp
        case .plain, nil: return .plain
        }
    }
}
