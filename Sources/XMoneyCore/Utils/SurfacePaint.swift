import UIKit

/// Waits until a view is in a window with a real size and its backing store has
/// been created. Then allows one display interval for the content to commit.
/// Gives up after a short wall-clock cap so a view that never lands in a window
/// cannot hold the loading surface open.
@MainActor
package enum SurfacePaint {
    package static func waitUntilButtonDrawn(_ button: UIView, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if Task.isCancelled { return }
            button.layoutIfNeeded()
            button.layer.displayIfNeeded()
            if button.window != nil,
               button.bounds.width > 1,
               button.bounds.height > 1,
               button.layer.contents != nil {
                await nextDisplayInterval()
                return
            }
            do {
                try await Task.sleep(nanoseconds: 16_000_000)
            } catch {
                return
            }
        }
        #if DEBUG
        NSLog("XMoney: Apple Pay button did not paint within %.1f seconds; continuing.", timeout)
        #endif
    }

    package static func waitUntilLaidOut(_ view: UIView, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if Task.isCancelled { return }
            view.layoutIfNeeded()
            if view.window != nil,
               view.bounds.width > 1,
               view.bounds.height > 1 {
                await nextDisplayInterval()
                return
            }
            do {
                try await Task.sleep(nanoseconds: 16_000_000)
            } catch {
                return
            }
        }
    }

    private static func nextDisplayInterval() async {
        do {
            try await Task.sleep(nanoseconds: 16_000_000)
        } catch {
            return
        }
    }
}
