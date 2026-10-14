import SafariServices
import UIKit

/// How a 3DS challenge presentation ended.
package enum ThreeDSChallengeEnd: Equatable {
    /// The shopper tapped Close, or Cancel on the bank-app waiting screen.
    /// `bankHandoff` is also true when the app went to the background while the challenge was showing.
    case userCanceled(bankHandoff: Bool)
    /// The poll asked the controller to close.
    case closedByPoll
    /// No window, the host could not present, or the controller was already started.
    case unavailable
    /// The first hop was cleartext or a blocked system scheme.
    case rejectedRedirect
}

package enum ThreeDSSessionOutcome {
    /// A programmatic dismiss wins, so Safari finishing after the poll closes the page is not a user cancel.
    /// A challenge page can open the bank app after the first load, which only shows up as the app leaving the foreground.
    package static func resolve(
        programmaticDismiss: Bool,
        bankHandoff: Bool = false,
        backgrounded: Bool = false
    ) -> ThreeDSChallengeEnd {
        if programmaticDismiss {
            return .closedByPoll
        }
        return .userCanceled(bankHandoff: bankHandoff || backgrounded)
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
    private let locale: String
    private weak var host: UIViewController?
    private var safari: SFSafariViewController?
    private var handoffController: ThreeDSBankHandoffViewController?
    private var backgroundObserver: NSObjectProtocol?
    private var programmaticDismiss = false
    private var bankHandoff = false
    private var backgrounded = false
    private var didStart = false

    package init(locale: String) {
        self.locale = locale
        super.init()
    }

    deinit {
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
    }

    /// Cancelling the calling task acts as `dismiss()`, even before a dismiss could find this controller.
    package func present(url: URL, from host: UIViewController?) async -> ThreeDSChallengeEnd {
        await withTaskCancellationHandler {
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
                    guard Self.present(safari, over: host) else {
                        self.resume.resume(.unavailable)
                        return
                    }
                    self.safari = safari
                    self.observeBackground()
                }
            }
        } onCancel: {
            self.dismiss()
        }
    }

    /// Poll won. Resume before dismiss so a following `safariViewControllerDidFinish` cannot look like a user cancel.
    package func dismiss() {
        let work = {
            self.setProgrammaticDismiss()
            self.resume.resume(.closedByPoll)
            self.stopObservingBackground()
            Self.close(self.safari)
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
        stopObservingBackground()
        let end = ThreeDSSessionOutcome.resolve(
            programmaticDismiss: isProgrammaticDismiss(),
            backgrounded: isBackgrounded()
        )
        resume.resume(end)
    }

    /// HTTPS stays in this Safari controller.
    /// A blocked scheme fails the challenge closed. Any other scheme is offered to the shopper as a bank app.
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
                self.confirmOpenExternally(url, over: controller)
            }
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    /// Returns false when UIKit ignored the request, for example because the host is already presenting.
    @discardableResult
    static func present(_ controller: UIViewController, over host: UIViewController) -> Bool {
        let top = topmost(from: host)
        top.present(controller, animated: true)
        return controller.presentingViewController != nil
    }

    static func topmost(from root: UIViewController) -> UIViewController {
        var top = root
        while let next = top.presentedViewController, !next.isBeingDismissed {
            top = next
        }
        return top
    }

    private func confirmOpenExternally(_ url: URL, over controller: UIViewController) {
        guard !isProgrammaticDismiss() else { return }
        let alert = UIAlertController(
            title: Strings.text("threeds.openBankApp.title", locale: locale),
            message: Strings.text("threeds.openBankApp.message", locale: locale),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: Strings.text("sheet.cancel", locale: locale),
            style: .cancel
        ) { [weak self] _ in
            self?.cancelChallenge()
        })
        alert.addAction(UIAlertAction(
            title: Strings.text("threeds.openBankApp.open", locale: locale),
            style: .default
        ) { [weak self] _ in
            UIApplication.shared.open(url, options: [:]) { accepted in
                if accepted {
                    self?.presentBankHandoff()
                } else {
                    self?.cancelChallenge()
                }
            }
        })
        Self.present(alert, over: controller)
    }

    /// Safari is left on an unloadable custom-scheme page, so the challenge cannot continue.
    private func cancelChallenge() {
        guard !isProgrammaticDismiss() else { return }
        resume.resume(ThreeDSSessionOutcome.resolve(programmaticDismiss: false, backgrounded: isBackgrounded()))
        stopObservingBackground()
        Self.close(safari)
        safari = nil
    }

    private func rejectRedirect() {
        setProgrammaticDismiss()
        resume.resume(.rejectedRedirect)
        stopObservingBackground()
        Self.close(safari)
        safari = nil
    }

    /// Called on Safari itself, `dismiss` only removes what Safari presents, such as the bank-app alert.
    static func close(_ safari: UIViewController?, animated: Bool = true) {
        guard let safari else { return }
        (safari.presentingViewController ?? safari).dismiss(animated: animated)
    }

    private func presentBankHandoff() {
        guard !isProgrammaticDismiss(), handoffController == nil else { return }
        setBankHandoff(true)
        stopObservingBackground()
        let waiting = ThreeDSBankHandoffViewController(locale: locale)
        waiting.onCancel = { [weak self] in
            self?.cancelBankHandoff()
        }
        let show = { [weak self] in
            guard let self, !self.isProgrammaticDismiss() else { return }
            guard let host = self.host, host.view.window != nil, !host.isBeingDismissed,
                  Self.present(waiting, over: host) else {
                self.resume.resume(.userCanceled(bankHandoff: true))
                return
            }
            self.handoffController = waiting
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

    private func observeBackground() {
        guard backgroundObserver == nil else { return }
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setBackgrounded()
        }
    }

    private func stopObservingBackground() {
        guard let backgroundObserver else { return }
        NotificationCenter.default.removeObserver(backgroundObserver)
        self.backgroundObserver = nil
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

    private func setBackgrounded() {
        stateLock.lock()
        backgrounded = true
        stateLock.unlock()
    }

    private func isBackgrounded() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return backgrounded
    }
}
