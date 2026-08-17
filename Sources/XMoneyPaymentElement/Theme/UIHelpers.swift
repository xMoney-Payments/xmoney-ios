import UIKit
#if !COCOAPODS
import XMoneyCore
#endif

package enum UIHelpers {
    package static func isDarkMode(config: PaymentConfig, traitCollection: UITraitCollection?) -> Bool {
        switch config.options.style {
        case .alwaysLight: return false
        case .alwaysDark: return true
        case .automatic: return traitCollection?.userInterfaceStyle == .dark
        }
    }

    package static func overrideStyle(for config: PaymentConfig) -> UIUserInterfaceStyle {
        switch config.options.style {
        case .alwaysLight: return .light
        case .alwaysDark: return .dark
        case .automatic: return .unspecified
        }
    }
}
