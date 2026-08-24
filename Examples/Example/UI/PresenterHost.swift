import SwiftUI
import UIKit

/// Resolves the nearest `UIViewController` so UIKit `present(from:)` works from SwiftUI.
struct PresenterHost: UIViewControllerRepresentable {
    var onResolve: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> PresenterViewController {
        PresenterViewController(onResolve: onResolve)
    }

    func updateUIViewController(_ uiViewController: PresenterViewController, context: Context) {
        uiViewController.onResolve = onResolve
    }

    final class PresenterViewController: UIViewController {
        var onResolve: (UIViewController) -> Void

        init(onResolve: @escaping (UIViewController) -> Void) {
            self.onResolve = onResolve
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func loadView() {
            let view = WindowObservingView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
            view.onMovedToWindow = { [weak self] in
                self?.publishAnchor()
            }
            self.view = view
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            publishAnchor()
        }

        private func publishAnchor() {
            onResolve(presentationAnchor)
        }

        /// Prefer a parent that is already in a window. A 0×0 representable is
        /// often not in the hierarchy, so presenting from `self` fails.
        private var presentationAnchor: UIViewController {
            var current: UIViewController = self
            while let parent = current.parent {
                current = parent
            }
            if current.view.window != nil {
                var top = current
                while let presented = top.presentedViewController, !presented.isBeingDismissed {
                    top = presented
                }
                return top
            }
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
            let window = windows.first(where: \.isKeyWindow) ?? windows.first
            if var top = window?.rootViewController {
                while let presented = top.presentedViewController, !presented.isBeingDismissed {
                    top = presented
                }
                return top
            }
            return self
        }
    }
}

private final class WindowObservingView: UIView {
    var onMovedToWindow: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            onMovedToWindow?()
        }
    }
}

struct HiddenPresenter: View {
    @Binding var presenter: UIViewController?

    var body: some View {
        PresenterHost { controller in
            if presenter !== controller {
                presenter = controller
            }
        }
        .frame(width: 1, height: 1)
        .accessibilityHidden(true)
    }
}
