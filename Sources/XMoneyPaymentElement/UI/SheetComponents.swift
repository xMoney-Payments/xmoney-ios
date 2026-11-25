import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

// MARK: - Grabber

package final class GrabberView: UIView {
    package init(theme: CheckoutTheme) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let pill = UIView()
        pill.backgroundColor = theme.grabber
        pill.layer.cornerRadius = 2
        pill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pill)
        NSLayoutConstraint.activate([
            pill.centerXAnchor.constraint(equalTo: centerXAnchor),
            pill.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            pill.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            pill.widthAnchor.constraint(equalToConstant: 38),
            pill.heightAnchor.constraint(equalToConstant: 4),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Close

package final class CircleCloseButton: UIButton {
    package init(theme: CheckoutTheme, locale: String = "en-US") {
        super.init(frame: .zero)
        let icon = UIImageView(image: EmbeddedAssets.image(named: "close")?.withRenderingMode(.alwaysTemplate))
        icon.tintColor = theme.primaryText
        icon.isUserInteractionEnabled = false
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
        ])
        tintColor = theme.primaryText
        backgroundColor = .clear
        accessibilityLabel = Strings.text("sheet.cancel", locale: locale)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 44),
            heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Or divider

final class OrDividerView: UIView {
    init(theme: CheckoutTheme, label: String) {
        super.init(frame: .zero)
        let left = makeLine(theme: theme)
        let right = makeLine(theme: theme)
        let text = UILabel()
        theme.style(text, text: label, size: 14, weight: .regular, color: theme.orLabel)
        text.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [left, text, right])
        stack.axis = .horizontal
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            left.widthAnchor.constraint(equalTo: right.widthAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func makeLine(theme: CheckoutTheme) -> UIView {
        let line = UIView()
        line.backgroundColor = theme.orDivider
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }
}

// MARK: - Radio

final class RadioIndicator: UIView {
    private let ring = CAShapeLayer()
    private let dot = UIView()

    init(theme: CheckoutTheme) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        ring.fillColor = UIColor.clear.cgColor
        ring.lineWidth = 2
        layer.addSublayer(ring)
        dot.layer.cornerRadius = 7
        dot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dot)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 24),
            heightAnchor.constraint(equalToConstant: 24),
            dot.centerXAnchor.constraint(equalTo: centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 14),
            dot.heightAnchor.constraint(equalToConstant: 14),
        ])
        setSelected(false, theme: theme, animated: false)
    }

    /// Selected state is a 14pt accent dot inside the ring. The indicator itself stays clear.
    package var selectionDotIsVisible: Bool { dot.alpha > 0.5 }
    package var selectionDotColor: UIColor? { dot.backgroundColor }
    package var selectionDotSide: CGFloat { 14 }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        ring.frame = bounds
        let inset = ring.lineWidth / 2
        ring.path = UIBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset)).cgPath
    }

    func setSelected(_ selected: Bool, theme: CheckoutTheme, animated: Bool) {
        let updates = {
            let stroke = (selected ? theme.primary : theme.radioIdle).cgColor
            self.ring.strokeColor = stroke
            self.dot.backgroundColor = theme.primary
            self.dot.alpha = selected ? 1 : 0
        }
        if animated {
            UIView.animate(withDuration: 0.2, animations: updates)
        } else {
            updates()
        }
    }
}

// MARK: - Checkbox

final class CheckboxControl: UIControl {
    private let box = UIView()
    private let checkView = UIImageView()
    private let theme: CheckoutTheme
    private(set) var isChecked = true

    init(theme: CheckoutTheme) {
        self.theme = theme
        super.init(frame: .zero)
        box.layer.cornerRadius = 8
        box.layer.borderWidth = 1.5
        box.isUserInteractionEnabled = false
        box.translatesAutoresizingMaskIntoConstraints = false
        checkView.contentMode = .scaleAspectFit
        checkView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(box)
        box.addSubview(checkView)
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: leadingAnchor),
            box.centerYAnchor.constraint(equalTo: centerYAnchor),
            box.widthAnchor.constraint(equalToConstant: 22),
            box.heightAnchor.constraint(equalToConstant: 22),
            checkView.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            checkView.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            checkView.widthAnchor.constraint(equalToConstant: 12),
            checkView.heightAnchor.constraint(equalToConstant: 9),
            trailingAnchor.constraint(equalTo: box.trailingAnchor),
            topAnchor.constraint(equalTo: box.topAnchor),
            bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])
        addTarget(self, action: #selector(toggle), for: .touchUpInside)
        setChecked(false, animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setChecked(_ checked: Bool, animated: Bool) {
        isChecked = checked
        let updates = {
            if checked {
                self.box.backgroundColor = self.theme.primary
                self.box.layer.borderColor = UIColor.clear.cgColor
                self.checkView.image = EmbeddedAssets.image(named: "check")?
                    .withRenderingMode(.alwaysTemplate)
                self.checkView.tintColor = .white
                self.checkView.alpha = 1
            } else {
                self.box.backgroundColor = .clear
                self.box.layer.borderColor = self.theme.checkboxRing.cgColor
                self.checkView.alpha = 0
            }
        }
        if animated {
            UIView.animate(withDuration: 0.15, animations: updates)
        } else {
            updates()
        }
    }

    @objc private func toggle() {
        setChecked(!isChecked, animated: true)
        sendActions(for: .valueChanged)
    }
}

// MARK: - Brand tile

enum BrandTileStyle {
    case savedCard(brand: String?)
    case addCard
    case collapsedSummary
    case payWithCard
    case crypto
}

final class BrandTileView: UIView {
    private let iconView = UIImageView()
    private var brandIcon: CardBrandIcon?
    private var cryptoGlyph: UILabel?

    init(theme: CheckoutTheme, size: CGSize = CGSize(width: 48, height: 34)) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = theme.brandTileRadius
        clipsToBounds = true
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size.width),
            heightAnchor.constraint(equalToConstant: size.height),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func apply(style: BrandTileStyle, theme: CheckoutTheme) {
        brandIcon?.removeFromSuperview()
        brandIcon = nil
        cryptoGlyph?.removeFromSuperview()
        cryptoGlyph = nil
        iconView.removeFromSuperview()
        layer.shadowOpacity = 0
        layer.borderWidth = 0
        clipsToBounds = true

        switch style {
        case let .savedCard(brand):
            backgroundColor = theme.brandTileBackground
            layer.borderWidth = 1
            layer.borderColor = theme.brandTileBorder.cgColor
            clipsToBounds = false
            layer.shadowColor = UIColor(hex: "#16141A")?.cgColor
            layer.shadowOpacity = 0.04
            layer.shadowOffset = CGSize(width: 0, height: 1)
            layer.shadowRadius = 1
            let icon = CardBrandIcon(size: .savedCardRow)
            icon.setBrand(brand, size: .savedCardRow, visaTint: theme.visaTint)
            brandIcon = icon
            addSubview(icon)
            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
        case .addCard:
            backgroundColor = theme.accentIconBackground
            iconView.image = EmbeddedAssets.image(named: "plus")?
                .withRenderingMode(.alwaysTemplate)
            iconView.tintColor = theme.iconBrand
            iconView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(iconView)
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 14),
                iconView.heightAnchor.constraint(equalToConstant: 14),
            ])
        case .collapsedSummary:
            backgroundColor = theme.accentIconBackground
            addCardIcon(theme: theme)
        case .payWithCard:
            backgroundColor = theme.accentIconBackground
            if !theme.isDark {
                clipsToBounds = false
                layer.shadowColor = UIColor(hex: "#16141A")?.cgColor
                layer.shadowOpacity = 0.04
                layer.shadowOffset = CGSize(width: 0, height: 1)
                layer.shadowRadius = 1
            }
            addCardIcon(theme: theme)
        case .crypto:
            backgroundColor = theme.accentIconBackground
            let glyph = UILabel()
            glyph.text = "₿"
            glyph.font = theme.font(ofSize: 18, weight: .bold)
            glyph.textColor = theme.iconBrand
            glyph.translatesAutoresizingMaskIntoConstraints = false
            addSubview(glyph)
            cryptoGlyph = glyph
            NSLayoutConstraint.activate([
                glyph.centerXAnchor.constraint(equalTo: centerXAnchor),
                glyph.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
        }
    }

    private func addCardIcon(theme: CheckoutTheme) {
        iconView.image = EmbeddedAssets.image(named: "card-generic")?
            .withRenderingMode(.alwaysTemplate)
        iconView.tintColor = theme.iconBrand
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
        ])
    }
}

// MARK: - Error row

final class ErrorRowView: UIView {
    private let label = UILabel()
    private let theme: CheckoutTheme
    private let messageSize: CGFloat

    init(
        message: String,
        theme: CheckoutTheme,
        topInset: CGFloat = 8,
        leadingInset: CGFloat = 2,
        badgeWeight: UIFont.Weight = .medium,
        messageSize: CGFloat = 12
    ) {
        self.theme = theme
        self.messageSize = messageSize
        super.init(frame: .zero)
        let badge = UILabel()
        badge.text = "!"
        badge.font = theme.font(ofSize: 10, weight: badgeWeight)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.backgroundColor = theme.errorBadge
        badge.layer.cornerRadius = 7.5
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 15),
            badge.heightAnchor.constraint(equalToConstant: 15),
        ])

        setMessage(message)

        let stack = UIStackView(arrangedSubviews: [badge, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: topInset),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingInset),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -leadingInset),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func setMessage(_ message: String) {
        theme.style(
            label,
            text: message,
            size: messageSize,
            weight: .semibold,
            color: theme.errorText,
            multiline: true
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Powered by footer

final class PoweredByFooterView: UIView {
    private let label = UILabel()
    private let logo = UIImageView()

    init(theme: CheckoutTheme, locale: String) {
        super.init(frame: .zero)
        logo.image = EmbeddedAssets.image(named: "xmoney-wordmark")?
            .withRenderingMode(.alwaysTemplate)
        logo.contentMode = .scaleAspectFit
        logo.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logo.heightAnchor.constraint(equalToConstant: 14),
            logo.widthAnchor.constraint(equalToConstant: 56),
        ])

        let stack = UIStackView(arrangedSubviews: [label, logo])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .bottom
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        apply(theme: theme, locale: locale)
    }

    func apply(theme: CheckoutTheme, locale: String) {
        theme.style(
            label,
            text: Strings.text("sheet.poweredBy", locale: locale),
            size: 12,
            weight: .medium,
            color: theme.poweredByText
        )
        logo.tintColor = theme.poweredByLogo
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
