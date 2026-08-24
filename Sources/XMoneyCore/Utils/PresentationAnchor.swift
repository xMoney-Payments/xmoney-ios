import UIKit

/// Finds a view controller that can present a modal.
///
/// SwiftUI `UIViewControllerRepresentable` hosts are often not in a window yet
/// when `updateUIViewController` first runs, and 0×0 hidden children may never
/// join the hierarchy. Presenting from those controllers logs:
/// "Attempt to present … whose view is not in the window hierarchy."
package enum PresentationAnchor {
    @MainActor
    package static func resolve(from origin: UIViewController) -> UIViewController {
        if let attached = attachedAncestor(from: origin) {
            return topMost(from: attached)
        }
        if let root = keyWindowRoot() {
            return topMost(from: root)
        }
        return origin
    }

    @MainActor
    package static func isPresentable(_ controller: UIViewController) -> Bool {
        controller.viewIfLoaded?.window != nil
    }

    @MainActor
    private static func attachedAncestor(from origin: UIViewController) -> UIViewController? {
        var current: UIViewController? = origin
        var lastAttached: UIViewController?
        var seen = Set<ObjectIdentifier>()
        while let vc = current, seen.insert(ObjectIdentifier(vc)).inserted {
            if vc.viewIfLoaded?.window != nil {
                lastAttached = vc
            }
            if let parent = vc.parent {
                current = parent
            } else if let nav = vc.navigationController, nav !== vc {
                current = nav
            } else {
                break
            }
        }
        return lastAttached
    }

    @MainActor
    private static func topMost(from seed: UIViewController) -> UIViewController {
        var top = seed
        var seen = Set<ObjectIdentifier>()
        while let presented = top.presentedViewController,
              !presented.isBeingDismissed,
              seen.insert(ObjectIdentifier(presented)).inserted {
            top = presented
        }
        if let nav = top as? UINavigationController, let visible = nav.visibleViewController {
            return visible
        }
        if let tab = top as? UITabBarController, let selected = tab.selectedViewController {
            return topMost(from: selected)
        }
        return top
    }

    @MainActor
    private static func keyWindowRoot() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        let window = windows.first(where: \.isKeyWindow) ?? windows.first
        return window?.rootViewController
    }
}
