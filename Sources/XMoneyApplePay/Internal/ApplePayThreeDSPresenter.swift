import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

final class ApplePayThreeDSPresenter: ThreeDSPresenter {
    private weak var host: UIViewController?
    private var threeDSSession: ThreeDSSafariController?
    private let locale: String

    init(host: UIViewController, locale: String) {
        self.host = host
        self.locale = locale
    }

    func presentThreeDS(url: URL) async -> ThreeDSChallengeEnd {
        let (session, host): (ThreeDSSafariController, UIViewController?) = await MainActor.run {
            let session = ThreeDSSafariController(locale: self.locale)
            self.threeDSSession = session
            return (session, self.host)
        }
        return await session.present(url: url, from: host)
    }

    func dismissThreeDS() {
        Task { @MainActor in
            self.threeDSSession?.dismiss()
            self.threeDSSession = nil
        }
    }
}
