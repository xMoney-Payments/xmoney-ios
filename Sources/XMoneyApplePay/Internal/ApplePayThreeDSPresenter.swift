import UIKit
import XMoneyCore

final class ApplePayThreeDSPresenter: ThreeDSPresenter {
    private weak var host: UIViewController?
    private var threeDSController: UIViewController?
    private let resume = ThreeDSResume()

    init(host: UIViewController) {
        self.host = host
    }

    func presentThreeDS(url: URL, returnURLMatcher: @escaping (URL) -> Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                guard let host = self.host else {
                    continuation.resume(returning: false)
                    return
                }
                self.resume.arm(continuation)
                let threeDS = ThreeDSViewController(
                    url: url,
                    returnURLMatcher: returnURLMatcher,
                    completion: { [weak self] success in
                        self?.resume.resume(success)
                        self?.threeDSController = nil
                    }
                )
                self.threeDSController = threeDS
                host.present(threeDS, animated: true)
            }
        }
    }

    func dismissThreeDS() {
        Task { @MainActor in
            self.threeDSController?.dismiss(animated: true)
            self.threeDSController = nil
            self.resume.resume(true)
        }
    }
}
