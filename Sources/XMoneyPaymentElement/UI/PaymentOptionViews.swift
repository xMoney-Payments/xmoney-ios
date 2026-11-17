import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

/// Tile, title, subtitle and radio. Shared by the "Pay with card" and "Pay with crypto" options.
final class PaymentOptionRow: UIControl {
    private let radio: RadioIndicator
    private let theme: CheckoutTheme

    init(theme: CheckoutTheme, tile: BrandTileStyle, title: String, subtitle: String) {
        self.theme = theme
        radio = RadioIndicator(theme: theme)
        super.init(frame: .zero)

        let tileView = BrandTileView(theme: theme)
        tileView.apply(style: tile, theme: theme)

        let titleLabel = UILabel()
        theme.style(titleLabel, text: title, size: 16, weight: .bold, color: theme.primaryText)
        let subtitleLabel = UILabel()
        theme.style(subtitleLabel, text: subtitle, size: 14, weight: .medium, color: theme.metaText)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 0

        let row = UIStackView(arrangedSubviews: [tileView, textStack, radio])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
        accessibilityTraits = .button
        accessibilityLabel = "\(title), \(subtitle)"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setSelected(_ selected: Bool) {
        radio.setSelected(selected, theme: theme, animated: false)
        accessibilityTraits = selected ? [.button, .selected] : .button
    }
}

/// White method card with a 6pt inset. The selected option inside it gets the tinted 12pt panel.
class PaymentOptionPanel: UIView {
    let theme: CheckoutTheme
    let row: PaymentOptionRow
    let block = UIView()
    let blockStack = UIStackView()
    var onSelect: (() -> Void)?
    /// Sits below the tinted panel, on the card's white fill, with a 6pt gap.
    private let insetStack = UIStackView()
    private var footerView: UIView?

    init(theme: CheckoutTheme, row: PaymentOptionRow) {
        self.theme = theme
        self.row = row
        super.init(frame: .zero)
        backgroundColor = theme.componentBackground
        layer.cornerRadius = theme.containerRadius
        layer.borderColor = theme.containerBorder.cgColor
        layer.borderWidth = theme.containerBorderWidth

        insetStack.axis = .vertical
        insetStack.spacing = 6
        insetStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(insetStack)

        block.layer.cornerRadius = 12
        block.clipsToBounds = true
        block.translatesAutoresizingMaskIntoConstraints = false
        insetStack.addArrangedSubview(block)

        blockStack.axis = .vertical
        blockStack.spacing = 0
        blockStack.translatesAutoresizingMaskIntoConstraints = false
        block.addSubview(blockStack)
        blockStack.addArrangedSubview(row)

        NSLayoutConstraint.activate([
            insetStack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            insetStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            insetStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            insetStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            blockStack.topAnchor.constraint(equalTo: block.topAnchor),
            blockStack.leadingAnchor.constraint(equalTo: block.leadingAnchor),
            blockStack.trailingAnchor.constraint(equalTo: block.trailingAnchor),
            blockStack.bottomAnchor.constraint(equalTo: block.bottomAnchor),
        ])
        row.addAction(UIAction { [weak self] _ in self?.onSelect?() }, for: .touchUpInside)
    }

    /// Content that stays on the white card, under the tinted selection panel.
    func setFooter(_ footer: UIView) {
        footerView?.removeFromSuperview()
        footerView = footer
        footer.isHidden = true
        insetStack.addArrangedSubview(footer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func applySelected(_ selected: Bool) {
        row.setSelected(selected)
        block.backgroundColor = selected ? theme.selectedBackground : .clear
        footerView?.isHidden = !selected
    }
}

/// "Pay with card" option for checkouts without saved cards; hosts the card form while selected.
final class PayWithCardPanelView: PaymentOptionPanel {
    private let formWrapper = UIView()

    init(theme: CheckoutTheme, locale: String, form: CardFormView) {
        let row = PaymentOptionRow(
            theme: theme,
            tile: .payWithCard,
            title: Strings.text("sheet.payWithCard", locale: locale),
            subtitle: Strings.text("sheet.visaOrMastercard", locale: locale)
        )
        super.init(theme: theme, row: row)
        form.removeFromSuperview()
        form.translatesAutoresizingMaskIntoConstraints = false
        formWrapper.addSubview(form)
        NSLayoutConstraint.activate([
            form.topAnchor.constraint(equalTo: formWrapper.topAnchor, constant: 16),
            form.leadingAnchor.constraint(equalTo: formWrapper.leadingAnchor, constant: 12),
            form.trailingAnchor.constraint(equalTo: formWrapper.trailingAnchor, constant: -12),
            form.bottomAnchor.constraint(equalTo: formWrapper.bottomAnchor),
        ])
        blockStack.addArrangedSubview(formWrapper)
    }

    override func applySelected(_ selected: Bool) {
        super.applySelected(selected)
        formWrapper.isHidden = !selected
    }
}

/// "Pay with crypto" option. UI preview only; selecting it shows the redirect notice.
final class CryptoOptionPanel: PaymentOptionPanel {
    private let notice = UIView()

    init(theme: CheckoutTheme, locale: String) {
        let row = PaymentOptionRow(
            theme: theme,
            tile: .crypto,
            title: Strings.text("sheet.payWithCrypto", locale: locale),
            subtitle: Strings.text("sheet.cryptoSubtitle", locale: locale)
        )
        super.init(theme: theme, row: row)

        let label = UILabel()
        theme.style(
            label,
            text: Strings.text("sheet.cryptoRedirectNotice", locale: locale),
            size: 14,
            weight: .medium,
            color: theme.metaText,
            multiline: true,
            lineHeight: 20
        )
        label.translatesAutoresizingMaskIntoConstraints = false
        notice.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: notice.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: notice.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: notice.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: notice.bottomAnchor, constant: -10),
        ])
        setFooter(notice)
    }
}
