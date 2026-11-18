import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

final class PaymentMethodContainerView: UIView {
    enum Selection: Equatable {
        case saved(String)
        case newCard
        /// Another payment method outside this container is selected.
        case none
    }

    var onSelectSaved: ((SavedCard) -> Void)?
    var onUseOtherCard: (() -> Void)?
    var onExpandSaved: (() -> Void)?
    var onToggleEdit: (() -> Void)?
    var onAskDelete: ((SavedCard) -> Void)?
    var onConfirmDelete: ((SavedCard) -> Void)?
    var onCancelDelete: (() -> Void)?

    private let theme: CheckoutTheme
    private let cards: [SavedCard]
    private let locale: String

    private let rootStack = UIStackView()
    private let headerView = UIView()
    private let headerTitle = UILabel()
    private let editButton = UIButton(type: .system)
    private let outerContainer = UIView()
    private let contentStack = UIStackView()
    private var expandedStack: UIStackView?
    private var collapsedSummaryButton: UIControl?
    private var newCardBlock: UIView?
    private var rowControls: [String: UIControl] = [:]
    private var radioIndicators: [String: RadioIndicator] = [:]
    private var selectionOverlays: [String: UIView] = [:]

    private var isEditing = false
    private var pendingDeleteId: String?
    private var isDeleting = false

    private enum BuiltState: Equatable {
        case expanded
        case collapsed
        case otherMethod
    }

    private var builtState: BuiltState?
    private var expandedHeaderConstraints: [NSLayoutConstraint] = []
    private var collapsedHeaderConstraints: [NSLayoutConstraint] = []

    init(theme: CheckoutTheme, cards: [SavedCard], locale: String) {
        self.theme = theme
        self.cards = cards
        self.locale = locale
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        rootStack.axis = .vertical
        rootStack.spacing = 0
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        headerView.translatesAutoresizingMaskIntoConstraints = false
        setupHeader()

        outerContainer.backgroundColor = theme.componentBackground
        outerContainer.layer.cornerRadius = theme.containerRadius
        outerContainer.layer.borderColor = theme.containerBorder.cgColor
        outerContainer.layer.borderWidth = theme.containerBorderWidth
        outerContainer.translatesAutoresizingMaskIntoConstraints = false

        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let inner = UIStackView(arrangedSubviews: [headerView, contentStack])
        inner.axis = .vertical
        inner.spacing = 0
        inner.translatesAutoresizingMaskIntoConstraints = false
        outerContainer.addSubview(inner)
        rootStack.addArrangedSubview(outerContainer)
        addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            inner.topAnchor.constraint(equalTo: outerContainer.topAnchor, constant: 6),
            inner.leadingAnchor.constraint(equalTo: outerContainer.leadingAnchor, constant: 6),
            inner.trailingAnchor.constraint(equalTo: outerContainer.trailingAnchor, constant: -6),
            inner.bottomAnchor.constraint(equalTo: outerContainer.bottomAnchor, constant: -6),
        ])
    }

    private func setupHeader() {
        headerTitle.attributedText = NSAttributedString(
            string: Strings.text("sheet.savedCards", locale: locale),
            attributes: theme.titleAttributes(size: 14, weight: .semibold, color: theme.metaText)
        )
        headerTitle.translatesAutoresizingMaskIntoConstraints = false

        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.addAction(UIAction { [weak self] _ in
            self?.onToggleEdit?()
        }, for: .touchUpInside)
        updateEditButtonTitle()

        editButton.contentHorizontalAlignment = .trailing
        headerView.addSubview(headerTitle)
        headerView.addSubview(editButton)
        expandedHeaderConstraints = [
            headerView.heightAnchor.constraint(equalToConstant: Self.expandedHeaderHeight),
            headerTitle.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
        ]
        collapsedHeaderConstraints = [
            headerTitle.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),
            headerTitle.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -2),
        ]
        NSLayoutConstraint.activate([
            headerTitle.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            editButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12),
            editButton.centerYAnchor.constraint(equalTo: headerTitle.centerYAnchor),
            editButton.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.expandedHeaderHeight),
            editButton.heightAnchor.constraint(equalToConstant: Self.expandedHeaderHeight),
            editButton.leadingAnchor.constraint(greaterThanOrEqualTo: headerTitle.trailingAnchor, constant: 8),
        ])
        NSLayoutConstraint.activate(collapsedHeaderConstraints)
        headerView.isHidden = true
        editButton.accessibilityLabel = Strings.text("sheet.edit", locale: locale)
    }

    private func updateHeaderTitle(expanded: Bool) {
        let base = Strings.text("sheet.savedCards", locale: locale)
        let title = expanded ? base : "\(base) · \(cards.count)"
        headerTitle.attributedText = NSAttributedString(
            string: title,
            attributes: theme.titleAttributes(
                size: 14,
                weight: .semibold,
                color: isEditing ? theme.sectionLabelColor : theme.metaText
            )
        )
        if expanded {
            NSLayoutConstraint.deactivate(collapsedHeaderConstraints)
            NSLayoutConstraint.activate(expandedHeaderConstraints)
        } else {
            NSLayoutConstraint.deactivate(expandedHeaderConstraints)
            NSLayoutConstraint.activate(collapsedHeaderConstraints)
        }
    }

    private func updateEditButtonTitle() {
        let key = isEditing ? "sheet.done" : "sheet.edit"
        editButton.setAttributedTitle(
            NSAttributedString(
                string: Strings.text(key, locale: locale),
                attributes: theme.titleAttributes(size: 14, weight: .semibold, color: theme.primary)
            ),
            for: .normal
        )
        editButton.accessibilityLabel = Strings.text(key, locale: locale)
    }

    func apply(
        selection: Selection,
        formView: CardFormView?,
        isEditing: Bool,
        pendingDeleteId: String?,
        isDeleting: Bool,
        animated: Bool
    ) {
        let editingChanged = self.isEditing != isEditing
            || self.pendingDeleteId != pendingDeleteId
            || self.isDeleting != isDeleting
        self.isEditing = isEditing
        self.pendingDeleteId = pendingDeleteId
        self.isDeleting = isDeleting
        updateEditButtonTitle()

        let targetState: BuiltState
        switch selection {
        case .newCard: targetState = .collapsed
        case .none: targetState = .otherMethod
        case .saved: targetState = .expanded
        }
        headerView.isHidden = targetState == .otherMethod
        editButton.isHidden = targetState != .expanded
        updateHeaderTitle(expanded: targetState == .expanded)

        if builtState == targetState {
            if targetState == .expanded {
                if editingChanged {
                    rebuild(selection: selection, formView: formView)
                } else {
                    updateSelectionInPlace(selection)
                }
            }
            if targetState == .collapsed, let formView, formView.superview == nil {
                rebuild(selection: selection, formView: formView)
            }
            return
        }

        rebuild(selection: selection, formView: formView)
        builtState = targetState

        setNeedsLayout()
        layoutIfNeeded()
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                self.layoutIfNeeded()
            }
        }
    }

    private func updateSelectionInPlace(_ selection: Selection) {
        guard !isEditing else { return }
        let selectedId: String?
        if case let .saved(id) = selection { selectedId = id } else { selectedId = nil }
        for card in cards {
            let isSelected = card.id == selectedId
            radioIndicators[card.id]?.setSelected(isSelected, theme: theme, animated: true)
            selectionOverlays[card.id]?.alpha = isSelected ? 1 : 0
        }
    }

    private func rebuild(selection: Selection, formView: CardFormView?) {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        rowControls.removeAll()
        radioIndicators.removeAll()
        selectionOverlays.removeAll()
        expandedStack = nil
        collapsedSummaryButton = nil
        newCardBlock = nil

        switch selection {
        case .newCard:
            buildCollapsedState(formView: formView)
        case .saved:
            buildExpandedState(selection: selection)
        case .none:
            buildOtherMethodState()
        }
    }

    /// Another method (crypto) is selected: the cards collapse to one idle "Pay with card" row.
    private func buildOtherMethodState() {
        let row = PaymentOptionRow(
            theme: theme,
            tile: .payWithCard,
            title: Strings.text("sheet.payWithCard", locale: locale),
            subtitle: Strings.text("sheet.visaOrMastercard", locale: locale)
        )
        row.setSelected(false)
        row.addAction(UIAction { [weak self] _ in
            self?.onExpandSaved?()
        }, for: .touchUpInside)
        contentStack.addArrangedSubview(row)
    }

    private func buildExpandedState(selection: Selection) {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        expandedStack = stack

        let cardsStack = UIStackView()
        cardsStack.axis = .vertical
        cardsStack.spacing = 0

        for card in cards {
            let isSelected: Bool
            if case let .saved(id) = selection {
                isSelected = card.id == id
            } else {
                isSelected = false
            }
            cardsStack.addArrangedSubview(makeSavedRow(card: card, isSelected: isSelected))
        }

        let scroll = PreferSelfScrollView()
        let needsScroll = cards.count > Self.maxVisibleSavedCards || pendingDeleteId != nil
        scroll.isScrollEnabled = needsScroll
        scroll.alwaysBounceVertical = false
        scroll.bounces = needsScroll
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.isDirectionalLockEnabled = true
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.clipsToBounds = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        cardsStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(cardsStack)

        let visibleRows = min(cards.count, Self.maxVisibleSavedCards)
        let extra = pendingDeleteId == nil ? 0 : Self.confirmPanelHeight
        let viewportHeight = Self.savedCardRowHeight * CGFloat(max(visibleRows, 1)) + extra
        let heightConstraint = scroll.heightAnchor.constraint(equalToConstant: viewportHeight)
        heightConstraint.priority = .required

        scroll.setContentHuggingPriority(.required, for: .vertical)
        scroll.setContentCompressionResistancePriority(.required, for: .vertical)

        NSLayoutConstraint.activate([
            cardsStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            cardsStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            cardsStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            cardsStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            cardsStack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            heightConstraint,
        ])

        stack.addArrangedSubview(scroll)
        if !isEditing {
            stack.addArrangedSubview(makeUseOtherCardRow())
        }
        contentStack.addArrangedSubview(stack)

        if let pending = pendingDeleteId, let index = cards.firstIndex(where: { $0.id == pending }) {
            let offset = Self.savedCardRowHeight * CGFloat(index)
            DispatchQueue.main.async {
                scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: true)
            }
        }
    }

    private static let savedCardRowHeight: CGFloat = 64
    private static let confirmPanelHeight: CGFloat = 102
    private static let maxVisibleSavedCards = 3
    private static let expandedHeaderHeight: CGFloat = 44
    private static let trashSize: CGFloat = 32

    private func buildCollapsedState(formView: CardFormView?) {
        let summary = makeCollapsedSummaryRow()
        collapsedSummaryButton = summary
        contentStack.addArrangedSubview(summary)

        let block = UIView()
        block.backgroundColor = theme.selectedBackground
        block.layer.cornerRadius = 12
        block.clipsToBounds = true
        block.translatesAutoresizingMaskIntoConstraints = false
        newCardBlock = block

        let blockStack = UIStackView()
        blockStack.axis = .vertical
        blockStack.spacing = 0
        blockStack.translatesAutoresizingMaskIntoConstraints = false
        block.addSubview(blockStack)

        let header = makeNewCardHeaderRow()
        blockStack.addArrangedSubview(header)

        if let formView {
            formView.removeFromSuperview()
            let wrapper = UIView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            formView.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(formView)
            NSLayoutConstraint.activate([
                formView.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 12),
                formView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 12),
                formView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -12),
                formView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            ])
            blockStack.addArrangedSubview(wrapper)
        }

        NSLayoutConstraint.activate([
            blockStack.topAnchor.constraint(equalTo: block.topAnchor),
            blockStack.leadingAnchor.constraint(equalTo: block.leadingAnchor),
            blockStack.trailingAnchor.constraint(equalTo: block.trailingAnchor),
            blockStack.bottomAnchor.constraint(equalTo: block.bottomAnchor),
        ])

        contentStack.addArrangedSubview(block)
    }

    private func makeSavedRow(card: SavedCard, isSelected: Bool) -> UIView {
        let isAsking = pendingDeleteId == card.id
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        control.layer.cornerRadius = theme.rowRadius
        if isAsking {
            control.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
        rowControls[card.id] = control

        let tile = BrandTileView(theme: theme, size: CGSize(width: 48, height: 34))
        tile.apply(style: .savedCard(brand: SavedCardFormatting.savedCardBrandForIcon(card)), theme: theme)

        let titleAttributes = theme.titleAttributes(color: theme.primaryText)

        let bankLabel = UILabel()
        bankLabel.attributedText = NSAttributedString(
            string: SavedCardFormatting.savedCardIssuerLabel(card),
            attributes: titleAttributes
        )
        bankLabel.numberOfLines = 1
        bankLabel.lineBreakMode = .byTruncatingTail
        bankLabel.setContentHuggingPriority(.required, for: .horizontal)
        bankLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let last4Label = UILabel()
        last4Label.attributedText = NSAttributedString(
            string: SavedCardFormatting.savedCardMaskedNumber(card),
            attributes: titleAttributes
        )
        last4Label.numberOfLines = 1
        last4Label.setContentHuggingPriority(.required, for: .horizontal)
        last4Label.setContentCompressionResistancePriority(.required, for: .horizontal)

        let titleSpacer = UIView()
        titleSpacer.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
        titleSpacer.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)

        let titleRow = UIStackView(arrangedSubviews: [bankLabel, last4Label, titleSpacer])
        titleRow.axis = .horizontal
        titleRow.spacing = 4
        titleRow.alignment = .center

        let subtitleLabel = UILabel()
        theme.style(
            subtitleLabel,
            text: SavedCardFormatting.savedCardMeta(card, locale: locale),
            size: 14,
            weight: .medium,
            color: theme.primaryText.withAlphaComponent(Self.expandedMetaAlpha)
        )

        let textStack = UIStackView(arrangedSubviews: [titleRow, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 0

        let trailing: UIView
        if isEditing {
            let spacer = UIView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.widthAnchor.constraint(equalToConstant: Self.trashSize).isActive = true
            spacer.heightAnchor.constraint(equalToConstant: Self.trashSize).isActive = true
            trailing = spacer
        } else {
            let radio = RadioIndicator(theme: theme)
            radio.setSelected(isSelected, theme: theme, animated: false)
            radioIndicators[card.id] = radio
            trailing = radio
        }

        let row = UIStackView(arrangedSubviews: [tile, textStack, trailing])
        row.axis = .horizontal
        row.spacing = isAsking ? 13 : 12
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        control.addSubview(row)

        let overlay = UIView()
        overlay.backgroundColor = isAsking
            ? theme.errorBorder.withAlphaComponent(0.08)
            : theme.selectedBackground
        overlay.isUserInteractionEnabled = false
        overlay.layer.cornerRadius = theme.rowRadius
        if isAsking {
            overlay.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
        overlay.alpha = (isAsking || (isSelected && !isEditing)) ? 1 : 0
        overlay.translatesAutoresizingMaskIntoConstraints = false
        control.insertSubview(overlay, at: 0)
        selectionOverlays[card.id] = overlay
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: control.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: control.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: control.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: control.bottomAnchor),
        ])

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: control.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: control.bottomAnchor, constant: -12),
        ])

        control.addAction(UIAction { [weak self] _ in
            self?.onSelectSaved?(card)
        }, for: .touchUpInside)
        control.accessibilityLabel = SavedCardFormatting.savedCardDisplayName(card)
        control.heightAnchor.constraint(equalToConstant: Self.savedCardRowHeight).isActive = true

        if isEditing {
            let trash = makeTrashButton(card: card)
            control.addSubview(trash)
            NSLayoutConstraint.activate([
                trash.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -12),
                trash.centerYAnchor.constraint(equalTo: control.centerYAnchor),
            ])
        }

        let column = UIStackView(arrangedSubviews: [control])
        column.axis = .vertical
        column.spacing = 0
        if isAsking {
            column.addArrangedSubview(makeConfirmPanel(card: card))
        }
        return column
    }

    private func makeTrashButton(card: SavedCard) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = theme.errorBorder.withAlphaComponent(0.09)
        button.layer.cornerRadius = Self.trashSize / 2
        button.tintColor = theme.errorText
        let image = EmbeddedAssets.image(named: "trash")?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.accessibilityLabel = Strings.text("sheet.delete", locale: locale)
        button.isEnabled = !isDeleting
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: Self.trashSize),
            button.heightAnchor.constraint(equalToConstant: Self.trashSize),
        ])
        button.addAction(UIAction { [weak self] _ in
            self?.onAskDelete?(card)
        }, for: .touchUpInside)
        button.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        UIView.animate(withDuration: 0.2) {
            button.transform = .identity
        }
        return button
    }

    private func makeConfirmPanel(card: SavedCard) -> UIView {
        let panel = UIView()
        panel.backgroundColor = theme.errorBorder.withAlphaComponent(0.08)
        panel.layer.cornerRadius = theme.rowRadius
        panel.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        panel.isAccessibilityElement = false
        panel.translatesAutoresizingMaskIntoConstraints = false

        let prompt = UILabel()
        theme.style(
            prompt,
            text: Strings.text("sheet.removeCardConfirm", locale: locale),
            size: 16,
            weight: .semibold,
            color: theme.primaryText,
            multiline: true
        )
        prompt.translatesAutoresizingMaskIntoConstraints = false

        let remove = makeConfirmPill(
            title: Strings.text("sheet.remove", locale: locale),
            background: theme.errorText,
            titleColor: .white
        )
        remove.isEnabled = !isDeleting
        remove.addAction(UIAction { [weak self] _ in
            self?.onConfirmDelete?(card)
        }, for: .touchUpInside)

        let keep = makeConfirmPill(
            title: Strings.text("sheet.keepIt", locale: locale),
            background: theme.primaryText,
            titleColor: Self.keepItText
        )
        keep.isEnabled = !isDeleting
        keep.addAction(UIAction { [weak self] _ in
            self?.onCancelDelete?()
        }, for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [remove, keep])
        buttons.axis = .horizontal
        buttons.spacing = 8
        buttons.distribution = .fillEqually
        buttons.translatesAutoresizingMaskIntoConstraints = false

        panel.addSubview(prompt)
        panel.addSubview(buttons)
        NSLayoutConstraint.activate([
            prompt.topAnchor.constraint(equalTo: panel.topAnchor, constant: 4),
            prompt.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 13),
            prompt.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -13),
            buttons.topAnchor.constraint(equalTo: prompt.bottomAnchor, constant: 12),
            buttons.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 13),
            buttons.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -13),
            buttons.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14),
            buttons.heightAnchor.constraint(equalToConstant: Self.confirmButtonHeight),
        ])
        return panel
    }

    private static let confirmButtonHeight: CGFloat = 48
    private static let keepItText = UIColor(hex: "#F7F6F9") ?? .white
    private static let expandedMetaAlpha: CGFloat = 0.45

    private func makeConfirmPill(
        title: String,
        background: UIColor,
        titleColor: UIColor
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = background
        button.layer.cornerRadius = Self.confirmButtonHeight / 2
        button.setAttributedTitle(
            NSAttributedString(
                string: title,
                attributes: theme.titleAttributes(
                    size: 14,
                    weight: .semibold,
                    color: titleColor,
                    alignment: .center
                )
            ),
            for: .normal
        )
        return button
    }

    private func makeUseOtherCardRow() -> UIView {
        let control = UIControl()
        let tile = BrandTileView(theme: theme, size: CGSize(width: 48, height: 34))
        tile.apply(style: .addCard, theme: theme)

        let title = UILabel()
        title.attributedText = NSAttributedString(
            string: Strings.text("sheet.useAnotherCard", locale: locale),
            attributes: theme.titleAttributes(color: theme.primary)
        )

        let visa = CardBrandIcon(size: .useOtherCardPair)
        visa.setBrand("visa", size: .useOtherCardPair, visaTint: theme.visaTint)
        let mc = CardBrandIcon(size: .useOtherCardPair)
        mc.setBrand("mastercard", size: .useOtherCardPair)
        let brands = UIStackView(arrangedSubviews: [visa, mc])
        brands.axis = .horizontal
        brands.alignment = .center
        brands.spacing = 8
        brands.alignment = .center

        let row = UIStackView(arrangedSubviews: [tile, title, brands])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        control.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -12),
            row.centerYAnchor.constraint(equalTo: control.centerYAnchor),
            control.heightAnchor.constraint(equalToConstant: Self.savedCardRowHeight),
        ])

        control.addAction(UIAction { [weak self] _ in
            self?.onUseOtherCard?()
        }, for: .touchUpInside)
        return control
    }

    private func makeCollapsedSummaryRow() -> UIControl {
        let control = UIControl()
        let card = cards.first
        let tile = BrandTileView(theme: theme, size: CGSize(width: 48, height: 34))
        tile.apply(style: .savedCard(brand: card.flatMap { SavedCardFormatting.savedCardBrandForIcon($0) }), theme: theme)

        let title = UILabel()
        let titleText = card.map { SavedCardFormatting.savedCardIssuerLabel($0) + " " + SavedCardFormatting.savedCardMaskedNumber($0) }
            ?? Strings.text("sheet.savedCards", locale: locale)
        title.attributedText = NSAttributedString(
            string: titleText,
            attributes: theme.titleAttributes(color: theme.primaryText)
        )

        let subtitle = UILabel()
        let subtitleText = card.map { SavedCardFormatting.savedCardMeta($0, locale: locale) } ?? ""
        theme.style(subtitle, text: subtitleText, size: 14, weight: .medium, color: theme.metaText)
        subtitle.isHidden = subtitleText.isEmpty

        let textStack = UIStackView(arrangedSubviews: [title, subtitle])
        textStack.axis = .vertical
        textStack.spacing = 0

        let chevron = UIImageView()
        chevron.image = EmbeddedAssets.image(named: "chevron-down")?
            .withRenderingMode(.alwaysTemplate)
        chevron.tintColor = theme.primary
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chevron.widthAnchor.constraint(equalToConstant: 16),
            chevron.heightAnchor.constraint(equalToConstant: 16),
        ])

        let row = UIStackView(arrangedSubviews: [tile, textStack, chevron])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        control.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: control.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: control.bottomAnchor, constant: -12),
        ])

        control.addAction(UIAction { [weak self] _ in
            self?.onExpandSaved?()
        }, for: .touchUpInside)
        return control
    }

    private func makeNewCardHeaderRow() -> UIView {
        let tile = BrandTileView(theme: theme, size: CGSize(width: 48, height: 34))
        tile.apply(style: .addCard, theme: theme)

        let title = UILabel()
        title.attributedText = NSAttributedString(
            string: Strings.text("sheet.useAnotherCard", locale: locale),
            attributes: theme.titleAttributes(color: theme.primaryText)
        )

        let subtitle = UILabel()
        theme.style(
            subtitle,
            text: Strings.text("sheet.visaOrMastercard", locale: locale),
            size: 14,
            weight: .medium,
            color: theme.sectionLabelColor
        )

        let textStack = UIStackView(arrangedSubviews: [title, subtitle])
        textStack.axis = .vertical
        textStack.spacing = 0

        let radio = RadioIndicator(theme: theme)
        radio.setSelected(true, theme: theme, animated: false)

        let row = UIStackView(arrangedSubviews: [tile, textStack, radio])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return row
    }
}
