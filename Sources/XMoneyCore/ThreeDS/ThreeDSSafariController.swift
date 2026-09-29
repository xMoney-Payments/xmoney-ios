import SafariServices
import UIKit

/// How a 3DS challenge presentation ended.
package enum ThreeDSChallengeEnd: Equatable {
    /// The shopper tapped Close, or Cancel on the bank-app waiting screen.
    case userCanceled(bankHandoff: Bool)
    /// The poll asked the controller to close.
    case closedByPoll
    /// No window, or the controller was already started.
    case unavailable
    /// The first hop was cleartext or a blocked system scheme.
    case rejectedRedirect
}

package enum ThreeDSSessionOutcome {
    /// A programmatic dismiss wins, so Safari finishing after the poll closes the page is not a user cancel.
    package static func resolve(programmaticDismiss: Bool, bankHandoff: Bool = false) -> ThreeDSChallengeEnd {
        if programmaticDismiss {
            return .closedByPoll
        }
        return .userCanceled(bankHandoff: bankHandoff)
    }
}

/// Hosts the 3DS redirect chain in an `SFSafariViewController`.
///
/// The controller is presented full screen. Covering its view stops the page from loading.
/// Mobile does not treat any redirect, including the merchant return URL, as completion.
/// The transaction poll closes the controller.
package final class ThreeDSSafariController: NSObject, SFSafariViewControllerDelegate {
    private let resume = ThreeDSResume<ThreeDSChallengeEnd>()
    private let stateLock = NSLock()
    private weak var host: UIViewController?
    private var safari: SFSafariViewController?
    private var handoffController: ThreeDSBankHandoffViewController?
    private var programmaticDismiss = false
    private var bankHandoff = false
    private var didStart = false

    package func present(url: URL, from host: UIViewController?) async -> ThreeDSChallengeEnd {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let host, host.view.window != nil, !host.isBeingDismissed else {
                    continuation.resume(returning: .unavailable)
                    return
                }
                guard !self.didStart else {
                    continuation.resume(returning: .unavailable)
                    return
                }
                self.didStart = true
                self.host = host
                self.resume.arm(continuation)
                if self.isProgrammaticDismiss() {
                    self.resume.resume(.closedByPoll)
                    return
                }

                let safari = SFSafariViewController(url: url)
                safari.delegate = self
                safari.dismissButtonStyle = .close
                safari.modalPresentationStyle = .fullScreen
                self.safari = safari
                host.present(safari, animated: true)
            }
        }
    }

    /// Poll won. Resume before dismiss so a following `safariViewControllerDidFinish` cannot look like a user cancel.
    package func dismiss() {
        let work = {
            self.setProgrammaticDismiss()
            self.resume.resume(.closedByPoll)
            self.safari?.dismiss(animated: true)
            self.safari = nil
            self.handoffController?.dismiss(animated: true)
            self.handoffController = nil
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    package func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        if isBankHandoff() { return }
        let end = ThreeDSSessionOutcome.resolve(programmaticDismiss: isProgrammaticDismiss())
        resume.resume(end)
    }

    /// HTTPS stays in this Safari controller.
    /// A blocked scheme fails the challenge closed. Any other scheme is offered to the system as a bank app.
    package func safariViewController(
        _ controller: SFSafariViewController,
        initialLoadDidRedirectTo url: URL
    ) {
        let decision = ThreeDSRedirectPolicy.decide(url)
        let work = {
            switch decision {
            case .stayInBrowser:
                return
            case .reject:
                self.rejectRedirect()
            case .openExternally:
                UIApplication.shared.open(url, options: [:]) { accepted in
                    guard accepted else { return }
                    self.presentBankHandoff()
                }
            }
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private func rejectRedirect() {
        setProgrammaticDismiss()
        resume.resume(.rejectedRedirect)
        safari?.dismiss(animated: true)
        safari = nil
    }

    private func presentBankHandoff() {
        guard !isProgrammaticDismiss(), handoffController == nil else { return }
        setBankHandoff(true)
        let waiting = ThreeDSBankHandoffViewController()
        waiting.onCancel = { [weak self] in
            self?.cancelBankHandoff()
        }
        let show = { [weak self] in
            guard let self, !self.isProgrammaticDismiss() else { return }
            guard let host = self.host, host.view.window != nil, !host.isBeingDismissed else { return }
            self.handoffController = waiting
            host.present(waiting, animated: true)
        }
        if let safari {
            self.safari = nil
            safari.dismiss(animated: true, completion: show)
        } else {
            show()
        }
    }

    private func cancelBankHandoff() {
        resume.resume(.userCanceled(bankHandoff: true))
        handoffController?.dismiss(animated: true)
        handoffController = nil
    }

    private func setProgrammaticDismiss() {
        stateLock.lock()
        programmaticDismiss = true
        stateLock.unlock()
    }

    private func isProgrammaticDismiss() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return programmaticDismiss
    }

    private func setBankHandoff(_ value: Bool) {
        stateLock.lock()
        bankHandoff = value
        stateLock.unlock()
    }

    private func isBankHandoff() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return bankHandoff
    }
}
