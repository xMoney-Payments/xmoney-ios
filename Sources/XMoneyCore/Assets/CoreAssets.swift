import UIKit

package enum CoreAssets {
    package static let bundle: Bundle = {
        #if SWIFT_PACKAGE && !SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE
        return .module
        #else
        let bundleNames = [
            "XMoneyPaymentSheet_XMoneyCore",
            "XMoneyCore",
        ]
        let roots = [Bundle(for: BundleToken.self), Bundle.main]
        for root in roots {
            if root.url(forResource: "XMoneyCoreAssets", withExtension: "car") != nil {
                return root
            }
            for name in bundleNames {
                if let url = root.url(forResource: name, withExtension: "bundle"),
                   let found = Bundle(url: url) {
                    return found
                }
            }
        }
        return Bundle(for: BundleToken.self)
        #endif
    }()

    package static func image(named: String, traitCollection: UITraitCollection? = nil) -> UIImage? {
        UIImage(named: named, in: bundle, compatibleWith: traitCollection)
    }
}

private final class BundleToken {}
