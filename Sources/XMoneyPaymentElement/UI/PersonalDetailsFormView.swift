    import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

package final class PersonalDetailsFormView: UIView, UITextFieldDelegate {
    package var onPick: ((PersonalDetailsField) -> Void)?
    package var onContentSizeChange: (() -> Void)?
    package var onFocus: ((UIView) -> Void)?

    private let theme: CheckoutTheme
    private let visibility: CustomerDetailsVisibility
    private let validationMode: PaymentConfig.ValidationMode
    private let locale: String
    private let isSpaced: Bool

    private var values: PersonalDetailsValues
    private var showErrors = false
    private var blurred: Set<PersonalDetailsField> = []
    private var forceShown: Set<PersonalDetailsField> = []
    private var focusedField: PersonalDetailsField?
    private var displayedErrors: [PersonalDetailsField: PersonalDetailsFieldError] = [:]

    private var texts: [PersonalDetailsField: UITextField] = [:]
    private var selects: [PersonalDetailsField: SelectControl] = [:]
    private var boxes: [PersonalDetailsField: UIView] = [:]
    private var errorLabels: [PersonalDetailsField: UILabel] = [:]
    private var regionRow: UIView?
    private var regionDivider: UIView?
    private var postalSlot: UIView?
    private var postalDivider: UIView?
    private var cityPostalRatio: NSLayoutConstraint?
    private var regionLabel: UILabel?
    private var postalLabel: UILabel?
    private let contactGroup = UIView()
    private let addressGroup = UIView()
    private var contactErrorRow: ErrorRowView?
    private var addressErrorRow: ErrorRowView?
    private var lastErrorVisible = false

    package init(
        theme: CheckoutTheme,
        visibility: CustomerDetailsVisibility,
        validationMode: PaymentConfig.ValidationMode,
        locale: String,
        grouping: PaymentConfig.CardGrouping,
        values: PersonalDetailsValues
    ) {
        self.theme = theme
        self.visibility = visibility
        self.validationMode = validationMode
        self.locale = locale
        self.isSpaced = grouping == .spaced
        self.values = values
        super.init(frame: .zero)
        build()
        applyAddressFormat(resetRegion: false)
        renderErrors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    package func currentValues() -> PersonalDetailsValues { values }

    package var didAttemptSubmit: Bool { showErrors }

    package func setCountry(_ code: String) {
        let hadRegion = !values.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hadPostal = !values.postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let regionTouched = hadRegion || blurred.contains(.region)
        let postalTouched = hadPostal || blurred.contains(.postalCode)
        values.country = code
        values.region = ""
        selects[.region]?.setDisplay(nil, placeholder: regionPlaceholder())
        let format = AddressFormats.format(countryCode: code)
        if !format.showPostal {
            values.postalCode = ""
            texts[.postalCode]?.text = ""
        }
        displayedErrors[.region] = nil
        displayedErrors[.postalCode] = nil
        forceShown.remove(.region)
        forceShown.remove(.postalCode)
        applyAddressFormat(resetRegion: true)
        revalidate(changed: .country, trigger: .change)
        if regionTouched {
            blurred.insert(.region)
            forceShown.insert(.region)
            displayedErrors[.region] = CustomerDetailsValidator.validateField(
                .region, values: values, visibility: visibility
            )
        }
        if postalTouched && format.showPostal {
            blurred.insert(.postalCode)
            forceShown.insert(.postalCode)
            displayedErrors[.postalCode] = CustomerDetailsValidator.validateField(
                .postalCode, values: values, visibility: visibility
            )
        }
        renderErrors()
        onContentSizeChange?()
    }

    package func setRegion(_ name: String) {
        values.region = name
        forceShown.remove(.region)
        selects[.region]?.setDisplay(name, placeholder: regionPlaceholder())
        revalidate(changed: .region, trigger: .change)
    }

    package func setPhoneCountry(_ code: String) {
        values.phoneCountry = code
        refreshPhoneCountryDisplay()
        revalidate(changed: .phoneCountry, trigger: .change)
    }

    package func notePickerDismissed(_ field: PersonalDetailsField) {
        blurred.insert(field)
        focusedField = nil
        revalidate(changed: field, trigger: .blur)
    }

    @discardableResult
    package func validateAndShowErrors() -> Bool {
        showErrors = true
        for field in CustomerDetailsValidator.activeFields(visibility: visibility, countryCode: values.country) {
            blurred.insert(field)
        }
        revalidate(changed: nil, trigger: .submit)
        return CustomerDetailsValidator.validate(values, visibility: visibility).isEmpty
    }

    private let fieldHeight: CGFloat = 48
    private let fieldInset: CGFloat = 16

    private var restingFieldBorder: UIColor {
        UIColor(hex: "#E3E1E8") ?? theme.fieldBorder
    }

    private var placeholderColor: UIColor { theme.inputPlaceholder }

    private func build() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = isSpaced ? 16 : 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        if visibility.showsContactSection {
            let errorRow = isSpaced ? nil : makeSectionError()
            contactErrorRow = errorRow
            stack.addArrangedSubview(section(
                heading("personalDetails.contactInfoHeading"),
                body: isSpaced ? padded(spacedContact(), top: 4, bottom: 4) : condensedContact(),
                error: errorRow
            ))
        }
        if visibility.showAddressSection {
            let errorRow = isSpaced ? nil : makeSectionError()
            addressErrorRow = errorRow
            stack.addArrangedSubview(section(
                heading("personalDetails.addressHeading"),
                body: isSpaced ? padded(spacedAddress(), top: 4) : condensedAddress(),
                error: errorRow
            ))
        }
    }

    private func section(_ title: UIView, body: UIView, error: ErrorRowView?) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.addArrangedSubview(title)
        if let error {
            let bodyStack = UIStackView(arrangedSubviews: [body, error])
            bodyStack.axis = .vertical
            bodyStack.spacing = 6
            stack.addArrangedSubview(bodyStack)
        } else {
            stack.addArrangedSubview(body)
        }
        return stack
    }

    private func makeSectionError() -> ErrorRowView {
        let row = ErrorRowView(message: " ", theme: theme)
        row.isHidden = true
        return row
    }

    private func heading(_ key: String) -> UIView {
        let label = UILabel()
        label.attributedText = NSAttributedString(
            string: text(key),
            attributes: isSpaced
                ? theme.titleAttributes(size: 16, weight: .semibold, color: theme.primaryText)
                : theme.titleAttributes(size: 14, weight: .semibold, color: theme.sectionLabelColor)
        )
        return isSpaced ? label : padded(label, top: 4)
    }

    private func padded(_ child: UIView, top: CGFloat = 0, bottom: CGFloat = 0) -> UIView {
        let wrap = UIView()
        child.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(child)
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: wrap.topAnchor, constant: top),
            child.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            child.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -bottom),
        ])
        return wrap
    }

    private func fieldLabel(_ key: String) -> UILabel {
        let label = UILabel()
        setFieldCaption(label, key)
        return label
    }

    private func setFieldCaption(_ label: UILabel?, _ key: String) {
        guard let label else { return }
        label.attributedText = NSAttributedString(
            string: key.isEmpty ? " " : text(key),
            attributes: theme.titleAttributes(
                size: 14,
                weight: .semibold,
                color: theme.sectionLabelColor
            )
        )
    }

    private func spacedContact() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        if visibility.showFullName {
            stack.addArrangedSubview(spacedField(.fullName, label: "personalDetails.fullName", placeholder: "personalDetails.fullNamePlaceholder", keyboard: .default, contentType: .name, cap: .words).view)
        }
        if visibility.showPhone {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8
            row.alignment = .top
            row.distribution = .fill
            let country = spacedSelect(.phoneCountry, label: "personalDetails.phone", placeholder: "personalDetails.phoneCountryPlaceholder")
            let national = spacedField(.phone, label: "", placeholder: "personalDetails.phonePlaceholder", keyboard: .phonePad, contentType: .telephoneNumber, cap: .none)
            row.addArrangedSubview(country.view)
            row.addArrangedSubview(national.view)
            country.view.widthAnchor.constraint(equalToConstant: 130).isActive = true
            national.view.setContentHuggingPriority(.defaultLow, for: .horizontal)
            country.view.setContentHuggingPriority(.required, for: .horizontal)
            stack.addArrangedSubview(row)
        }
        if visibility.showEmail {
            stack.addArrangedSubview(spacedField(.email, label: "personalDetails.email", placeholder: "personalDetails.emailPlaceholder", keyboard: .emailAddress, contentType: .emailAddress, cap: .none).view)
        }
        return stack
    }

    private func spacedAddress() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.addArrangedSubview(spacedSelect(.country, label: "personalDetails.country", placeholder: "personalDetails.countryPlaceholder").view)
        let region = spacedSelect(.region, label: "personalDetails.region.generic", placeholder: "personalDetails.region.genericSelect")
        regionRow = region.view
        regionLabel = region.caption
        stack.addArrangedSubview(region.view)
        stack.addArrangedSubview(spacedField(.address, label: "personalDetails.address", placeholder: "personalDetails.addressPlaceholder", keyboard: .default, contentType: .streetAddressLine1, cap: .words).view)
        let city = spacedField(.city, label: "personalDetails.city", placeholder: "personalDetails.cityPlaceholder", keyboard: .default, contentType: .addressCity, cap: .words)
        let postal = spacedField(.postalCode, label: "personalDetails.postal.postalCode", placeholder: "personalDetails.postal.postalCodePlaceholder", keyboard: .default, contentType: .postalCode, cap: .allCharacters)
        postalSlot = postal.view
        postalLabel = postal.caption
        let row = UIStackView(arrangedSubviews: [city.view, postal.view])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .top
        city.view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        city.view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        postal.view.setContentHuggingPriority(.required, for: .horizontal)
        postal.view.setContentCompressionResistancePriority(.required, for: .horizontal)
        stack.addArrangedSubview(row)
        return stack
    }

    private func condensedContact() -> UIView {
        var rows: [UIView] = []
        func append(_ row: UIView) {
            if !rows.isEmpty { rows.append(hairline()) }
            rows.append(row)
        }
        if visibility.showFullName {
            append(plainField(.fullName, placeholder: "personalDetails.fullNamePlaceholder", keyboard: .default, contentType: .name, cap: .words))
        }
        if visibility.showPhone {
            append(condensedPhoneRow())
        }
        if visibility.showEmail {
            append(plainField(.email, placeholder: "personalDetails.emailPlaceholder", keyboard: .emailAddress, contentType: .emailAddress, cap: .none))
        }
        return grouped(rows, group: contactGroup)
    }

    private func condensedAddress() -> UIView {
        let country = plainSelect(.country, placeholder: "personalDetails.countryPlaceholder")
        let region = plainSelect(.region, placeholder: "personalDetails.region.genericSelect")
        regionRow = region
        let address = plainField(.address, placeholder: "personalDetails.addressPlaceholder", keyboard: .default, contentType: .streetAddressLine1, cap: .words)
        let city = plainField(.city, placeholder: "personalDetails.cityPlaceholder", keyboard: .default, contentType: .addressCity, cap: .words)
        let postal = plainField(.postalCode, placeholder: "personalDetails.postal.postalCodePlaceholder", keyboard: .default, contentType: .postalCode, cap: .allCharacters)
        postalSlot = postal
        let cityRow = UIStackView()
        cityRow.axis = .horizontal
        cityRow.alignment = .fill
        let divider = UIView()
        divider.backgroundColor = restingFieldBorder
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
        postalDivider = divider
        cityRow.addArrangedSubview(city)
        cityRow.addArrangedSubview(divider)
        cityRow.addArrangedSubview(postal)
        let ratio = city.widthAnchor.constraint(equalTo: cityRow.widthAnchor, multiplier: 0.5)
        ratio.isActive = true
        cityPostalRatio = ratio
        let regionLine = hairline()
        regionDivider = regionLine
        return grouped([country, regionLine, region, hairline(), address, hairline(), cityRow], group: addressGroup)
    }

    private func condensedPhoneRow() -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .fill
        let country = plainSelect(.phoneCountry, placeholder: "personalDetails.phoneCountryPlaceholder")
        let divider = UIView()
        divider.backgroundColor = restingFieldBorder
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
        let national = plainField(.phone, placeholder: "personalDetails.phonePlaceholder", keyboard: .phonePad, contentType: .telephoneNumber, cap: .none)
        row.addArrangedSubview(country)
        row.addArrangedSubview(divider)
        row.addArrangedSubview(national)
        country.widthAnchor.constraint(equalToConstant: 130).isActive = true
        return row
    }

    private func grouped(_ rows: [UIView], group: UIView) -> UIView {
        group.backgroundColor = theme.componentBackground
        group.layer.cornerRadius = theme.fieldGroupRadius
        group.layer.borderWidth = theme.borderWidth
        group.layer.borderColor = restingFieldBorder.cgColor
        group.clipsToBounds = true
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        group.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: group.topAnchor),
            stack.leadingAnchor.constraint(equalTo: group.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: group.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: group.bottomAnchor),
        ])
        for row in rows {
            stack.addArrangedSubview(row)
        }
        return group
    }

    private func hairline() -> UIView {
        let line = UIView()
        line.backgroundColor = restingFieldBorder
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    private func spacedField(
        _ field: PersonalDetailsField,
        label key: String,
        placeholder: String,
        keyboard: UIKeyboardType,
        contentType: UITextContentType?,
        cap: UITextAutocapitalizationType
    ) -> LabeledField {
        let wrapper = UIStackView()
        wrapper.axis = .vertical
        wrapper.spacing = 4
        let label = fieldLabel(key)
        let box = fieldBox()
        boxes[field] = box
        let input = makeTextField(field, placeholder: placeholder, keyboard: keyboard, contentType: contentType, cap: cap)
        box.addSubview(input)
        pinField(input, in: box)
        let error = makeErrorLabel()
        errorLabels[field] = error
        wrapper.addArrangedSubview(label)
        wrapper.addArrangedSubview(box)
        wrapper.setCustomSpacing(6, after: box)
        wrapper.addArrangedSubview(error)
        return LabeledField(view: wrapper, caption: label)
    }

    private func spacedSelect(_ field: PersonalDetailsField, label key: String, placeholder: String) -> LabeledField {
        let wrapper = UIStackView()
        wrapper.axis = .vertical
        wrapper.spacing = 4
        let label = fieldLabel(key)
        let box = fieldBox()
        boxes[field] = box
        let select = makeSelect(field, placeholder: placeholder)
        box.addSubview(select)
        pinField(select, in: box)
        let error = makeErrorLabel()
        errorLabels[field] = error
        wrapper.addArrangedSubview(label)
        wrapper.addArrangedSubview(box)
        wrapper.setCustomSpacing(6, after: box)
        wrapper.addArrangedSubview(error)
        return LabeledField(view: wrapper, caption: label)
    }

    private func plainField(
        _ field: PersonalDetailsField,
        placeholder: String,
        keyboard: UIKeyboardType,
        contentType: UITextContentType?,
        cap: UITextAutocapitalizationType
    ) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: fieldHeight).isActive = true
        let input = makeTextField(field, placeholder: placeholder, keyboard: keyboard, contentType: contentType, cap: cap)
        row.addSubview(input)
        pinField(input, in: row)
        return row
    }

    private func plainSelect(_ field: PersonalDetailsField, placeholder: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: fieldHeight).isActive = true
        let select = makeSelect(field, placeholder: placeholder)
        row.addSubview(select)
        pinField(select, in: row)
        return row
    }

    private func fieldBox() -> UIView {
        let box = UIView()
        box.backgroundColor = theme.componentBackground
        box.layer.cornerRadius = theme.fieldGroupRadius
        box.layer.borderWidth = theme.borderWidth
        box.layer.borderColor = restingFieldBorder.cgColor
        box.clipsToBounds = true
        box.translatesAutoresizingMaskIntoConstraints = false
        box.heightAnchor.constraint(equalToConstant: fieldHeight).isActive = true
        return box
    }

    private func makeTextField(
        _ field: PersonalDetailsField,
        placeholder: String,
        keyboard: UIKeyboardType,
        contentType: UITextContentType?,
        cap: UITextAutocapitalizationType
    ) -> UITextField {
        let input = UITextField()
        input.font = theme.font(ofSize: 18, weight: .medium)
        input.textColor = theme.primaryText
        input.keyboardType = keyboard
        input.autocapitalizationType = cap
        input.autocorrectionType = .no
        input.borderStyle = .none
        input.delegate = self
        if let contentType { input.textContentType = contentType }
        input.accessibilityLabel = text(labelKey(field))
        input.addTarget(self, action: #selector(editingChanged(_:)), for: .editingChanged)
        input.translatesAutoresizingMaskIntoConstraints = false
        input.text = storedText(field)
        setPlaceholder(input, key: placeholder)
        texts[field] = input
        return input
    }

    private func makeSelect(_ field: PersonalDetailsField, placeholder: String) -> SelectControl {
        let select = SelectControl(theme: theme)
        select.accessibilityLabel = text(labelKey(field))
        select.addAction(UIAction { [weak self] _ in
            self?.focusedField = field
            self?.onPick?(field)
        }, for: .touchUpInside)
        select.setDisplay(storedSelectTitle(field), placeholder: text(placeholder))
        if field == .phoneCountry {
            select.setFlag(phoneFlag(values.phoneCountry))
        }
        selects[field] = select
        return select
    }

    private func pinField(_ child: UIView, in parent: UIView) {
        child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: fieldInset),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -fieldInset),
            child.topAnchor.constraint(equalTo: parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
        ])
    }

    private func makeErrorLabel() -> UILabel {
        let label = UILabel()
        label.font = theme.font(ofSize: 12, weight: .semibold)
        label.textColor = theme.errorText
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }

    private func applyAddressFormat(resetRegion: Bool) {
        let format = AddressFormats.format(countryCode: values.country)
        let showPostal = format.showPostal
        if !showPostal { cityPostalRatio?.isActive = false }
        regionRow?.isHidden = !format.showRegion
        regionDivider?.isHidden = !format.showRegion
        postalSlot?.isHidden = !showPostal
        postalDivider?.isHidden = !showPostal
        if showPostal { cityPostalRatio?.isActive = true }
        setFieldCaption(regionLabel, format.regionLabelKey)
        setFieldCaption(postalLabel, format.postalLabelKey)
        selects[.region]?.accessibilityLabel = text(format.regionLabelKey)
        if let postal = texts[.postalCode] {
            setPlaceholder(postal, key: format.postalPlaceholderKey)
            postal.accessibilityLabel = text(format.postalLabelKey)
        }
        selects[.region]?.setDisplay(
            resetRegion ? nil : storedSelectTitle(.region),
            placeholder: text(format.regionSelectKey)
        )
        selects[.country]?.setDisplay(storedSelectTitle(.country), placeholder: text("personalDetails.countryPlaceholder"))
        refreshPhoneCountryDisplay()
    }

    private func regionPlaceholder() -> String {
        text(AddressFormats.format(countryCode: values.country).regionSelectKey)
    }

    private func storedText(_ field: PersonalDetailsField) -> String {
        switch field {
        case .fullName: return values.fullName
        case .phone: return values.phoneNational
        case .email: return values.email
        case .address: return values.address
        case .city: return values.city
        case .postalCode: return values.postalCode
        default: return ""
        }
    }

    private func storedSelectTitle(_ field: PersonalDetailsField) -> String? {
        switch field {
        case .phoneCountry:
            return values.phoneCountry.isEmpty ? nil : phoneCountryTitle(values.phoneCountry)
        case .country:
            guard let country = Countries.byCode(values.country) else { return nil }
            return Countries.localizedName(country, locale: locale)
        case .region:
            return values.region.isEmpty ? nil : values.region
        default:
            return nil
        }
    }

    private func phoneCountryTitle(_ code: String) -> String {
        guard let country = Countries.byCode(code) else { return code }
        return "+\(country.dialCode)"
    }

    private func phoneFlag(_ code: String) -> String? {
        guard let country = Countries.byCode(code) else { return nil }
        let flag = Countries.flagEmoji(code: country.code)
        return flag.isEmpty ? nil : flag
    }

    private func refreshPhoneCountryDisplay() {
        selects[.phoneCountry]?.setFlag(phoneFlag(values.phoneCountry))
        selects[.phoneCountry]?.setDisplay(
            storedSelectTitle(.phoneCountry),
            placeholder: text("personalDetails.phoneCountryPlaceholder")
        )
    }

    private func labelKey(_ field: PersonalDetailsField) -> String {
        switch field {
        case .fullName: return "personalDetails.fullName"
        case .phoneCountry: return "personalDetails.phoneCountryCode"
        case .phone: return "personalDetails.phone"
        case .email: return "personalDetails.email"
        case .country: return "personalDetails.country"
        case .region: return AddressFormats.format(countryCode: values.country).regionLabelKey
        case .address: return "personalDetails.address"
        case .city: return "personalDetails.city"
        case .postalCode: return AddressFormats.format(countryCode: values.country).postalLabelKey
        }
    }

    private func setPlaceholder(_ field: UITextField, key: String) {
        field.attributedPlaceholder = NSAttributedString(
            string: text(key),
            attributes: [
                .foregroundColor: placeholderColor,
                .font: theme.font(ofSize: 18, weight: .regular),
                .kern: -0.18 * theme.fontScale,
            ]
        )
    }

    private func text(_ key: String) -> String {
        Strings.text(key, locale: locale)
    }

    @objc private func editingChanged(_ field: UITextField) {
        guard let key = texts.first(where: { $0.value === field })?.key else { return }
        let raw = field.text ?? ""
        switch key {
        case .fullName: values.fullName = raw
        case .phone: values.phoneNational = raw
        case .email: values.email = raw
        case .address: values.address = raw
        case .city: values.city = raw
        case .postalCode: values.postalCode = raw
        default: break
        }
        revalidate(changed: key, trigger: .change)
    }

    package func textFieldDidBeginEditing(_ textField: UITextField) {
        focusedField = texts.first(where: { $0.value === textField })?.key
        updateBorders()
        onFocus?(textField)
    }

    package func textFieldDidEndEditing(_ textField: UITextField) {
        guard let field = texts.first(where: { $0.value === textField })?.key else { return }
        blurred.insert(field)
        if focusedField == field { focusedField = nil }
        revalidate(changed: field, trigger: .blur)
    }

    private enum Trigger { case change, blur, submit }

    private func revalidate(changed: PersonalDetailsField?, trigger: Trigger) {
        let current = CustomerDetailsValidator.validate(values, visibility: visibility)
        switch trigger {
        case .submit:
            displayedErrors = current
            forceShown = Set(forceShown.filter { current[$0] != nil })
        case .blur:
            if let changed {
                displayedErrors[changed] = current[changed]
                if current[changed] == nil { forceShown.remove(changed) }
            }
        case .change:
            for field in PersonalDetailsField.allCases {
                if CardValidationDisplay.shouldRefreshDisplayedErrorOnChange(
                    mode: validationMode,
                    fieldBlurred: blurred.contains(field),
                    submitAttempted: showErrors
                ) {
                    displayedErrors[field] = current[field]
                    if current[field] == nil { forceShown.remove(field) }
                }
            }
        }
        renderErrors()
    }

    private func visibleError(_ field: PersonalDetailsField) -> PersonalDetailsFieldError? {
        guard let error = displayedErrors[field] else { return nil }
        if forceShown.contains(field) { return error }
        guard CardValidationDisplay.shouldShowError(
            mode: validationMode,
            fieldBlurred: blurred.contains(field),
            submitAttempted: showErrors
        ) else { return nil }
        return error
    }

    private func renderErrors() {
        if isSpaced {
            for field in PersonalDetailsField.allCases {
                let error = visibleError(field)
                errorLabels[field]?.text = error?.localizedMessage(locale: locale)
                errorLabels[field]?.isHidden = error == nil
            }
        } else {
            applySectionError(contactErrorRow, fields: CustomerDetailsValidator.contactOrder)
            applySectionError(addressErrorRow, fields: CustomerDetailsValidator.addressOrder(countryCode: values.country))
        }
        updateBorders()
        let errorVisible = hasVisibleError()
        if errorVisible != lastErrorVisible {
            lastErrorVisible = errorVisible
            onContentSizeChange?()
        }
    }

    private func applySectionError(_ row: ErrorRowView?, fields: [PersonalDetailsField]) {
        guard let row else { return }
        let message = fields.compactMap { visibleError($0)?.localizedMessage(locale: locale) }.first
        row.setMessage(message ?? "")
        row.isHidden = message == nil
    }

    private func hasVisibleError() -> Bool {
        CustomerDetailsValidator.activeFields(visibility: visibility, countryCode: values.country)
            .contains { visibleError($0) != nil }
    }

    private func updateBorders() {
        if isSpaced {
            for (field, box) in boxes {
                let invalid = visibleError(field) != nil
                let isFocused = focusedField == field
                if invalid {
                    box.layer.borderWidth = theme.fieldStrokeWidth(hasError: true)
                    box.layer.borderColor = theme.errorBorder.cgColor
                } else if isFocused {
                    box.layer.borderWidth = theme.fieldStrokeWidth(hasError: false)
                    box.layer.borderColor = theme.primary.cgColor
                } else {
                    box.layer.borderWidth = theme.fieldStrokeWidth(hasError: false)
                    box.layer.borderColor = restingFieldBorder.cgColor
                }
            }
            return
        }
        paint(contactGroup, fields: CustomerDetailsValidator.contactOrder)
        paint(addressGroup, fields: CustomerDetailsValidator.addressOrder(countryCode: values.country))
    }

    private func paint(_ group: UIView, fields: [PersonalDetailsField]) {
        let invalid = fields.contains { visibleError($0) != nil }
        let isFocused = fields.contains { focusedField == $0 }
        if invalid {
            group.layer.borderWidth = theme.fieldStrokeWidth(hasError: true)
            group.layer.borderColor = theme.errorBorder.cgColor
        } else if isFocused {
            group.layer.borderWidth = theme.fieldStrokeWidth(hasError: false)
            group.layer.borderColor = theme.primary.cgColor
        } else {
            group.layer.borderWidth = theme.fieldStrokeWidth(hasError: false)
            group.layer.borderColor = restingFieldBorder.cgColor
        }
    }
}

private struct LabeledField {
    let view: UIView
    let caption: UILabel
}

private final class SelectControl: UIControl {
    private let label = UILabel()
    private let flagLabel = UILabel()
    private let chevron = UIImageView()
    private let theme: CheckoutTheme
    private var placeholder = ""
    private var labelLeading: NSLayoutConstraint!

    init(theme: CheckoutTheme) {
        self.theme = theme
        super.init(frame: .zero)
        label.font = theme.font(ofSize: 18, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        flagLabel.font = theme.font(ofSize: 18, weight: .regular)
        flagLabel.textAlignment = .center
        flagLabel.isHidden = true
        flagLabel.translatesAutoresizingMaskIntoConstraints = false
        chevron.image = EmbeddedAssets.image(named: "chevron-down")?.withRenderingMode(.alwaysTemplate)
        chevron.tintColor = theme.mutedIcon
        chevron.translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityTraits = .button
        addSubview(flagLabel)
        addSubview(label)
        addSubview(chevron)
        labelLeading = label.leadingAnchor.constraint(equalTo: leadingAnchor)
        NSLayoutConstraint.activate([
            flagLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            flagLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            flagLabel.widthAnchor.constraint(equalToConstant: 24),
            flagLabel.heightAnchor.constraint(equalToConstant: 24),
            labelLeading,
            label.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 8),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setFlag(_ flag: String?) {
        let shown = flag?.isEmpty == false
        flagLabel.isHidden = !shown
        flagLabel.text = flag
        labelLeading.constant = shown ? 32 : 0
    }

    func setDisplay(_ value: String?, placeholder: String) {
        self.placeholder = placeholder
        let shown = (value?.isEmpty == false) ? value! : placeholder
        let filled = value?.isEmpty == false
        accessibilityValue = filled ? value : nil
        label.attributedText = NSAttributedString(
            string: shown,
            attributes: [
                .font: theme.font(ofSize: 18, weight: filled ? .medium : .regular),
                .foregroundColor: filled ? theme.primaryText : (UIColor(hex: "#D1CDDB") ?? theme.placeholderText),
            ]
        )
    }
}
