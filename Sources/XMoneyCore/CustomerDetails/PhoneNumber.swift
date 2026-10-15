import Foundation

/// National phone rules from `phone-validation.utils.js`.
/// One leading 0 is dropped only when 6–15 digits remain. A leading `+` is
/// not formatting, so a pasted international number stays invalid.
package enum PhoneNumber {
    package static let minDigits = 6
    package static let maxDigits = 15

    package static func normalizeNationalDigits(_ nationalInput: String) -> String {
        let withoutFormatting = nationalInput.replacingOccurrences(
            of: "[\\s\\-().]",
            with: "",
            options: .regularExpression
        )
        return withoutFormatting.filter(\.isNumber)
    }

    /// Drops one leading 0 only when 6–15 digits remain.
    package static func formatNationalForPayload(_ digits: String) -> String {
        guard !digits.isEmpty else { return "" }
        guard digits.hasPrefix("0") else { return digits }
        let stripped = String(digits.dropFirst())
        if stripped.count >= minDigits && stripped.count <= maxDigits {
            return stripped
        }
        return digits
    }

    package static func isNationalValid(_ nationalInput: String) -> Bool {
        let trimmed = nationalInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let withoutFormatting = trimmed.replacingOccurrences(
            of: "[\\s\\-().]",
            with: "",
            options: .regularExpression
        )
        guard withoutFormatting.allSatisfy(\.isNumber), !withoutFormatting.isEmpty else { return false }
        return withoutFormatting.count >= minDigits && withoutFormatting.count <= maxDigits
    }

    /// `+{dial}{national}`. Empty when either part is missing.
    package static func payload(dialCode: String?, nationalInput: String) -> String {
        guard let dialCode, !dialCode.isEmpty else { return "" }
        let national = formatNationalForPayload(normalizeNationalDigits(nationalInput))
        guard !national.isEmpty else { return "" }
        return "+\(dialCode)\(national)"
    }
}
