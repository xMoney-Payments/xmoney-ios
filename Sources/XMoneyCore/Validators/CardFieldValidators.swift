import Foundation

package enum CardFieldValidators {
    private static let validator = CardNumberValidator()

    package enum FieldError: Equatable {
        case cardNumberRequired
        case cardNumberUnsupported
        case cardNumberTooShort
        case cardNumberWrongLength
        case cardNumberInvalid
        case expDateRequired
        case expDateInvalidFormat
        case expDateInvalidMonth
        case cardExpired
        case cvvRequired
        case cvvInvalid
        case cardHolderNameRequired
        case cardHolderNameNoDigits
        case cardHolderNameInvalidChars

        var messageKey: String {
            switch self {
            case .cardNumberRequired: return "errors.cardNumberRequired"
            case .cardNumberUnsupported: return "errors.cardNumberUnsupported"
            case .cardNumberTooShort: return "errors.cardNumberTooShort"
            case .cardNumberWrongLength: return "errors.cardNumberWrongLength"
            case .cardNumberInvalid: return "errors.cardNumberInvalid"
            case .expDateRequired: return "errors.expDateRequired"
            case .expDateInvalidFormat: return "errors.expDateInvalidFormat"
            case .expDateInvalidMonth: return "errors.expDateInvalidMonth"
            case .cardExpired: return "errors.cardExpired"
            case .cvvRequired: return "errors.cvvRequired"
            case .cvvInvalid: return "errors.cvvInvalid"
            case .cardHolderNameRequired: return "errors.cardHolderNameRequired"
            case .cardHolderNameNoDigits: return "errors.cardHolderNameNoDigits"
            case .cardHolderNameInvalidChars: return "errors.cardHolderNameInvalidChars"
            }
        }

        package func localizedMessage(locale: String) -> String {
            Strings.text(messageKey, locale: locale)
        }
    }

    package static func detectBrand(_ rawNumber: String) -> String? {
        validator.detect(normalizeDigits(rawNumber))
    }

    package static func validateCardNumber(_ rawNumber: String) -> FieldError? {
        let number = normalizeDigits(rawNumber)
        if number.isEmpty { return .cardNumberRequired }
        guard let brand = validator.detect(number) else {
            if number.count < 13 { return .cardNumberTooShort }
            return .cardNumberUnsupported
        }
        if number.count < validator.minLength(number) { return .cardNumberTooShort }
        if !validator.validateLength(number, brand: brand) { return .cardNumberWrongLength }
        if !validator.checkLuhn(number) { return .cardNumberInvalid }
        return nil
    }

    package static func validateExpiry(month: String, year: String) -> FieldError? {
        if month.isEmpty || year.isEmpty { return .expDateRequired }
        guard let mm = Int(month), let yy = Int(year) else { return .expDateInvalidFormat }
        if mm < 1 || mm > 12 { return .expDateInvalidMonth }

        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        let currentYear = (now.year ?? 0) % 100
        let currentMonth = now.month ?? 0
        if yy < currentYear || (yy == currentYear && mm < currentMonth) {
            return .cardExpired
        }
        return nil
    }

    package static func validateCVV(_ cvv: String) -> FieldError? {
        if cvv.isEmpty { return .cvvRequired }
        let digits = normalizeDigits(cvv)
        if digits.count < 3 || digits.count > 4 { return .cvvInvalid }
        return nil
    }

    package static func validateHolderName(_ name: String?) -> FieldError? {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .cardHolderNameRequired }
        if trimmed.rangeOfCharacter(from: .decimalDigits) != nil { return .cardHolderNameNoDigits }
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzÀ-ÿ .'-")
        if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return .cardHolderNameInvalidChars
        }
        return trimmed.count <= 250 ? nil : .cardHolderNameInvalidChars
    }

    // MARK: - Formatting

    package static func normalizeDigits(_ value: String) -> String {
        value.filter { $0.isNumber }
    }

    package static func formatCardNumber(_ raw: String) -> (formatted: String, raw: String, brand: String?) {
        let digits = normalizeDigits(raw)
        let brand = validator.detect(digits)
        let maxLen = validator.maxLength(digits)
        let capped = String(digits.prefix(maxLen))
        let grouped = stride(from: 0, to: capped.count, by: 4).map { start -> String in
            let s = capped.index(capped.startIndex, offsetBy: start)
            let e = capped.index(s, offsetBy: 4, limitedBy: capped.endIndex) ?? capped.endIndex
            return String(capped[s..<e])
        }.joined(separator: " ")
        return (grouped, capped, brand)
    }

    package static func formatExpiry(_ raw: String) -> String {
        let digits = normalizeDigits(raw)
        guard !digits.isEmpty else { return "" }
        var month = String(digits.prefix(2))
        if month.count == 2, let m = Int(month), m > 12 { month = "12" }
        if digits.count <= 2 { return month }
        let year = String(digits.dropFirst(2).prefix(2))
        return "\(month) / \(year)"
    }
}
