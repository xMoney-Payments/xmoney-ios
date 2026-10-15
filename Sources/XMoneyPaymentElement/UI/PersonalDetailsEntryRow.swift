import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

package final class PersonalDetailsEntryRow: UIView {
    package var onTap: (() -> Void)?

    private let theme: CheckoutTheme
    private let locale: String
    private let button = UIControl()
    private let titleLabel = UILabel()
    private let chevron = UIImageView()
    private let plusTile: BrandTileView
    private let personTile = UIView()
    private let personIcon = UIImageView()
    private let badge = UIImageView()
    private let errorRow = UIView()

    package init(theme: CheckoutTheme, locale: String) {
        self.theme = theme
        self.locale = locale
        self.plusTile = BrandTileView(theme: theme, size: CGSize(width: 48, height: 34))
        super.init(frame: .zero)
        build(theme: theme)
        apply(completed: false, showsError: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    package func apply(completed: Bool, showsError: Bool) {
        let showError = showsError && !completed
        plusTile.isHidden = completed
        personTile.isHidden = !completed
        let title = Strings.text(
            completed ? "personalDetails.detailsCompleted" : "personalDetails.enterDetails",
            locale: locale
        )
        titleLabel.attributedText = NSAttributedString(
            string: title,
            attributes: theme.titleAttributes(
                size: 16,
                weight: .bold,
                color: completed ? theme.primaryText : theme.primary
            )
        )
        button.layer.borderWidth = 1
        button.layer.borderColor = (showError ? theme.errorBorder : theme.containerBorder).cgColor
        button.isAccessibilityElement = true
        button.accessibilityTraits = .button
        button.accessibilityLabel = title
        button.accessibilityHint = showError
            ? Strings.text("personalDetails.completeDetails", locale: locale)
            : nil
        errorRow.isHidden = !showError
    }

    private func build(theme: CheckoutTheme) {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        button.backgroundColor = theme.componentBackground
        button.layer.cornerRadius = theme.paymentContainerRadius
        button.layer.borderWidth = 1
        button.layer.borderColor = theme.containerBorder.cgColor
        button.addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)

        plusTile.apply(style: .addCard, theme: theme)

        personTile.backgroundColor = theme.neutralChip
        personTile.layer.cornerRadius = theme.brandTileRadius
        personTile.translatesAutoresizingMaskIntoConstraints = false
        personTile.isUserInteractionEnabled = false
        NSLayoutConstraint.activate([
            personTile.widthAnchor.constraint(equalToConstant: 48),
            personTile.heightAnchor.constraint(equalToConstant: 34),
        ])
        personIcon.image = EmbeddedAssets.image(named: "person")?.withRenderingMode(.alwaysTemplate)
        personIcon.tintColor = theme.mutedIcon
        personIcon.translatesAutoresizingMaskIntoConstraints = false
        personTile.addSubview(personIcon)
        badge.backgroundColor = theme.primary
        badge.layer.cornerRadius = 11
        badge.layer.borderWidth = 1
        badge.layer.borderColor = theme.componentBackground.cgColor
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        let check = UIImageView(image: EmbeddedAssets.image(named: "check")?.withRenderingMode(.alwaysTemplate))
        check.tintColor = theme.primaryButtonText
        check.contentMode = .scaleAspectFit
        check.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(check)
        personTile.addSubview(badge)
        NSLayoutConstraint.activate([
            personIcon.centerXAnchor.constraint(equalTo: personTile.centerXAnchor),
            personIcon.centerYAnchor.constraint(equalTo: personTile.centerYAnchor),
            personIcon.widthAnchor.constraint(equalToConstant: 16),
            personIcon.heightAnchor.constraint(equalToConstant: 16),
            badge.widthAnchor.constraint(equalToConstant: 22),
            badge.heightAnchor.constraint(equalToConstant: 22),
            badge.trailingAnchor.constraint(equalTo: personTile.trailingAnchor, constant: 4),
            badge.bottomAnchor.constraint(equalTo: personTile.bottomAnchor, constant: 4),
            check.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            check.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            check.widthAnchor.constraint(equalToConstant: 10),
            check.heightAnchor.constraint(equalToConstant: 8),
        ])

        titleLabel.numberOfLines = 2
        titleLabel.isAccessibilityElement = false
        chevron.isAccessibilityElement = false
        chevron.image = EmbeddedAssets.image(named: "chevron-right")?.withRenderingMode(.alwaysTemplate)
        chevron.tintColor = theme.primary
        chevron.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chevron.widthAnchor.constraint(equalToConstant: 8),
            chevron.heightAnchor.constraint(equalToConstant: 12),
        ])

        let row = UIStackView(arrangedSubviews: [plusTile, personTile, titleLabel, chevron])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: button.topAnchor, constant: 18),
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -18),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -18),
        ])

        let message = ErrorRowView(
            message: Strings.text("personalDetails.completeDetails", locale: locale),
            theme: theme,
            topInset: 4
        )
        errorRow.addSubview(message)
        message.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            message.topAnchor.constraint(equalTo: errorRow.topAnchor),
            message.leadingAnchor.constraint(equalTo: errorRow.leadingAnchor),
            message.trailingAnchor.constraint(equalTo: errorRow.trailingAnchor),
            message.bottomAnchor.constraint(equalTo: errorRow.bottomAnchor),
        ])

        stack.addArrangedSubview(button)
        stack.addArrangedSubview(errorRow)
    }
}
