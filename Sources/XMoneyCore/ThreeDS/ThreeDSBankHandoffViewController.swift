import UIKit

/// Shown after Safari hands the challenge to a bank app.
///
/// The custom-scheme page cannot load in Safari, and Close on that error page
/// would look like a cancel while the bank app is still approving.
package final class ThreeDSBankHandoffViewController: UIViewController {
    package var onCancel: (() -> Void)?
    private let locale: String

    /// UIKit reads the presentation style when `present` is called, so it is set here, not in `viewDidLoad`.
    /// Full screen and modal: a swipe would close the screen without `onCancel`.
    package init(locale: String) {
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    package override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

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
