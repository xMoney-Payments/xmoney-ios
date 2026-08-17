import UIKit
#if !COCOAPODS
import XMoneyCore
#endif

final class PaymentMethodContainerView: UIView {
    enum Selection: Equatable {
        case saved(String)
        case newCard
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
    }

    private var builtState: BuiltState?

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

        setupHeader()

        outerContainer.backgroundColor = theme.componentBackground
        outerContainer.layer.cornerRadius = theme.containerRadius
        outerContainer.layer.borderColor = theme.containerBorder.cgColor
        outerContainer.layer.borderWidth = theme.containerBorderWidth
        outerContainer.translatesAutoresizingMaskIntoConstraints = false

        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        outerContainer.addSubview(contentStack)
        rootStack.addArrangedSubview(headerView)
        rootStack.addArrangedSubview(outerContainer)
        addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: outerContainer.topAnchor, constant: 6),
            contentStack.leadingAnchor.constraint(equalTo: outerContainer.leadingAnchor, constant: 6),
            contentStack.trailingAnchor.constraint(equalTo: outerContainer.trailingAnchor, constant: -6),
            contentStack.bottomAnchor.constraint(equalTo: outerContainer.bottomAnchor, constant: -6),
        ])
    }

    private func setupHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.attributedText = NSAttributedString(
            string: Strings.text("sheet.savedCards", locale: locale),
            attributes: theme.titleAttributes(size: 13, weight: .semibold, color: theme.primaryText.withAlphaComponent(0.45))
        )
        title.translatesAutoresizingMaskIntoConstraints = false

        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.addAction(UIAction { [weak self] _ in
            self?.onToggleEdit?()
        }, for: .touchUpInside)
        updateEditButtonTitle()

        headerView.addSubview(title)
        headerView.addSubview(editButton)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 4),
            title.topAnchor.constraint(equalTo: headerView.topAnchor),
            title.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8),
            editButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -4),
            editButton.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            editButton.leadingAnchor.constraint(greaterThanOrEqualTo: title.trailingAnchor, constant: 8),
        ])
        headerView.isHidden = true
        editButton.accessibilityLabel = Strings.text("sheet.edit", locale: locale)
    }

    private func updateEditButtonTitle() {
        let key = isEditing ? "sheet.done" : "sheet.edit"
        editButton.setAttributedTitle(
            NSAttributedString(
                string: Strings.text(key, locale: locale),
                attributes: theme.titleAttributes(size: 13, weight: .bold, color: theme.primary)
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

        let targetState: BuiltState = selection == .newCard ? .collapsed : .expanded
        headerView.isHidden = targetState != .expanded

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
        guard case let .saved(selectedId) = selection, !isEditing else { return }
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
        }
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

        let separator = UIView()
        separator.backgroundColor = theme.fieldDivider
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stack.addArrangedSubview(separator)

        stack.addArrangedSubview(makeUseOtherCardRow())
        contentStack.addArrangedSubview(stack)

        if let pending = pendingDeleteId, let index = cards.firstIndex(where: { $0.id == pending }) {
            let offset = Self.savedCardRowHeight * CGFloat(index)
            DispatchQueue.main.async {
                scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: true)
            }
        }
    }

    private static let savedCardRowHeight: CGFloat = 56
    private static let confirmPanelHeight: CGFloat = 91
    private static let maxVisibleSavedCards = 3

    private func buildCollapsedState(formView: CardFormView?) {
        let summary = makeCollapsedSummaryRow()
        collapsedSummaryButton = summary
        contentStack.addArrangedSubview(summary)

        let block = UIView()
        block.backgroundColor = theme.selectedBackground
        block.layer.cornerRadius = theme.rowRadius
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
                formView.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 10),
                formView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 12),
                formView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -12),
                formView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -12),
            ])
            blockStack.addArrangedSubview(wrapper)
        }

        NSLayoutConstraint.activate([
            blockStack.topAnchor.constraint(equalTo: block.topAnchor),
            blockStack.leadingAnchor.constraint(equalTo: block.leadingAnchor),
            blockStack.trailingAnchor.constraint(equalTo: block.trailingAnchor),
            blockStack.bottomAnchor.constraint(equalTo: block.bottomAnchor),
        ])

        let blockWrapper = UIView()
        blockWrapper.translatesAutoresizingMaskIntoConstraints = false
        blockWrapper.addSubview(block)
        NSLayoutConstraint.activate([
            block.topAnchor.constraint(equalTo: blockWrapper.topAnchor),
            block.leadingAnchor.constraint(equalTo: blockWrapper.leadingAnchor, constant: -6),
            block.trailingAnchor.constraint(equalTo: blockWrapper.trailingAnchor, constant: 6),
            block.bottomAnchor.constraint(equalTo: blockWrapper.bottomAnchor, constant: 6),
        ])
        contentStack.addArrangedSubview(blockWrapper)
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

        let tile = BrandTileView(theme: theme)
        tile.apply(style: .savedCard(brand: SavedCardFormatting.savedCardBrandForIcon(card)), theme: theme)

        let title = UILabel()
        title.attributedText = NSAttributedString(
            string: SavedCardFormatting.savedCardDisplayName(card),
            attributes: theme.titleAttributes(color: theme.primaryText)
        )

        let subtitleLabel = UILabel()
        subtitleLabel.text = SavedCardFormatting.savedCardMeta(card, locale: locale)
        subtitleLabel.font = theme.font(ofSize: 13, weight: .medium)
        subtitleLabel.textColor = theme.primaryText.withAlphaComponent(0.45)

        let textStack = UIStackView(arrangedSubviews: [title, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 1

        let trailing: UIView
        if isEditing {
            let spacer = UIView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.widthAnchor.constraint(equalToConstant: 34).isActive = true
            spacer.heightAnchor.constraint(equalToConstant: 34).isActive = true
            trailing = spacer
        } else {
            let radio = RadioIndicator(theme: theme)
            radio.setSelected(isSelected, theme: theme, animated: false)
            radioIndicators[card.id] = radio
            trailing = radio
        }

        let row = UIStackView(arrangedSubviews: [tile, textStack, trailing])
        row.axis = .horizontal
        row.spacing = 13
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
        control.accessibilityLabel = title.text
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
        button.layer.cornerRadius = 17
        button.tintColor = theme.errorText
        let image = EmbeddedAssets.image(named: "trash")?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.accessibilityLabel = Strings.text("sheet.delete", locale: locale)
        button.isEnabled = !isDeleting
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 34),
            button.heightAnchor.constraint(equalToConstant: 34),
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
        prompt.text = Strings.text("sheet.removeCardConfirm", locale: locale)
        prompt.font = theme.font(ofSize: 15, weight: .bold)
        prompt.textColor = theme.primaryText
        prompt.numberOfLines = 0
        prompt.translatesAutoresizingMaskIntoConstraints = false

        let remove = makeConfirmPill(
            title: Strings.text("sheet.remove", locale: locale),
            background: theme.errorText,
            titleColor: .white,
            weight: .bold
        )
        remove.isEnabled = !isDeleting
        remove.addAction(UIAction { [weak self] _ in
            self?.onConfirmDelete?(card)
        }, for: .touchUpInside)

        let keep = makeConfirmPill(
            title: Strings.text("sheet.keepIt", locale: locale),
            background: theme.primaryText.withAlphaComponent(0.06),
            titleColor: theme.primaryText,
            weight: .semibold
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
            buttons.heightAnchor.constraint(equalToConstant: 46),
        ])
        return panel
    }

    private func makeConfirmPill(
        title: String,
        background: UIColor,
        titleColor: UIColor,
        weight: UIFont.Weight
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = background
        button.layer.cornerRadius = 23
        button.setAttributedTitle(
            NSAttributedString(
                string: title,
                attributes: theme.titleAttributes(size: 14.5, weight: weight, color: titleColor)
            ),
            for: .normal
        )
        return button
    }

    private func makeUseOtherCardRow() -> UIView {
        let control = UIControl()
        let tile = BrandTileView(theme: theme)
        tile.apply(style: .addCard, theme: theme)

        let title = UILabel()
        title.attributedText = NSAttributedString(
            string: Strings.text("sheet.useOtherCard", locale: locale),
            attributes: theme.titleAttributes(color: theme.primary)
        )

        let visa = CardBrandIcon(size: .useOtherCardPair)
        visa.setBrand("visa", size: .useOtherCardPair)
        let mc = CardBrandIcon(size: .useOtherCardPair)
        mc.setBrand("mastercard", size: .useOtherCardPair)
        let brands = UIStackView(arrangedSubviews: [visa, mc])
        brands.axis = .horizontal
        brands.spacing = 6

        let row = UIStackView(arrangedSubviews: [tile, title, brands])
        row.axis = .horizontal
        row.spacing = 13
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
            self?.onUseOtherCard?()
        }, for: .touchUpInside)
        return control
    }

    private func makeCollapsedSummaryRow() -> UIControl {
        let control = UIControl()
        let tile = BrandTileView(theme: theme)
        tile.apply(style: .collapsedSummary, theme: theme)

        let title = UILabel()
        title.attributedText = NSAttributedString(
            string: Strings.text("sheet.savedCards", locale: locale),
            attributes: theme.titleAttributes(color: theme.primaryText)
        )

        let subtitle = UILabel()
        subtitle.text = SavedCardFormatting.savedCardsSummarySubtitle(cards)
        subtitle.font = theme.font(ofSize: 13, weight: .medium)
        subtitle.textColor = theme.primaryText.withAlphaComponent(0.45)

        let textStack = UIStackView(arrangedSubviews: [title, subtitle])
        textStack.axis = .vertical
        textStack.spacing = 1

        let chevron = UIImageView()
        chevron.image = EmbeddedAssets.image(named: "chevron-down")?
            .withRenderingMode(.alwaysTemplate)
        chevron.tintColor = theme.primaryText.withAlphaComponent(0.38)
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chevron.widthAnchor.constraint(equalToConstant: 13),
            chevron.heightAnchor.constraint(equalToConstant: 8),
        ])

        let row = UIStackView(arrangedSubviews: [tile, textStack, chevron])
        row.axis = .horizontal
        row.spacing = 13
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
        let tile = BrandTileView(theme: theme)
        tile.apply(style: .addCard, theme: theme)

        let title = UILabel()
        title.attributedText = NSAttributedString(
            string: Strings.text("sheet.useOtherCard", locale: locale),
            attributes: theme.titleAttributes(color: theme.primaryText)
        )

        let subtitle = UILabel()
        subtitle.text = Strings.text("sheet.visaOrMastercard", locale: locale)
        subtitle.font = theme.font(ofSize: 13, weight: .medium)
        subtitle.textColor = theme.primaryText.withAlphaComponent(0.45)

        let textStack = UIStackView(arrangedSubviews: [title, subtitle])
        textStack.axis = .vertical
        textStack.spacing = 1

        let radio = RadioIndicator(theme: theme)
        radio.setSelected(true, theme: theme, animated: false)

        let row = UIStackView(arrangedSubviews: [tile, textStack, radio])
        row.axis = .horizontal
        row.spacing = 13
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return row
    }
}
