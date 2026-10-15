import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

package enum PersonalDetailsPresentation {
    /// Scrolls inside the payment sheet when the form is taller than the sheet.
    case sheet
    /// Fills the host and lets the merchant page scroll. No nested scroll view.
    case inline
}

package final class PersonalDetailsViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    package var onCommit: ((PersonalDetailsValues) -> Void)?
    package var onBack: ((PersonalDetailsValues) -> Void)?
    package var onContentSizeChange: (() -> Void)?
    package var showsFooterHairline = false

    private let config: PaymentConfig
    private let visibility: CustomerDetailsVisibility
    private let initialValues: PersonalDetailsValues
    private let presentation: PersonalDetailsPresentation
    private var form: PersonalDetailsFormView!
    private let continueButton = PayCTAButton()
    private let header = UIView()
    private let footer = UIView()
    private var contentStack: UIStackView!
    private var scrollView: UIScrollView?
    private var installedConstraints: [NSLayoutConstraint] = []
    private var picker: SelectionListViewController?
    private var pickerField: PersonalDetailsField?
    private var measuredHeight: CGFloat = 560
    private var preparedSafeBottom: CGFloat = 0
    private var lastMeasuredWidth: CGFloat = 0
    private var lastMeasuredSafeBottom: CGFloat = -1
    private var contentSizeNotifyScheduled = false
    private weak var focusedFieldView: UIView?
    private var keyboardObserver: NSObjectProtocol?
    /// Screen coordinates of the last keyboard frame. Nil until the keyboard has moved.
    private var lastKeyboardFrame: CGRect?

    package init(
        config: PaymentConfig,
        visibility: CustomerDetailsVisibility,
        initialValues: PersonalDetailsValues,
        presentation: PersonalDetailsPresentation = .sheet
    ) {
        self.config = config
        self.visibility = visibility
        self.initialValues = initialValues
        self.presentation = presentation
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let keyboardObserver {
            NotificationCenter.default.removeObserver(keyboardObserver)
        }
    }

    package var contentHeight: CGFloat { measuredHeight }

    /// Validates the open page and commits it, the same checks Continue runs.
    /// Returns false when a field is invalid so the page stays open.
    package func commitIfValid() -> Bool {
        loadViewIfNeeded()
        guard form.validateAndShowErrors() else {
            remeasure(notify: true)
            return false
        }
        onCommit?(form.currentValues())
        return true
    }

    package func currentValues() -> PersonalDetailsValues {
        form?.currentValues() ?? initialValues
    }

    /// Lays the form out at the sheet width so `contentHeight` is ready before the first frame.
    package func prepareForPresentation(width: CGFloat, safeAreaBottom: CGFloat) {
        preparedSafeBottom = safeAreaBottom
        loadViewIfNeeded()
        view.bounds.size.width = max(width, 1)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        remeasure(notify: false)
    }

    package override func viewDidLoad() {
        super.viewDidLoad()
        let theme = resolvedTheme()
        applyPageBackground(theme)
        form = makeForm(values: initialValues, theme: theme)
        wireForm()
        build(theme: theme)
        observeKeyboard()
        continueButton.onTap = { [weak self] in
            guard let self else { return }
            guard self.form.validateAndShowErrors() else {
                self.remeasure(notify: true)
                return
            }
            self.onCommit?(self.form.currentValues())
        }
    }

    package override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The home-indicator inset is often still 0 before this page is in the sheet.
        // Measuring again here keeps the sheet tall enough that a short form does not scroll.
        updateMeasuredHeightForSafeArea()
        updateScrollability()
    }

    private func updateMeasuredHeightForSafeArea() {
        guard presentation == .sheet, view.window != nil, view.bounds.width > 1 else { return }
        let safe = view.safeAreaInsets.bottom
        let width = view.bounds.width
        guard abs(safe - lastMeasuredSafeBottom) > 0.5 || abs(width - lastMeasuredWidth) > 0.5 else { return }
        lastMeasuredSafeBottom = safe
        lastMeasuredWidth = width
        remeasure(notify: true)
    }

    package override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        rebuildForAppearanceChange()
    }

    private func makeForm(values: PersonalDetailsValues, theme: CheckoutTheme) -> PersonalDetailsFormView {
        PersonalDetailsFormView(
            theme: theme,
            visibility: visibility,
            validationMode: config.card.validationMode,
            locale: config.options.locale,
            grouping: config.card.inputs.grouping,
            values: values
        )
    }

    private func wireForm() {
        form.onPick = { [weak self] field in
            self?.openPicker(field)
        }
        form.onContentSizeChange = { [weak self] in
            self?.remeasure(notify: true)
        }
        form.onFocus = { [weak self] field in
            guard let self else { return }
            self.focusedFieldView = field
            self.scrollFieldIntoView(field, keyboardFrame: self.lastKeyboardFrame, duration: 0.25)
        }
    }

    private func rebuildForAppearanceChange() {
        let values = form?.currentValues() ?? initialValues
        let attempted = form?.didAttemptSubmit ?? false
        closePicker()
        let theme = resolvedTheme()
        applyPageBackground(theme)
        form = makeForm(values: values, theme: theme)
        wireForm()
        build(theme: theme)
        if attempted {
            _ = form.validateAndShowErrors()
        }
        remeasure(notify: true)
    }

    private func activate(_ constraints: [NSLayoutConstraint]) {
        NSLayoutConstraint.activate(constraints)
        installedConstraints.append(contentsOf: constraints)
    }

    private func clearBuiltChrome() {
        NSLayoutConstraint.deactivate(installedConstraints)
        installedConstraints.removeAll()
        contentStack?.removeFromSuperview()
        contentStack = nil
        scrollView = nil
        header.subviews.forEach { $0.removeFromSuperview() }
        footer.subviews.forEach { $0.removeFromSuperview() }
    }

    private func applyPageBackground(_ theme: CheckoutTheme) {
        if presentation == .inline {
            view.backgroundColor = .clear
            view.isOpaque = false
        } else {
            view.backgroundColor = theme.background
            view.isOpaque = true
        }
    }

    private func resolvedTheme() -> CheckoutTheme {
        CheckoutTheme.resolve(
            config: config,
            isDark: UIHelpers.isDarkMode(config: config, traitCollection: traitCollection)
        )
    }

    private func build(theme: CheckoutTheme) {
        clearBuiltChrome()
        let back = UIButton(type: .system)
        back.setImage(
            EmbeddedAssets.image(named: "chevron-left")?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        back.tintColor = theme.primaryText
        back.backgroundColor = theme.neutralChip
        back.layer.cornerRadius = 18
        back.accessibilityLabel = Strings.text("personalDetails.back", locale: config.options.locale)
        back.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.view.endEditing(true)
            self.onBack?(self.form.currentValues())
        }, for: .touchUpInside)
        back.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.attributedText = NSAttributedString(
            string: Strings.text("personalDetails.enterDetails", locale: config.options.locale),
            attributes: [
                .font: theme.font(ofSize: 21, weight: .semibold),
                .foregroundColor: theme.primaryText,
                .kern: -0.63,
            ]
        )
        titleLabel.numberOfLines = 2
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        header.addSubview(back)
        header.addSubview(titleLabel)
        activate([
            header.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            back.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            back.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            back.widthAnchor.constraint(equalToConstant: 36),
            back.heightAnchor.constraint(equalToConstant: 36),
            titleLabel.leadingAnchor.constraint(equalTo: back.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: header.topAnchor),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: header.bottomAnchor),
        ])
        let headerFit = header.heightAnchor.constraint(equalToConstant: 36)
        headerFit.priority = .defaultHigh
        activate([headerFit])

        let formHost = makeFormHost()

        continueButton.translatesAutoresizingMaskIntoConstraints = false
        let title = Strings.text("personalDetails.continue", locale: config.options.locale)
        continueButton.apply(theme: theme, title: title, processing: false, enabled: true)
        let powered = PoweredByFooterView(theme: theme, locale: config.options.locale)
        let footerStack = UIStackView(arrangedSubviews: [continueButton, powered])
        footerStack.axis = .vertical
        footerStack.spacing = 10
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(footerStack)
        var footerConstraints = [
            footerStack.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            footerStack.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            footerStack.bottomAnchor.constraint(equalTo: footer.bottomAnchor),
        ]
        if showsFooterHairline {
            let hairline = UIView()
            hairline.backgroundColor = theme.footerBorder
            hairline.translatesAutoresizingMaskIntoConstraints = false
            footer.addSubview(hairline)
            footerConstraints.append(contentsOf: [
                hairline.topAnchor.constraint(equalTo: footer.topAnchor),
                hairline.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: -22),
                hairline.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: 22),
                hairline.heightAnchor.constraint(equalToConstant: 1),
                footerStack.topAnchor.constraint(equalTo: hairline.bottomAnchor, constant: 12),
            ])
        } else {
            footerConstraints.append(
                footerStack.topAnchor.constraint(equalTo: footer.topAnchor, constant: 4)
            )
        }
        activate(footerConstraints)

        let stack = UIStackView(arrangedSubviews: [header, formHost, footer])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(20, after: header)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentStack = stack
        view.addSubview(stack)
        let horizontal = horizontalInset
        let topInset: CGFloat = presentation == .inline ? 0 : 8
        let bottomInset: CGFloat = presentation == .inline ? 0 : 8
        let top = presentation == .inline ? view.topAnchor : view.safeAreaLayoutGuide.topAnchor
        let bottom = presentation == .inline ? view.bottomAnchor : view.safeAreaLayoutGuide.bottomAnchor
        activate([
            stack.topAnchor.constraint(equalTo: top, constant: topInset),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: horizontal),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -horizontal),
            stack.bottomAnchor.constraint(equalTo: bottom, constant: -bottomInset),
        ])
    }

    private func makeFormHost() -> UIView {
        guard presentation == .sheet else {
            form.translatesAutoresizingMaskIntoConstraints = false
            return form
        }
        let scroll = OverflowScrollView()
        scroll.alwaysBounceVertical = false
        scroll.bounces = false
        scroll.isScrollEnabled = false
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.keyboardDismissMode = .interactive
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.onLayout = { [weak self] in
            self?.updateScrollability()
        }
        form.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(form)
        activate([
            form.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            form.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            form.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            form.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            form.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])
        scrollView = scroll
        return scroll
    }

    private var horizontalInset: CGFloat { presentation == .inline ? 0 : 22 }

    private func updateScrollability() {
        guard let scrollView else { return }
        let overflows = scrollView.contentSize.height > scrollView.bounds.height + 1
        guard scrollView.isScrollEnabled != overflows else { return }
        scrollView.isScrollEnabled = overflows
        scrollView.bounces = overflows
        scrollView.alwaysBounceVertical = overflows
    }

    private func observeKeyboard() {
        keyboardObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self, let field = self.focusedFieldView else { return }
            let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
            self.lastKeyboardFrame = frame
            self.scrollFieldIntoView(field, keyboardFrame: frame, duration: duration)
        }
    }

    private func scrollFieldIntoView(_ field: UIView, keyboardFrame: CGRect?, duration: TimeInterval) {
        if presentation == .sheet {
            DispatchQueue.main.async { [weak self, weak field] in
                guard let self, let field else { return }
                self.view.layoutIfNeeded()
                self.updateScrollability()
                guard let scrollView = self.scrollView, scrollView.isScrollEnabled else { return }
                // The sheet has already moved above the keyboard, so the scroll view bounds are the visible area.
                let below = CGRect(x: scrollView.bounds.minX, y: scrollView.bounds.maxY, width: scrollView.bounds.width, height: 0)
                self.applyScroll(field: field, scrollView: scrollView, keyboardFrame: below, duration: duration)
            }
            return
        }
        guard let scrollView = ancestorScrollView(from: field) else { return }
        scrollView.layoutIfNeeded()
        let keyboard = keyboardFrame.map { scrollView.convert($0, from: nil) }
            ?? CGRect(x: 0, y: CGFloat.greatestFiniteMagnitude, width: 0, height: 0)
        applyScroll(field: field, scrollView: scrollView, keyboardFrame: keyboard, duration: duration)
    }

    private func ancestorScrollView(from field: UIView) -> UIScrollView? {
        var current = field.superview
        while let view = current {
            if let scroll = view as? UIScrollView { return scroll }
            current = view.superview
        }
        return nil
    }

    private func applyScroll(
        field: UIView,
        scrollView: UIScrollView,
        keyboardFrame: CGRect,
        duration: TimeInterval
    ) {
        let fieldRect = field.convert(field.bounds, to: scrollView)
        guard let target = KeyboardScroll.targetOffset(
            fieldRect: fieldRect,
            bounds: scrollView.bounds,
            contentSize: scrollView.contentSize,
            contentOffset: scrollView.contentOffset,
            keyboardFrame: keyboardFrame
        ) else { return }
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            scrollView.contentOffset = target
        }
    }

    private func remeasure(notify: Bool) {
        let chrome = horizontalInset * 2
        let width = view.bounds.width > 0 ? view.bounds.width - chrome : UIScreen.main.bounds.width - chrome
        let formHeight = form.systemLayoutSizeFitting(
            CGSize(width: max(width, 1), height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        let headerHeight = header.systemLayoutSizeFitting(
            CGSize(width: max(width, 1), height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        let footerHeight = footer.systemLayoutSizeFitting(
            CGSize(width: max(width, 1), height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        let safeTop: CGFloat
        let safeBottom: CGFloat
        if presentation == .inline {
            safeTop = 0
            safeBottom = 0
        } else if view.window == nil {
            safeTop = view.safeAreaInsets.top
            safeBottom = max(view.safeAreaInsets.bottom, preparedSafeBottom)
        } else {
            safeTop = view.safeAreaInsets.top
            safeBottom = view.safeAreaInsets.bottom
        }
        let verticalPad: CGFloat = presentation == .inline ? 0 : 8
        let hairline = showsFooterHairline ? 1.0 : 0
        let next = ceil(safeTop + verticalPad + headerHeight + 20 + formHeight + 12 + hairline + footerHeight + verticalPad + safeBottom)
        guard abs(next - measuredHeight) > 1 else { return }
        measuredHeight = next
        guard notify, !contentSizeNotifyScheduled else { return }
        contentSizeNotifyScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.contentSizeNotifyScheduled = false
            self.onContentSizeChange?()
        }
    }

    private func openPicker(_ field: PersonalDetailsField) {
        view.endEditing(true)
        let theme = resolvedTheme()
        let locale = config.options.locale
        let list: SelectionListViewController
        switch field {
        case .country:
            list = SelectionListViewController(
                title: Strings.text("personalDetails.country", locale: locale),
                options: countryOptions(locale: locale),
                selectedID: form.currentValues().country,
                theme: theme,
                locale: locale
            )
        case .phoneCountry:
            list = SelectionListViewController(
                title: Strings.text("personalDetails.phoneCountryCode", locale: locale),
                options: phoneOptions(locale: locale),
                selectedID: form.currentValues().phoneCountry,
                theme: theme,
                locale: locale
            )
        case .region:
            let country = form.currentValues().country
            let format = AddressFormats.format(countryCode: country)
            list = SelectionListViewController(
                title: Strings.text(format.regionLabelKey, locale: locale),
                options: Subdivisions.list(countryCode: country).map {
                    SelectionListOption(id: $0.name, title: $0.name)
                },
                selectedID: form.currentValues().region,
                theme: theme,
                locale: locale
            )
        default:
            return
        }
        list.onSelect = { [weak self] id in
            guard let self else { return }
            switch field {
            case .country: self.form.setCountry(id)
            case .phoneCountry: self.form.setPhoneCountry(id)
            case .region: self.form.setRegion(id)
            default: break
            }
            self.form.notePickerDismissed(field)
            self.closePicker()
        }
        list.onBack = { [weak self] in
            self?.form.notePickerDismissed(field)
            self?.closePicker()
        }
        pickerField = field
        showPicker(list)
    }

    /// Swiping the inline picker sheet down leaves the field unchanged.
    package func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard presentation == .inline,
              let picker,
              presentationController.presentedViewController === picker else { return }
        let field = pickerField
        self.picker = nil
        pickerField = nil
        if let field {
            form.notePickerDismissed(field)
        }
    }

    private func showPicker(_ list: SelectionListViewController) {
        if presentation == .inline {
            presentInlinePicker(list)
            return
        }
        picker?.view.removeFromSuperview()
        picker?.removeFromParent()
        addChild(list)
        list.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(list.view)
        NSLayoutConstraint.activate([
            list.view.topAnchor.constraint(equalTo: view.topAnchor),
            list.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            list.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            list.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        list.didMove(toParent: self)
        contentStack.isHidden = true
        picker = list
    }

    private func presentInlinePicker(_ list: SelectionListViewController) {
        let theme = resolvedTheme()
        list.overrideUserInterfaceStyle = UIHelpers.overrideStyle(for: config)
        list.modalPresentationStyle = .pageSheet
        if let sheet = list.sheetPresentationController {
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = theme.sheetCornerRadius
            sheet.detents = [.large()]
        }
        picker = list
        let presenter = nearestPresenter()
        presenter.present(list, animated: true)
        list.presentationController?.delegate = self
    }

    private func nearestPresenter() -> UIViewController {
        var responder: UIResponder? = next
        while let current = responder {
            if let controller = current as? UIViewController {
                return controller
            }
            responder = current.next
        }
        return self
    }

    private func closePicker() {
        guard let picker else { return }
        picker.view.endEditing(true)
        self.picker = nil
        pickerField = nil
        if presentation == .inline {
            picker.dismiss(animated: true)
            return
        }
        picker.willMove(toParent: nil)
        picker.view.removeFromSuperview()
        picker.removeFromParent()
        contentStack.isHidden = false
    }

    private func countryOptions(locale: String) -> [SelectionListOption] {
        Countries.all.map { country in
            let name = Countries.localizedName(country, locale: locale)
            return SelectionListOption(
                id: country.code,
                title: "\(Countries.flagEmoji(code: country.code)) \(name)",
                searchText: "\(name) \(country.code)"
            )
        }
        .sorted { $0.searchText.localizedCaseInsensitiveCompare($1.searchText) == .orderedAscending }
    }

    private func phoneOptions(locale: String) -> [SelectionListOption] {
        Countries.all.map { country in
            let name = Countries.localizedName(country, locale: locale)
            let flag = Countries.flagEmoji(code: country.code)
            return SelectionListOption(
                id: country.code,
                title: "\(name) \(flag)  +\(country.dialCode)",
                searchText: "\(name) \(country.dialCode) \(country.code)"
            )
        }
        .sorted { $0.searchText.localizedCaseInsensitiveCompare($1.searchText) == .orderedAscending }
    }
}

/// Reports layout after `contentSize` has been resolved from the content layout guide.
private final class OverflowScrollView: UIScrollView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}
