import UIKit

/// Waits until a view is in a window with a real size and its backing store has
/// been created, then waits for one display-link tick so the content commits.
/// Gives up after a short monotonic cap so a view that never paints cannot
/// hold the loading surface open.
///
/// Returns `false` without waiting when the view is not in a window (or leaves
/// it, or the task is cancelled). Callers defer their reveal until the view is
/// back in a window. A timeout returns `true`: the wait is over.
@MainActor
package enum SurfacePaint {
    @discardableResult
    package static func waitUntilButtonDrawn(_ button: UIView, timeout: TimeInterval = 2) async -> Bool {
        await wait(button, timeout: timeout) { view in
            view.layer.displayIfNeeded()
            return hasBackingStore(view.layer)
        } onTimeout: {
            #if DEBUG
            NSLog("XMoney: Apple Pay button did not paint within %.1f seconds; continuing.", timeout)
            #endif
        }
    }

    @discardableResult
    package static func waitUntilLaidOut(_ view: UIView, timeout: TimeInterval = 2) async -> Bool {
        await wait(view, timeout: timeout) { _ in true } onTimeout: {}
    }

    private static func wait(
        _ view: UIView,
        timeout: TimeInterval,
        isPainted: (UIView) -> Bool,
        onTimeout: () -> Void
    ) async -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while ProcessInfo.processInfo.systemUptime < deadline {
            if Task.isCancelled || view.window == nil { return false }
            view.layoutIfNeeded()
            if view.bounds.width > 1, view.bounds.height > 1, isPainted(view) {
                await DisplayTick().wait()
                return view.window != nil && !Task.isCancelled
            }
            await DisplayTick().wait()
        }
        onTimeout()
        return true
    }

    /// PassKit may draw into its own layer or into sublayers, depending on the
    /// OS and initializer.
    private static func hasBackingStore(_ layer: CALayer) -> Bool {
        if layer.contents != nil { return true }
        return layer.sublayers?.contains(where: hasBackingStore) ?? false
    }
}

/// One `CADisplayLink` callback, with a short fallback for environments where
/// the display link does not fire (headless test hosts).
@MainActor
private final class DisplayTick: NSObject {
    private var link: CADisplayLink?
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.continuation = continuation
            let link = CADisplayLink(target: self, selector: #selector(fire))
            link.add(to: .main, forMode: .common)
            self.link = link
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000)
                self.fire()
            }
        }
    }

    @objc private func fire() {
        link?.invalidate()
        link = nil
        continuation?.resume()
        continuation = nil
    }
}
