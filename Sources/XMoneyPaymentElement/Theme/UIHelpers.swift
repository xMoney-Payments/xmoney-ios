import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

package enum UIHelpers {
    package static func isDarkMode(config: PaymentConfig, traitCollection: UITraitCollection?) -> Bool {
        switch config.options.appearance.colorScheme {
        case .light: return false
        case .dark: return true
        case .automatic: return traitCollection?.userInterfaceStyle == .dark
        }
    }

    package static func overrideStyle(for config: PaymentConfig) -> UIUserInterfaceStyle {
        switch config.options.appearance.colorScheme {
        case .light: return .light
        case .dark: return .dark
        case .automatic: return .unspecified
        }
    }

    package static func contentSizeScale(_ traits: UITraitCollection?) -> CGFloat {
        let baseTraits = UITraitCollection(preferredContentSizeCategory: .large)
        let base = UIFont.preferredFont(forTextStyle: .body, compatibleWith: baseTraits).pointSize
        let current = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits).pointSize
        guard base > 0 else { return 1 }
        return current / base
    }

    package static func increasedContrast(_ traits: UITraitCollection?) -> Bool {
        traits?.accessibilityContrast == .high
    }

    package static func traitsAffectingThemeChanged(
        _ current: UITraitCollection,
        from previous: UITraitCollection?
    ) -> Bool {
        guard let previous else { return false }
        return current.hasDifferentColorAppearance(comparedTo: previous)
            || current.preferredContentSizeCategory != previous.preferredContentSizeCategory
            || current.accessibilityContrast != previous.accessibilityContrast
    }
}
