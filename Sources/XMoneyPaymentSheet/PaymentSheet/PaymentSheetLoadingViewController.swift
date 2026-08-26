import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
import XMoneyPaymentElement
#endif

final class PaymentSheetLoadingViewController: UIViewController, PaymentSheetHeightProviding {
    private let config: PaymentConfig
    private let loaderSize: CGFloat = 72
    private let contentPadding: CGFloat = 40
    private var loader: XCoinFlipLoaderView?

    var onContentSizeChange: (() -> Void)?

    private var theme: CheckoutTheme {
        CheckoutTheme.resolve(
            config: config,
            isDark: UIHelpers.isDarkMode(config: config, traitCollection: traitCollection)
        )
    }

    init(config: PaymentConfig) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTheme()
        buildLayout()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        onContentSizeChange?()
    }

    var preferredSheetHeight: CGFloat {
        let markHeight = loaderSize * (418.0 / 539.0)
        return ceil(contentPadding + markHeight + contentPadding + view.safeAreaInsets.bottom)
    }

    private func applyTheme() {
        let t = theme
        view.backgroundColor = t.background
        view.layer.cornerRadius = t.sheetCornerRadius
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
    }

    private func buildLayout() {
        let flip = XCoinFlipLoaderView(color: CheckoutTheme.brandPrimary, size: loaderSize)
        flip.translatesAutoresizingMaskIntoConstraints = false
        loader = flip

        view.addSubview(flip)
        NSLayoutConstraint.activate([
            flip.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            flip.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }
}
