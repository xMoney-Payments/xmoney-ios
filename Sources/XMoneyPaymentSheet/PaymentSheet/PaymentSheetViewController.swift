import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
import XMoneyPaymentElement
#endif

package protocol PaymentSheetViewControllerDelegate: AnyObject {
    func sheetDidTapPayWithCard(_ input: CardInput, customerDetails: CustomerDetails?)
    func sheetDidSelectSavedCard(_ card: SavedCard, customerDetails: CustomerDetails?)
    func sheetDidTapApplePay()
    func sheetDidTapPersonalDetails()
    func sheetDidTapDeleteSavedCard(_ card: SavedCard) async throws
    func sheetDidCancel()
}

package final class PaymentSheetViewController: UIViewController, PaymentSheetHeightProviding {
    package weak var delegate: PaymentSheetViewControllerDelegate?

    private let config: PaymentConfig
    private var state: SheetState
    private let chromeStack = UIStackView()
    private let scrollView = UIScrollView()
    private var headerRow: UIView!
    private var formView: PaymentFormView!
    private var personalDetails: PersonalDetailsViewController?
    private var closeButton: UIButton!
    private var lastReportedHeight: CGFloat = 0
    private var isInvalidatingHeight = false
    private var keyboardObservers: [NSObjectProtocol] = []

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
        observeKeyboardForScrolling()
    }

    deinit {
        keyboardObservers.forEach(NotificationCenter.default.removeObserver)
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

    package var customerDetailsVisibility: CustomerDetailsVisibility { state.customerDetailsVisibility }

    package var personalDetailsProgress: PersonalDetailsProgress { state.personalDetails }

    package var isShowingPersonalDetails: Bool { personalDetails != nil }

    package func showPersonalDetails(_ details: PersonalDetailsViewController) {
        view.endEditing(true)
        guard personalDetails == nil else { return }
        addChild(details)
        details.view.translatesAutoresizingMaskIntoConstraints = false
        chromeStack.addArrangedSubview(details.view)
        details.didMove(toParent: self)
        headerRow.isHidden = true
        scrollView.isHidden = true
        personalDetails = details
        details.onContentSizeChange = { [weak self] in
            self?.invalidateSheetHeight()
        }
        // Lay the page out in the sheet so its safe-area inset is part of the height
        // before the sheet resizes. Otherwise a short form opens a bit too small and scrolls.
        view.layoutIfNeeded()
        invalidateSheetHeight()
    }

    package func hidePersonalDetails(refreshRow: Bool = false) {
        guard let details = personalDetails else { return }
        view.endEditing(true)
        details.willMove(toParent: nil)
        chromeStack.removeArrangedSubview(details.view)
        details.view.removeFromSuperview()
        details.removeFromParent()
        personalDetails = nil
        headerRow.isHidden = false
        scrollView.isHidden = false
        if refreshRow {
            formView?.refreshPersonalDetailsRow()
        }
        invalidateSheetHeight()
    }

    package func update(state: SheetState) {
        self.state = state
        formView?.update(state: state)
        invalidateSheetHeight()
    }

    package var preferredSheetHeight: CGFloat {
        if let personalDetails {
            // Grabber 16 (10+4+2) + 6 gap. The details view fills the rest.
            return ceil(16 + 6 + personalDetails.contentHeight)
        }
        // Grabber 16 (10+4+2) + 6 gap + 36 close row.
        let headerChrome: CGFloat = 16 + 6 + 36
        return ceil(headerChrome + (formView?.contentHeight ?? 280))
    }

    /// Card form and Apple Pay button (when offered) have drawn under the loading cover.
    package func waitUntilSurfaceDrawn() async {
        loadViewIfNeeded()
        view.layoutIfNeeded()
        await formView.waitUntilSurfaceDrawn()
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

        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        headerRow = header
        header.addSubview(close)
        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 36),
            close.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            close.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])

        formView = PaymentFormView(config: config, state: state, contentInsets: .sheet)
        formView.onPayCard = { [weak self] input, details in
            self?.delegate?.sheetDidTapPayWithCard(input, customerDetails: details)
        }
        formView.onSelectSaved = { [weak self] card, details in
            self?.delegate?.sheetDidSelectSavedCard(card, customerDetails: details)
        }
        formView.onOpenPersonalDetails = { [weak self] in
            self?.delegate?.sheetDidTapPersonalDetails()
        }
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
        chromeStack.addArrangedSubview(header)
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

    private func observeKeyboardForScrolling() {
        let center = NotificationCenter.default
        keyboardObservers = [
            center.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                self?.scheduleFieldScroll(note)
            },
            center.addObserver(
                forName: UITextField.textDidBeginEditingNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let self,
                      let field = note.object as? UIView,
                      field.isDescendant(of: self.view) else { return }
                self.scrollFocusedField(animated: true)
            },
        ]
    }

    private func scheduleFieldScroll(_ note: Notification) {
        let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        let hiding: Bool
        if let end, let window = view.window {
            let frame = window.convert(end, from: window.screen.coordinateSpace)
            hiding = frame.minY >= window.bounds.maxY - 1
        } else {
            hiding = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else { return }
            if hiding {
                self.scrollView.setContentOffset(.zero, animated: true)
            } else {
                self.scrollFocusedField(animated: true)
            }
        }
    }

    private func scrollFocusedField(animated: Bool) {
        view.layoutIfNeeded()
        let overflows = scrollView.contentSize.height > scrollView.bounds.height + 1
        scrollView.isScrollEnabled = overflows
        scrollView.bounces = overflows
        scrollView.alwaysBounceVertical = overflows
        guard overflows, let field = view.deepestFirstResponder else { return }
        let rect = field.convert(field.bounds, to: scrollView).insetBy(dx: 0, dy: -20)
        scrollView.scrollRectToVisible(rect, animated: animated)
    }
}

private extension UIView {
    var deepestFirstResponder: UIView? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let found = subview.deepestFirstResponder { return found }
        }
        return nil
    }
}
