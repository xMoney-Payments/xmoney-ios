import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

// MARK: - Grabber

final class GrabberView: UIView {
    init(theme: CheckoutTheme) {
        super.init(frame: .zero)
        let pill = UIView()
        pill.backgroundColor = theme.primaryText.withAlphaComponent(0.12)
        pill.layer.cornerRadius = 2
        pill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pill)
        NSLayoutConstraint.activate([
            pill.centerXAnchor.constraint(equalTo: centerXAnchor),
            pill.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            pill.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            pill.widthAnchor.constraint(equalToConstant: 38),
            pill.heightAnchor.constraint(equalToConstant: 4),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Close

final class CircleCloseButton: UIButton {
    init(theme: CheckoutTheme) {
        super.init(frame: .zero)
        setTitle("✕", for: .normal)
        setTitleColor(theme.primaryText, for: .normal)
        titleLabel?.font = theme.font(ofSize: 14, weight: .medium)
        backgroundColor = theme.neutralChip
        layer.cornerRadius = 18
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 36),
            heightAnchor.constraint(equalToConstant: 36),
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
        text.text = label
        text.font = theme.font(ofSize: 13, weight: .medium)
        text.textColor = theme.primaryText.withAlphaComponent(0.4)
        text.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [left, text, right])
        stack.axis = .horizontal
        stack.spacing = 14
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
        line.backgroundColor = theme.footerBorder
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }
}

// MARK: - Radio

final class RadioIndicator: UIView {
    private let checkView = UIImageView()

    init(theme: CheckoutTheme) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 10.5
        layer.borderWidth = 1.5
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 21),
            heightAnchor.constraint(equalToConstant: 21),
        ])
        checkView.contentMode = .scaleAspectFit
        checkView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkView)
        NSLayoutConstraint.activate([
            checkView.centerXAnchor.constraint(equalTo: centerXAnchor),
            checkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkView.widthAnchor.constraint(equalToConstant: 10),
            checkView.heightAnchor.constraint(equalToConstant: 8),
        ])
        setSelected(false, theme: theme, animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setSelected(_ selected: Bool, theme: CheckoutTheme, animated: Bool) {
        let updates = {
            if selected {
                self.backgroundColor = theme.primary
                self.layer.borderColor = UIColor.clear.cgColor
                self.checkView.image = EmbeddedAssets.image(named: "check")?
                    .withRenderingMode(.alwaysTemplate)
                self.checkView.tintColor = .white
                self.checkView.alpha = 1
            } else {
                self.backgroundColor = .clear
                self.layer.borderColor = theme.unselectedRing.cgColor
                self.checkView.alpha = 0
            }
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
        box.layer.cornerRadius = 7
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
                self.box.layer.borderColor = self.theme.unselectedRing.cgColor
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
}

final class BrandTileView: UIView {
    private let iconView = UIImageView()
    private var brandIcon: CardBrandIcon?

    init(theme: CheckoutTheme) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = theme.brandTileRadius
        clipsToBounds = true
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 44),
            heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func apply(style: BrandTileStyle, theme: CheckoutTheme) {
        brandIcon?.removeFromSuperview()
        brandIcon = nil
        iconView.removeFromSuperview()
        layer.shadowOpacity = 0
        layer.borderWidth = 0

        switch style {
        case let .savedCard(brand):
            backgroundColor = theme.componentBackground
            layer.borderWidth = theme.containerBorderWidth
            layer.borderColor = theme.containerBorder.cgColor
            let icon = CardBrandIcon(size: .savedCardRow)
            icon.setBrand(brand, size: .savedCardRow)
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
            iconView.tintColor = theme.primary
            iconView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(iconView)
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 14),
                iconView.heightAnchor.constraint(equalToConstant: 14),
            ])
        case .collapsedSummary:
            backgroundColor = theme.neutralChip
            iconView.image = EmbeddedAssets.image(named: "card-stack")?
                .withRenderingMode(.alwaysTemplate)
            iconView.tintColor = theme.primaryText.withAlphaComponent(0.5)
            iconView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(iconView)
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 18),
                iconView.heightAnchor.constraint(equalToConstant: 18),
            ])
        }
    }
}

// MARK: - Error row

final class ErrorRowView: UIView {
    init(message: String, theme: CheckoutTheme) {
        super.init(frame: .zero)
        let badge = UILabel()
        badge.text = "!"
        badge.font = theme.font(ofSize: 10, weight: .bold)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.backgroundColor = theme.errorText
        badge.layer.cornerRadius = 7.5
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 15),
            badge.heightAnchor.constraint(equalToConstant: 15),
        ])

        let label = UILabel()
        label.text = message
        label.font = theme.font(ofSize: 12.5, weight: .semibold)
        label.textColor = theme.errorText
        label.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [badge, label])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Powered by footer

final class PoweredByFooterView: UIView {
    init(theme: CheckoutTheme, locale: String) {
        super.init(frame: .zero)
        let label = UILabel()
        label.text = Strings.text("sheet.poweredBy", locale: locale)
        label.font = theme.font(ofSize: 12, weight: .medium)
        label.textColor = theme.secondaryText.withAlphaComponent(0.3)

        let logo = UIImageView()
        logo.image = EmbeddedAssets.image(named: "xmoney-wordmark")?
            .withRenderingMode(.alwaysTemplate)
        logo.tintColor = theme.secondaryText.withAlphaComponent(0.42)
        logo.contentMode = .scaleAspectFit
        logo.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logo.heightAnchor.constraint(equalToConstant: 13),
            logo.widthAnchor.constraint(equalToConstant: 52),
        ])

        let stack = UIStackView(arrangedSubviews: [label, logo])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
