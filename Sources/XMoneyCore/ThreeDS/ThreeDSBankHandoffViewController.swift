import UIKit

/// Shown after Safari hands the challenge to a bank app.
///
/// The custom-scheme page cannot load in Safari, and Close on that error page
/// would look like a cancel while the bank app is still approving.
package final class ThreeDSBankHandoffViewController: UIViewController {
    package var onCancel: (() -> Void)?

    package override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationStyle = .fullScreen
        view.backgroundColor = .systemBackground

        let locale = Locale.preferredLanguages.first ?? "en"
        let titleLabel = UILabel()
        titleLabel.text = Strings.text("threeds.bankHandoff.title", locale: locale)
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.text = Strings.text("threeds.bankHandoff.message", locale: locale)
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let cancel = UIButton(type: .system)
        cancel.setTitle(Strings.text("sheet.cancel", locale: locale), for: .normal)
        cancel.titleLabel?.font = .preferredFont(forTextStyle: .body)
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, cancel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    @objc private func cancelTapped() {
        onCancel?()
    }
}
