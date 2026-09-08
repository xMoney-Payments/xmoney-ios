import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

package final class CardFormView: UIView, UITextFieldDelegate {
    package struct Configuration {
        package let showSaveOptIn: Bool
        package let showCardDetailsCaption: Bool
        package let validationMode: PaymentConfig.ValidationMode
        package let locale: String
        package let grouping: PaymentConfig.CardGrouping

        package var isSpaced: Bool { grouping == .spaced }

        package init(
            showSaveOptIn: Bool,
            showCardDetailsCaption: Bool = false,
            validationMode: PaymentConfig.ValidationMode = .onTouched,
            locale: String = "en-US",
            grouping: PaymentConfig.CardGrouping = .condensed
        ) {
            self.showSaveOptIn = showSaveOptIn
            self.showCardDetailsCaption = showCardDetailsCaption
            self.validationMode = validationMode
            self.locale = locale
            self.grouping = grouping
        }
    }

    private enum Field: CaseIterable {
        case number, expiry, cvv, holder
    }

    private struct FieldUI {
        let field: UITextField
        var blurred: Bool = false
        var focused: Bool = false
    }

    private let theme: CheckoutTheme
    private let config: Configuration

    package var onValidationChange: ((Bool) -> Void)?
    package var onContentSizeChange: (() -> Void)?

    private var showErrors = false
    private var displayedErrors: [Field: CardFieldValidators.FieldError] = [:]

    private enum RevalidateTrigger {
        case change
        case blur
        case submit
        case layout
    }

    private let outerStack = UIStackView()
    private let captionLabel = UILabel()
    private let container = UIView()
    private let containerStack = UIStackView()
    private let errorsStack = UIStackView()
    private var fields: [Field: FieldUI] = [:]
    private var spacedErrorLabels: [Field: UILabel] = [:]
    private var spacedBoxes: [Field: UIView] = [:]
    private let brandIcon = CardBrandIcon(size: .fieldTrailing)
    private let cvvIconView = CvvIconView()
    private var saveCheckbox: CheckboxControl?
    private let errorOverlay = UIView()

    package init(theme: CheckoutTheme, config: Configuration) {
        self.theme = theme
        self.config = config
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    package func resetErrors() {
        showErrors = false
        displayedErrors = [:]
        revalidate(changedField: nil, trigger: .layout)
    }

    package var currentInput: CardInput {
        let (month, year) = parseExpiry(fields[.expiry]?.field.text ?? "")
        return CardInput(
            number: CardFieldValidators.normalizeDigits(fields[.number]?.field.text ?? ""),
            expiryMonth: month,
            expiryYear: year,
            cvv: fields[.cvv]?.field.text ?? "",
            holderName: fields[.holder]?.field.text,
            saveCard: config.showSaveOptIn && (saveCheckbox?.isChecked ?? false)
        )
    }

    package struct Draft {
        package var numberText: String
        package var expiryText: String
        package var cvvText: String
        package var holderText: String
        package var saveCard: Bool
        package var showErrors: Bool
    }

    package var draft: Draft {
        Draft(
            numberText: fields[.number]?.field.text ?? "",
            expiryText: fields[.expiry]?.field.text ?? "",
            cvvText: fields[.cvv]?.field.text ?? "",
            holderText: fields[.holder]?.field.text ?? "",
            saveCard: saveCheckbox?.isChecked ?? false,
            showErrors: showErrors
        )
    }

    package func restore(_ draft: Draft) {
        fields[.number]?.field.text = draft.numberText
        fields[.expiry]?.field.text = draft.expiryText
        fields[.cvv]?.field.text = draft.cvvText
        fields[.holder]?.field.text = draft.holderText
        saveCheckbox?.setChecked(draft.saveCard, animated: false)
        if let number = fields[.number]?.field {
            let result = CardFieldValidators.formatCardNumber(number.text ?? "")
            number.text = result.formatted
            brandIcon.setBrand(result.brand, visaTint: theme.visaTint)
        }
        if draft.showErrors {
            _ = validateAndShowErrors()
        }
    }

    package var hasVisibleErrors: Bool { hasVisibleErrorLabels() }

    package func relocalizeVisibleErrors() {
        guard hasVisibleErrors else { return }
        revalidate(changedField: nil, trigger: .submit)
    }

    package var isValid: Bool {
        validateAll().isEmpty
    }

    package var isReady: Bool {
        let input = currentInput
        let digits = CardFieldValidators.normalizeDigits(input.number)
        let expDigits = CardFieldValidators.normalizeDigits(
            (fields[.expiry]?.field.text ?? "").replacingOccurrences(of: " / ", with: "")
        )
        let cvcDigits = CardFieldValidators.normalizeDigits(input.cvv)
        let holderOk = !(input.holderName?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
        return digits.count == 16 && expDigits.count >= 4 && cvcDigits.count >= 3 && holderOk
    }

    private func setup() {
        outerStack.axis = .vertical
        outerStack.spacing = 6
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            outerStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        if config.showCardDetailsCaption {
            captionLabel.text = Strings.text("sheet.cardDetails", locale: config.locale)
            captionLabel.font = theme.font(ofSize: 13, weight: .semibold)
            captionLabel.textColor = theme.primaryText.withAlphaComponent(0.45)
            let captionWrap = UIView()
            captionLabel.translatesAutoresizingMaskIntoConstraints = false
            captionWrap.addSubview(captionLabel)
            NSLayoutConstraint.activate([
                captionLabel.topAnchor.constraint(equalTo: captionWrap.topAnchor),
                captionLabel.leadingAnchor.constraint(equalTo: captionWrap.leadingAnchor, constant: 2),
                captionLabel.trailingAnchor.constraint(equalTo: captionWrap.trailingAnchor),
                captionLabel.bottomAnchor.constraint(equalTo: captionWrap.bottomAnchor),
            ])
            outerStack.addArrangedSubview(captionWrap)
            outerStack.setCustomSpacing(9, after: captionWrap)
        }

        if config.isSpaced {
            setupSpacedFields()
        } else {
            setupCondensedFields()
        }

        brandIcon.setMutedTint(theme.mutedIcon)

        if !config.isSpaced {
            errorsStack.axis = .vertical
            errorsStack.spacing = 2
            outerStack.addArrangedSubview(errorsStack)
        }

        if config.showSaveOptIn {
            let saveRow = UIControl()
            let checkbox = CheckboxControl(theme: theme)
            checkbox.setChecked(false, animated: false)
            saveCheckbox = checkbox

            let label = UILabel()
            label.text = Strings.text("sheet.saveCardShort", locale: config.locale)
            label.font = theme.font(ofSize: 14, weight: .semibold)
            label.textColor = theme.primaryText

            let row = UIStackView(arrangedSubviews: [checkbox, label])
            row.axis = .horizontal
            row.spacing = 11
            row.alignment = .center
            row.isUserInteractionEnabled = false
            row.translatesAutoresizingMaskIntoConstraints = false
            saveRow.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: saveRow.topAnchor, constant: 12),
                row.leadingAnchor.constraint(equalTo: saveRow.leadingAnchor, constant: 2),
                row.trailingAnchor.constraint(lessThanOrEqualTo: saveRow.trailingAnchor),
                row.bottomAnchor.constraint(equalTo: saveRow.bottomAnchor, constant: -12),
            ])
            saveRow.addAction(UIAction { [weak checkbox] _ in
                checkbox?.sendActions(for: .touchUpInside)
            }, for: .touchUpInside)
            outerStack.addArrangedSubview(saveRow)
        }
    }

    private func setupCondensedFields() {
        container.backgroundColor = theme.componentBackground
        container.layer.cornerRadius = theme.fieldGroupRadius
        container.layer.borderWidth = theme.borderWidth
        container.layer.borderColor = theme.fieldBorder.cgColor
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        outerStack.addArrangedSubview(container)

        errorOverlay.layer.borderWidth = theme.fieldStrokeWidth(hasError: true)
        errorOverlay.layer.borderColor = theme.errorBorder.cgColor
        errorOverlay.layer.cornerRadius = theme.fieldGroupRadius
        errorOverlay.isUserInteractionEnabled = false
        errorOverlay.isHidden = true
        errorOverlay.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(errorOverlay)
        NSLayoutConstraint.activate([
            errorOverlay.topAnchor.constraint(equalTo: container.topAnchor),
            errorOverlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            errorOverlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            errorOverlay.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        containerStack.axis = .vertical
        containerStack.spacing = 0
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        containerStack.setContentCompressionResistancePriority(.required, for: .vertical)
        containerStack.setContentHuggingPriority(.required, for: .vertical)
        container.addSubview(containerStack)
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: container.topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        containerStack.addArrangedSubview(makeNumberRow())
        containerStack.addArrangedSubview(makeDivider())
        containerStack.addArrangedSubview(makeExpCvvRow())
        containerStack.addArrangedSubview(makeDivider())
        containerStack.addArrangedSubview(makeHolderRow())
    }

    private func setupSpacedFields() {
        let spaced = UIStackView()
        spaced.axis = .vertical
        spaced.spacing = 12
        spaced.translatesAutoresizingMaskIntoConstraints = false
        outerStack.addArrangedSubview(spaced)

        spaced.addArrangedSubview(makeSpacedLabeledField(
            field: .number,
            titleKey: "elements.cardNumber",
            content: makeNumberRow()
        ))

        let expCvvRow = UIStackView()
        expCvvRow.axis = .horizontal
        expCvvRow.spacing = 12
        expCvvRow.distribution = .fillEqually
        expCvvRow.addArrangedSubview(makeSpacedLabeledField(
            field: .expiry,
            titleKey: "elements.expDate",
            content: makeStandaloneExpiryRow()
        ))
        expCvvRow.addArrangedSubview(makeSpacedLabeledField(
            field: .cvv,
            titleKey: "elements.cvv",
            content: makeStandaloneCvvRow()
        ))
        spaced.addArrangedSubview(expCvvRow)
        spaced.addArrangedSubview(makeSpacedLabeledField(
            field: .holder,
            titleKey: "elements.cardholderName",
            content: makeHolderRow()
        ))
    }

    private func makeSpacedLabeledField(field: Field, titleKey: String, content: UIView) -> UIView {
        let wrapper = UIStackView()
        wrapper.axis = .vertical
        wrapper.spacing = 6

        let label = UILabel()
        label.text = Strings.text(titleKey, locale: config.locale)
        label.font = theme.font(ofSize: 13, weight: .semibold)
        label.textColor = theme.secondaryText
        label.isAccessibilityElement = false

        let box = UIView()
        box.backgroundColor = theme.componentBackground
        box.layer.cornerRadius = theme.fieldGroupRadius
        box.layer.borderWidth = theme.borderWidth
        box.layer.borderColor = theme.fieldBorder.cgColor
        box.clipsToBounds = true
        spacedBoxes[field] = box

        content.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: box.topAnchor),
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])

        let errorLabel = UILabel()
        errorLabel.font = theme.font(ofSize: 12.5, weight: .semibold)
        errorLabel.textColor = theme.errorText
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        spacedErrorLabels[field] = errorLabel

        wrapper.addArrangedSubview(label)
        wrapper.addArrangedSubview(box)
        wrapper.addArrangedSubview(errorLabel)
        return wrapper
    }

    private func makeDivider() -> UIView {
        let line = UIView()
        line.backgroundColor = theme.fieldDivider
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    private func makeTextField(
        field: Field,
        placeholderKey: String,
        keyboard: UIKeyboardType,
        contentType: UITextContentType? = nil,
        capitalization: UITextAutocapitalizationType = .none,
        secure: Bool = false
    ) -> UITextField {
        let textField = UITextField()
        let placeholder = Strings.text(placeholderKey, locale: config.locale)
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: theme.placeholderText]
        )
        textField.font = theme.font(ofSize: 18, weight: .medium)
        textField.textColor = theme.componentText
        textField.keyboardType = keyboard
        textField.borderStyle = .none
        textField.contentVerticalAlignment = .center
        textField.delegate = self
        textField.isSecureTextEntry = secure
        textField.autocapitalizationType = capitalization
        if let contentType { textField.textContentType = contentType }
        textField.accessibilityLabel = accessibilityLabel(for: field)
        textField.addTarget(self, action: #selector(editingChanged(_:)), for: .editingChanged)
        textField.translatesAutoresizingMaskIntoConstraints = false
        fields[field] = FieldUI(field: textField)
        return textField
    }

    private func accessibilityLabel(for field: Field) -> String {
        let key: String
        switch field {
        case .number: key = "elements.cardNumber"
        case .expiry: key = "elements.expDate"
        case .cvv: key = "elements.cvv"
        case .holder: key = "elements.cardholderName"
        }
        return Strings.text(key, locale: config.locale)
    }

    private func makeNumberRow() -> UIView {
        let row = makeFieldRow()

        let textField = makeTextField(
            field: .number,
            placeholderKey: config.isSpaced ? "placeholder.cardNumber.spaced" : "placeholder.cardNumber",
            keyboard: .numberPad,
            contentType: .creditCardNumber
        )
        row.addSubview(textField)
        row.addSubview(brandIcon)

        NSLayoutConstraint.activate([
            brandIcon.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            brandIcon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textField.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            textField.trailingAnchor.constraint(equalTo: brandIcon.leadingAnchor, constant: -10),
            textField.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textField.heightAnchor.constraint(equalTo: row.heightAnchor),
        ])
        return row
    }

    private func makeStandaloneExpiryRow() -> UIView {
        let row = makeFieldRow()

        let textField = makeTextField(
            field: .expiry,
            placeholderKey: "placeholder.expDate",
            keyboard: .numberPad
        )
        row.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            textField.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            textField.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textField.heightAnchor.constraint(equalTo: row.heightAnchor),
        ])
        return row
    }

    private func makeStandaloneCvvRow() -> UIView {
        let row = makeFieldRow()

        let textField = makeTextField(
            field: .cvv,
            placeholderKey: "placeholder.cvv.spaced",
            keyboard: .numberPad,
            secure: false
        )
        cvvIconView.iconColor = theme.mutedIcon
        cvvIconView.isUserInteractionEnabled = false
        cvvIconView.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(textField)
        row.addSubview(cvvIconView)
        NSLayoutConstraint.activate([
            cvvIconView.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            cvvIconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            cvvIconView.widthAnchor.constraint(equalToConstant: 20),
            cvvIconView.heightAnchor.constraint(equalToConstant: 20),
            textField.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            textField.trailingAnchor.constraint(equalTo: cvvIconView.leadingAnchor, constant: -10),
            textField.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textField.heightAnchor.constraint(equalTo: row.heightAnchor),
        ])
        return row
    }

    private func makeExpCvvRow() -> UIView {
        let row = makeFieldRow()

        let expContainer = UIView()
        expContainer.translatesAutoresizingMaskIntoConstraints = false
        let expField = makeTextField(
            field: .expiry,
            placeholderKey: "placeholder.expDate",
            keyboard: .numberPad
        )
        expContainer.addSubview(expField)
        expField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            expField.leadingAnchor.constraint(equalTo: expContainer.leadingAnchor, constant: 14),
            expField.trailingAnchor.constraint(equalTo: expContainer.trailingAnchor, constant: -8),
            expField.centerYAnchor.constraint(equalTo: expContainer.centerYAnchor),
            expField.heightAnchor.constraint(equalTo: expContainer.heightAnchor),
        ])

        let divider = UIView()
        divider.backgroundColor = theme.fieldDivider
        divider.translatesAutoresizingMaskIntoConstraints = false

        let cvvContainer = UIView()
        cvvContainer.translatesAutoresizingMaskIntoConstraints = false
        let cvvField = makeTextField(
            field: .cvv,
            placeholderKey: "placeholder.cvv",
            keyboard: .numberPad,
            secure: false
        )
        cvvIconView.iconColor = theme.mutedIcon
        cvvIconView.isUserInteractionEnabled = false
        cvvIconView.translatesAutoresizingMaskIntoConstraints = false

        cvvContainer.addSubview(cvvField)
        cvvContainer.addSubview(cvvIconView)
        cvvField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cvvIconView.trailingAnchor.constraint(equalTo: cvvContainer.trailingAnchor, constant: -14),
            cvvIconView.centerYAnchor.constraint(equalTo: cvvContainer.centerYAnchor),
            cvvIconView.widthAnchor.constraint(equalToConstant: 20),
            cvvIconView.heightAnchor.constraint(equalToConstant: 20),
            cvvField.leadingAnchor.constraint(equalTo: cvvContainer.leadingAnchor, constant: 14),
            cvvField.trailingAnchor.constraint(equalTo: cvvIconView.leadingAnchor, constant: -10),
            cvvField.centerYAnchor.constraint(equalTo: cvvContainer.centerYAnchor),
            cvvField.heightAnchor.constraint(equalTo: cvvContainer.heightAnchor),
        ])

        row.addSubview(expContainer)
        row.addSubview(divider)
        row.addSubview(cvvContainer)
        NSLayoutConstraint.activate([
            expContainer.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            expContainer.topAnchor.constraint(equalTo: row.topAnchor),
            expContainer.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            expContainer.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.5, constant: -0.5),
            divider.leadingAnchor.constraint(equalTo: expContainer.trailingAnchor),
            divider.topAnchor.constraint(equalTo: row.topAnchor),
            divider.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            cvvContainer.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            cvvContainer.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            cvvContainer.topAnchor.constraint(equalTo: row.topAnchor),
            cvvContainer.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])
        return row
    }

    private func makeHolderRow() -> UIView {
        let row = makeFieldRow()

        let textField = makeTextField(
            field: .holder,
            placeholderKey: "placeholder.cardholderName",
            keyboard: .default,
            contentType: .name,
            capitalization: .words
        )
        row.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            textField.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            textField.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textField.heightAnchor.constraint(equalTo: row.heightAnchor),
        ])
        return row
    }

    private func makeFieldRow() -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        let height = row.heightAnchor.constraint(equalToConstant: theme.fieldRowHeight)
        height.priority = .required
        height.isActive = true
        row.setContentCompressionResistancePriority(.required, for: .vertical)
        row.setContentHuggingPriority(.required, for: .vertical)
        return row
    }

    @objc private func editingChanged(_ field: UITextField) {
        if field === fields[.number]?.field {
            let result = CardFieldValidators.formatCardNumber(field.text ?? "")
            field.text = result.formatted
            brandIcon.setBrand(result.brand, visaTint: theme.visaTint)
        } else if field === fields[.expiry]?.field {
            field.text = CardFieldValidators.formatExpiry(field.text ?? "")
        } else if field === fields[.cvv]?.field {
            field.text = String(CardFieldValidators.normalizeDigits(field.text ?? "").prefix(4))
        }
        revalidate(changedField: fieldFor(textField: field), trigger: .change)
        onValidationChange?(isReady)
    }

    private func fieldFor(textField: UITextField) -> Field? {
        fields.first(where: { $0.value.field === textField })?.key
    }

    private var lastErrorVisible = false

    private func revalidate(changedField: Field?, trigger: RevalidateTrigger) {
        let current = validateAll()
        updateDisplayedErrors(current: current, changedField: changedField, trigger: trigger)
        updateContainerBorder()
        let errorVisible = hasVisibleErrorLabels()
        updateErrorLabels()
        if errorVisible != lastErrorVisible {
            lastErrorVisible = errorVisible
            notifyContentSizeChangeIfNeeded()
        }
    }

    private func updateDisplayedErrors(
        current: [Field: CardFieldValidators.FieldError],
        changedField: Field?,
        trigger: RevalidateTrigger
    ) {
        switch trigger {
        case .submit:
            displayedErrors = current
        case .blur:
            if let field = changedField {
                displayedErrors[field] = current[field]
            }
        case .change:
            for field in Field.allCases {
                if CardValidationDisplay.shouldRefreshDisplayedErrorOnChange(
                    mode: config.validationMode,
                    fieldBlurred: fields[field]?.blurred ?? false,
                    submitAttempted: showErrors
                ) {
                    displayedErrors[field] = current[field]
                }
            }
        case .layout:
            break
        }
    }

    private func visibleError(for field: Field) -> CardFieldValidators.FieldError? {
        guard shouldShowError(for: field) else { return nil }
        return displayedErrors[field]
    }

    private func hasVisibleErrorLabels() -> Bool {
        if config.isSpaced {
            return Field.allCases.contains { visibleError(for: $0) != nil }
        }
        return firstVisibleError() != nil
    }

    private func updateContainerBorder() {
        if config.isSpaced {
            for (field, box) in spacedBoxes {
                let hasVisibleError = visibleError(for: field) != nil
                let focused = fields[field]?.focused ?? false
                if hasVisibleError {
                    box.layer.borderWidth = theme.fieldStrokeWidth(hasError: true)
                    box.layer.borderColor = theme.errorBorder.cgColor
                } else if focused {
                    box.layer.borderWidth = theme.fieldStrokeWidth(hasError: false)
                    box.layer.borderColor = theme.primary.cgColor
                } else {
                    box.layer.borderWidth = theme.fieldStrokeWidth(hasError: false)
                    box.layer.borderColor = theme.fieldBorder.cgColor
                }
            }
            return
        }

        let hasVisibleError = firstVisibleError() != nil
        let anyFocused = fields.values.contains(where: \.focused)
        errorOverlay.isHidden = !hasVisibleError
        if hasVisibleError {
            container.layer.borderWidth = theme.fieldStrokeWidth(hasError: true)
            container.layer.borderColor = theme.errorBorder.cgColor
        } else if anyFocused {
            container.layer.borderWidth = theme.fieldStrokeWidth(hasError: false)
            container.layer.borderColor = theme.primary.cgColor
        } else {
            container.layer.borderWidth = theme.fieldStrokeWidth(hasError: false)
            container.layer.borderColor = theme.fieldBorder.cgColor
        }
    }

    private static let errorDisplayOrder: [Field] = [.number, .expiry, .cvv, .holder]

    private func firstVisibleError() -> Field? {
        Self.errorDisplayOrder.first { visibleError(for: $0) != nil }
    }

    private func updateErrorLabels() {
        if config.isSpaced {
            for field in Field.allCases {
                guard let label = spacedErrorLabels[field] else { continue }
                if let error = visibleError(for: field) {
                    label.text = error.localizedMessage(locale: config.locale)
                    label.isHidden = false
                } else {
                    label.text = nil
                    label.isHidden = true
                }
            }
            return
        }

        errorsStack.arrangedSubviews.forEach {
            errorsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        if let field = firstVisibleError(), let error = visibleError(for: field) {
            let row = ErrorRowView(message: error.localizedMessage(locale: config.locale), theme: theme)
            errorsStack.addArrangedSubview(row)
        }
    }

    private func shouldShowError(for field: Field) -> Bool {
        guard fields[field] != nil else { return false }
        return CardValidationDisplay.shouldShowError(
            mode: config.validationMode,
            fieldBlurred: fields[field]?.blurred ?? false,
            submitAttempted: showErrors
        )
    }

    private func validateAll() -> [Field: CardFieldValidators.FieldError] {
        let input = currentInput
        var errors: [Field: CardFieldValidators.FieldError] = [:]
        if let err = CardFieldValidators.validateCardNumber(input.number) { errors[.number] = err }
        if let err = CardFieldValidators.validateExpiry(month: input.expiryMonth, year: input.expiryYear) {
            errors[.expiry] = err
        }
        if let err = CardFieldValidators.validateCVV(input.cvv) { errors[.cvv] = err }
        if let err = CardFieldValidators.validateHolderName(input.holderName) {
            errors[.holder] = err
        }
        return errors
    }

    @discardableResult
    package func validateAndShowErrors() -> Bool {
        showErrors = true
        revalidate(changedField: nil, trigger: .submit)
        onValidationChange?(isReady)
        return isValid
    }

    private func notifyContentSizeChangeIfNeeded() {
        onContentSizeChange?()
    }

    // MARK: - UITextFieldDelegate

    package func textFieldDidBeginEditing(_ textField: UITextField) {
        guard let field = fieldFor(textField: textField), var ui = fields[field] else { return }
        ui.focused = true
        fields[field] = ui
        revalidate(changedField: field, trigger: .layout)
    }

    package func textFieldDidEndEditing(_ textField: UITextField) {
        guard let field = fieldFor(textField: textField), var ui = fields[field] else { return }
        ui.focused = false
        ui.blurred = true
        fields[field] = ui
        revalidate(changedField: field, trigger: .blur)
        onValidationChange?(isReady)
    }

    private func parseExpiry(_ text: String) -> (String, String) {
        let digits = CardFieldValidators.normalizeDigits(text)
        guard digits.count >= 2 else { return (digits, "") }
        return (String(digits.prefix(2)), String(digits.dropFirst(2).prefix(2)))
    }
}
