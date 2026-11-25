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
    private let stepDone = UIImageView()
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
                color: completed ? theme.primaryText : theme.textBrand,
                lineBreakMode: .byWordWrapping
            )
        )
        button.layer.borderWidth = showError ? 1 : 0
        button.layer.borderColor = theme.errorBorder.cgColor
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
        button.layer.cornerRadius = theme.containerRadius
        button.layer.borderWidth = 0
        button.layer.borderColor = theme.errorBorder.cgColor
        button.addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)

        plusTile.apply(style: .addCard, theme: theme)

        personTile.backgroundColor = theme.accentIconBackground
        personTile.layer.cornerRadius = theme.brandTileRadius
        personTile.translatesAutoresizingMaskIntoConstraints = false
        personTile.isUserInteractionEnabled = false
        NSLayoutConstraint.activate([
            personTile.widthAnchor.constraint(equalToConstant: 48),
            personTile.heightAnchor.constraint(equalToConstant: 34),
        ])
        stepDone.image = EmbeddedAssets.image(named: "step-done")?.withRenderingMode(.alwaysTemplate)
        stepDone.tintColor = theme.primary
        stepDone.contentMode = .scaleAspectFit
        stepDone.translatesAutoresizingMaskIntoConstraints = false
        personTile.addSubview(stepDone)
        NSLayoutConstraint.activate([
            stepDone.centerXAnchor.constraint(equalTo: personTile.centerXAnchor),
            stepDone.centerYAnchor.constraint(equalTo: personTile.centerYAnchor),
            stepDone.widthAnchor.constraint(equalToConstant: 24),
            stepDone.heightAnchor.constraint(equalToConstant: 24),
        ])

        titleLabel.numberOfLines = 2
        titleLabel.isAccessibilityElement = false
        chevron.isAccessibilityElement = false
        chevron.image = EmbeddedAssets.image(named: "chevron-down")?.withRenderingMode(.alwaysTemplate)
        chevron.tintColor = theme.iconBrand
        chevron.contentMode = .scaleAspectFit
        chevron.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        let chevronBox = UIView()
        chevronBox.isUserInteractionEnabled = false
        chevronBox.translatesAutoresizingMaskIntoConstraints = false
        chevronBox.addSubview(chevron)
        NSLayoutConstraint.activate([
            chevronBox.widthAnchor.constraint(equalToConstant: 16),
            chevronBox.heightAnchor.constraint(equalToConstant: 16),
            chevron.widthAnchor.constraint(equalToConstant: 13),
            chevron.heightAnchor.constraint(equalToConstant: 8),
            chevron.centerXAnchor.constraint(equalTo: chevronBox.centerXAnchor),
            chevron.centerYAnchor.constraint(equalTo: chevronBox.centerYAnchor),
        ])

        let row = UIStackView(arrangedSubviews: [plusTile, personTile, titleLabel, chevronBox])
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
            topInset: 8,
            leadingInset: 2,
            badgeWeight: .medium,
            messageSize: 12
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
