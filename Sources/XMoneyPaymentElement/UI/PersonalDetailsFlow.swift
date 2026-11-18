import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

/// Builds the personal-details page and writes Continue / Back into `progress`.
/// The caller decides how the page is shown.
package enum PersonalDetailsFlow {
    package static func make(
        config: PaymentConfig,
        visibility: CustomerDetailsVisibility,
        progress: PersonalDetailsProgress,
        presentation: PersonalDetailsPresentation = .sheet,
        onFinished: @escaping () -> Void
    ) -> PersonalDetailsViewController {
        let details = PersonalDetailsViewController(
            config: config,
            visibility: visibility,
            initialValues: progress.seed,
            presentation: presentation
        )
        details.onBack = { values in
            progress.leave(with: values, visibility: visibility)
            onFinished()
        }
        details.onCommit = { values in
            progress.commit(values)
            onFinished()
        }
        return details
    }
}
