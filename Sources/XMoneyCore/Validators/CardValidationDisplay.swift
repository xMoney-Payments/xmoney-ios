import Foundation

/// When card-field errors are visible and whether they update while typing.
/// Matches React Hook Form `mode` (plus live re-validate after Pay).
package enum CardValidationDisplay {
    package static func shouldShowError(
        mode: PaymentConfig.ValidationMode,
        fieldBlurred: Bool,
        submitAttempted: Bool
    ) -> Bool {
        switch mode {
        case .onChange:
            return true
        case .onSubmit:
            return submitAttempted
        case .onBlur, .onTouched:
            return submitAttempted || fieldBlurred
        }
    }

    package static func shouldRefreshDisplayedErrorOnChange(
        mode: PaymentConfig.ValidationMode,
        fieldBlurred: Bool,
        submitAttempted: Bool
    ) -> Bool {
        switch mode {
        case .onChange:
            return true
        case .onTouched:
            return submitAttempted || fieldBlurred
        case .onBlur, .onSubmit:
            return submitAttempted
        }
    }
}
