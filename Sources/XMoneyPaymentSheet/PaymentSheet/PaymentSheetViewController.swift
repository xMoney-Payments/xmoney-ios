import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
import XMoneyPaymentElement
#endif

package protocol PaymentSheetViewControllerDelegate: AnyObject {
    func sheetDidTapPayWithCard(_ input: CardInput)
    func sheetDidSelectSavedCard(_ card: SavedCard)
    func sheetDidTapApplePay()
    func sheetDidTapDeleteSavedCard(_ card: SavedCard) async throws
    func sheetDidCancel()
}

package final class PaymentSheetViewController: UIViewController, PaymentSheetHeightProviding {
    package weak var delegate: PaymentSheetViewControllerDelegate?

    private let config: PaymentConfig
    private var state: SheetState
    private let chromeStack = UIStackView()
    private let scrollView = UIScrollView()
    private var formView: PaymentFormView!
    private var closeButton: UIButton!
    private var lastReportedHeight: CGFloat = 0
    private var isInvalidatingHeight = false

    package var onContentSizeChange: (() -> Void)?

    private var theme: CheckoutTheme {
        CheckoutTheme.resolve(
            config: config,
            isDark: UIHelpers.isDarkMode(config: config, traitCollection: traitCollection)
        )
    }

    package init(config: PaymentConfig, state: SheetState) {
        self.config = config
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    package override func viewDidLoad() {
        super.viewDidLoad()
        applyTheme()
        buildLayout()
    }

    package override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyTheme()
        }
    }

    package func setProcessing(_ processing: Bool) {
        formView.setProcessing(processing)
        closeButton?.isEnabled = !processing
        closeButton?.alpha = processing ? 0.4 : 1
        isModalInPresentation = processing
        navigationController?.isModalInPresentation = processing
    }

    package func update(state: SheetState) {
        self.state = state
        formView?.update(state: state)
        invalidateSheetHeight()
    }

    package var preferredSheetHeight: CGFloat {
        // Grabber 16 (10+4+2) + 6 gap + 36 close row.
        let headerChrome: CGFloat = 16 + 6 + 36
        return ceil(headerChrome + (formView?.contentHeight ?? 280))
    }

    package func invalidateSheetHeight() {
        guard !isInvalidatingHeight else { return }
        isInvalidatingHeight = true
        defer { isInvalidatingHeight = false }

        let height = preferredSheetHeight
        guard abs(height - lastReportedHeight) > 1 else { return }
        lastReportedHeight = height
        onContentSizeChange?()
    }

    private func applyTheme() {
        let t = theme
        view.backgroundColor = t.background
        view.layer.cornerRadius = t.sheetCornerRadius
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
    }

    private func buildLayout() {
        let t = theme

        let grabber = GrabberView(theme: t)

        let close = CircleCloseButton(theme: t, locale: config.options.locale)
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton = close

        let headerRow = UIView()
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addSubview(close)
        NSLayoutConstraint.activate([
            headerRow.heightAnchor.constraint(equalToConstant: 36),
            close.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor, constant: 20),
            close.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
        ])

        formView = PaymentFormView(config: config, state: state, contentInsets: .sheet)
        formView.onPayCard = { [weak self] input in self?.delegate?.sheetDidTapPayWithCard(input) }
        formView.onSelectSaved = { [weak self] card in self?.delegate?.sheetDidSelectSavedCard(card) }
        formView.onDeleteSaved = { [weak self] card in
            try await self?.delegate?.sheetDidTapDeleteSavedCard(card)
        }
        formView.onApplePay = { [weak self] in self?.delegate?.sheetDidTapApplePay() }
        formView.onContentSizeChange = { [weak self] in
            self?.invalidateSheetHeight()
        }

        scrollView.alwaysBounceVertical = false
        scrollView.bounces = false
        scrollView.isScrollEnabled = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.addSubview(formView)
        formView.translatesAutoresizingMaskIntoConstraints = false
        // Form owns the 22pt horizontal inset — do not add a second margin here.
        NSLayoutConstraint.activate([
            formView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            formView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            formView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            formView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            formView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        chromeStack.axis = .vertical
        chromeStack.spacing = 0
        chromeStack.addArrangedSubview(grabber)
        chromeStack.setCustomSpacing(6, after: grabber)
        chromeStack.addArrangedSubview(headerRow)
        chromeStack.addArrangedSubview(scrollView)
        chromeStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chromeStack)
        NSLayoutConstraint.activate([
            chromeStack.topAnchor.constraint(equalTo: view.topAnchor),
            chromeStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chromeStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chromeStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    package override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        formView?.applyBottomSafeArea(view.safeAreaInsets.bottom)
        // Only allow the outer sheet to scroll when content actually overflows;
        // otherwise it steals pans from the nested saved-cards list.
        let contentH = scrollView.contentSize.height
        let frameH = scrollView.bounds.height
        let overflows = contentH > frameH + 1
        scrollView.isScrollEnabled = overflows
        scrollView.bounces = overflows
        scrollView.alwaysBounceVertical = overflows

        guard !isInvalidatingHeight else { return }
        // Prefer cached content height; avoid nested systemLayoutSizeFitting mid-layout.
        let height = preferredSheetHeight
        guard abs(height - lastReportedHeight) > 1 else { return }
        lastReportedHeight = height
        // Defer detent updates off the layout pass.
        DispatchQueue.main.async { [weak self] in
            self?.onContentSizeChange?()
        }
    }

    @objc private func closeTapped() {
        delegate?.sheetDidCancel()
    }
}
