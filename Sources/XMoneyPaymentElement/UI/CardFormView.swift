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
            validationMode: PaymentConfig.ValidationMode = .onChange,
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
        case holder, number, expiry, cvv
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

    private let outerStack = UIStackView()
    private let captionLabel = UILabel()
    private let container = UIView()
    private let containerStack = UIStackView()
    private let errorsStack = UIStackView()
    private var fields: [Field: FieldUI] = [:]
    private var spacedErrorLabels: [Field: UILabel] = [:]
    private var spacedBoxes: [Field: UIView] = [:]
    private let brandIcon = CardBrandIcon(size: .fieldTrailing)
    private let lockIconView = LockIconView()
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
        revalidate(changedField: nil)
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

    package var isValid: Bool {
        validateAll(markTouched: false).isEmpty
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
            outerStack.addArrangedSubview(captionLabel)
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
                row.topAnchor.constraint(equalTo: saveRow.topAnchor, constant: 6),
                row.leadingAnchor.constraint(equalTo: saveRow.leadingAnchor),
                row.trailingAnchor.constraint(lessThanOrEqualTo: saveRow.trailingAnchor),
                row.bottomAnchor.constraint(equalTo: saveRow.bottomAnchor),
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
        container.layer.borderColor = theme.componentBorder.cgColor
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        outerStack.addArrangedSubview(container)

        errorOverlay.layer.borderWidth = 1.5
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

        containerStack.addArrangedSubview(makeHolderRow())
        containerStack.addArrangedSubview(makeDivider())
        containerStack.addArrangedSubview(makeNumberRow())
        containerStack.addArrangedSubview(makeDivider())
        containerStack.addArrangedSubview(makeExpCvvRow())
    }

    private func setupSpacedFields() {
        let spaced = UIStackView()
        spaced.axis = .vertical
        spaced.spacing = 12
        spaced.translatesAutoresizingMaskIntoConstraints = false
        outerStack.addArrangedSubview(spaced)

        spaced.addArrangedSubview(makeSpacedLabeledField(
            field: .holder,
            titleKey: "elements.cardholderName",
            content: makeHolderRow()
        ))
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
    }

    private func makeSpacedLabeledField(field: Field, titleKey: String, content: UIView) -> UIView {
        let wrapper = UIStackView()
        wrapper.axis = .vertical
        wrapper.spacing = 6

        let label = UILabel()
        label.text = Strings.text(titleKey, locale: config.locale)
        label.font = theme.font(ofSize: 13, weight: .semibold)
        label.textColor = theme.secondaryText

        let box = UIView()
        box.backgroundColor = theme.componentBackground
        box.layer.cornerRadius = theme.fieldGroupRadius
        box.layer.borderWidth = theme.borderWidth
        box.layer.borderColor = theme.componentBorder.cgColor
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
        textField.textColor = theme.primaryText
        textField.keyboardType = keyboard
        textField.borderStyle = .none
        textField.contentVerticalAlignment = .center
        textField.delegate = self
        textField.isSecureTextEntry = secure
        textField.autocapitalizationType = capitalization
        if let contentType { textField.textContentType = contentType }
        textField.addTarget(self, action: #selector(editingChanged(_:)), for: .editingChanged)
        textField.translatesAutoresizingMaskIntoConstraints = false
        fields[field] = FieldUI(field: textField)
        return textField
    }

    private func makeNumberRow() -> UIView {
        let row = makeFieldRow()

        let textField = makeTextField(
            field: .number,
            placeholderKey: "placeholder.cardNumber",
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
            placeholderKey: "placeholder.cvv",
            keyboard: .numberPad,
            secure: false
        )
        lockIconView.iconColor = theme.mutedIcon
        lockIconView.isUserInteractionEnabled = false
        lockIconView.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(textField)
        row.addSubview(lockIconView)
        NSLayoutConstraint.activate([
            lockIconView.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            lockIconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            lockIconView.widthAnchor.constraint(equalToConstant: 19),
            lockIconView.heightAnchor.constraint(equalToConstant: 20),
            textField.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            textField.trailingAnchor.constraint(equalTo: lockIconView.leadingAnchor, constant: -10),
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
        lockIconView.iconColor = theme.mutedIcon
        lockIconView.isUserInteractionEnabled = false
        lockIconView.translatesAutoresizingMaskIntoConstraints = false

        cvvContainer.addSubview(cvvField)
        cvvContainer.addSubview(lockIconView)
        cvvField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lockIconView.trailingAnchor.constraint(equalTo: cvvContainer.trailingAnchor, constant: -14),
            lockIconView.centerYAnchor.constraint(equalTo: cvvContainer.centerYAnchor),
            lockIconView.widthAnchor.constraint(equalToConstant: 19),
            lockIconView.heightAnchor.constraint(equalToConstant: 20),
            cvvField.leadingAnchor.constraint(equalTo: cvvContainer.leadingAnchor, constant: 14),
            cvvField.trailingAnchor.constraint(equalTo: lockIconView.leadingAnchor, constant: -10),
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
            brandIcon.setBrand(result.brand)
        } else if field === fields[.expiry]?.field {
            field.text = CardFieldValidators.formatExpiry(field.text ?? "")
        } else if field === fields[.cvv]?.field {
            field.text = String(CardFieldValidators.normalizeDigits(field.text ?? "").prefix(4))
        }
        revalidate(changedField: fieldFor(textField: field))
        onValidationChange?(isReady)
    }

    private func fieldFor(textField: UITextField) -> Field? {
        fields.first(where: { $0.value.field === textField })?.key
    }

    private var lastErrorVisible = false

    private func revalidate(changedField: Field?, forceAll: Bool = false) {
        let errors = validateAll(markTouched: false)
        updateContainerBorder(errors: errors)
        let errorVisible = hasVisibleErrorLabels(errors: errors)
        updateErrorLabels(errors: errors)
        if errorVisible != lastErrorVisible {
            lastErrorVisible = errorVisible
            notifyContentSizeChangeIfNeeded()
        }
    }

    private func hasVisibleErrorLabels(errors: [Field: CardFieldValidators.FieldError]) -> Bool {
        if config.isSpaced {
            return Field.allCases.contains { errors[$0] != nil && shouldShowError(for: $0) }
        }
        return firstVisibleError(in: errors) != nil
    }

    private func updateContainerBorder(errors: [Field: CardFieldValidators.FieldError]) {
        if config.isSpaced {
            for (field, box) in spacedBoxes {
                let hasVisibleError = errors[field] != nil && shouldShowError(for: field)
                let focused = fields[field]?.focused ?? false
                if hasVisibleError {
                    box.layer.borderWidth = 1.5
                    box.layer.borderColor = theme.errorBorder.cgColor
                } else if focused {
                    box.layer.borderWidth = theme.borderWidth
                    box.layer.borderColor = theme.primary.cgColor
                } else {
                    box.layer.borderWidth = theme.borderWidth
                    box.layer.borderColor = theme.componentBorder.cgColor
                }
            }
            return
        }

        let hasVisibleError = firstVisibleError(in: errors) != nil
        let anyFocused = fields.values.contains(where: \.focused)
        errorOverlay.isHidden = !hasVisibleError
        if hasVisibleError {
            container.layer.borderWidth = 1.5
            container.layer.borderColor = theme.errorBorder.cgColor
        } else if anyFocused {
            container.layer.borderWidth = theme.borderWidth
            container.layer.borderColor = theme.primary.cgColor
        } else {
            container.layer.borderWidth = theme.borderWidth
            container.layer.borderColor = theme.componentBorder.cgColor
        }
    }

    private static let errorDisplayOrder: [Field] = [.number, .expiry, .cvv, .holder]

    private func firstVisibleError(in errors: [Field: CardFieldValidators.FieldError]) -> Field? {
        Self.errorDisplayOrder.first { field in
            errors[field] != nil && shouldShowError(for: field)
        }
    }

    private func updateErrorLabels(errors: [Field: CardFieldValidators.FieldError]) {
        if config.isSpaced {
            for field in Field.allCases {
                guard let label = spacedErrorLabels[field] else { continue }
                if let error = errors[field], shouldShowError(for: field) {
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

        if let field = firstVisibleError(in: errors), let error = errors[field] {
            let row = ErrorRowView(message: error.localizedMessage(locale: config.locale), theme: theme)
            errorsStack.addArrangedSubview(row)
        }
    }

    private func shouldShowError(for field: Field) -> Bool {
        guard fields[field] != nil else { return false }
        if config.validationMode == .onSubmit {
            return showErrors
        }
        return showErrors || (fields[field]?.blurred ?? false)
    }

    private func validateAll(markTouched: Bool) -> [Field: CardFieldValidators.FieldError] {
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
        revalidate(changedField: nil)
        onValidationChange?(isReady)
        return isValid
    }

    private var lastNotifiedHeight: CGFloat = 0

    private func notifyContentSizeChangeIfNeeded() {
        layoutIfNeeded()
        let height = systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        guard abs(height - lastNotifiedHeight) > 0.5 else { return }
        lastNotifiedHeight = height
        onContentSizeChange?()
    }

    // MARK: - UITextFieldDelegate

    package func textFieldDidBeginEditing(_ textField: UITextField) {
        guard let field = fieldFor(textField: textField), var ui = fields[field] else { return }
        ui.focused = true
        fields[field] = ui
        revalidate(changedField: field)
    }

    package func textFieldDidEndEditing(_ textField: UITextField) {
        guard let field = fieldFor(textField: textField), var ui = fields[field] else { return }
        ui.focused = false
        ui.blurred = true
        fields[field] = ui
        revalidate(changedField: field)
        onValidationChange?(isReady)
    }

    private func parseExpiry(_ text: String) -> (String, String) {
        let digits = CardFieldValidators.normalizeDigits(text)
        guard digits.count >= 2 else { return (digits, "") }
        return (String(digits.prefix(2)), String(digits.dropFirst(2).prefix(2)))
    }
}
