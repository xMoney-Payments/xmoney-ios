import UIKit

// Do not replace panGestureRecognizer.delegate — UIScrollView owns it internally.
final class PreferSelfScrollView: UIScrollView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        delaysContentTouches = false
        canCancelContentTouches = true
        showsHorizontalScrollIndicator = false
        keyboardDismissMode = .onDrag
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        claimPriorityOverAncestorScrollers()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        claimPriorityOverAncestorScrollers()
    }

    private func claimPriorityOverAncestorScrollers() {
        var ancestor: UIView? = superview
        while let view = ancestor {
            if let parentScroll = view as? UIScrollView, parentScroll !== self {
                parentScroll.panGestureRecognizer.require(toFail: panGestureRecognizer)
            }
            for recognizer in view.gestureRecognizers ?? [] {
                guard let pan = recognizer as? UIPanGestureRecognizer,
                      pan !== panGestureRecognizer else { continue }
                pan.require(toFail: panGestureRecognizer)
            }
            ancestor = view.superview
        }
    }

    override func touchesShouldCancel(in view: UIView) -> Bool {
        // Allow dragging to cancel UIControl tracking on saved-card rows.
        if view is UIControl { return true }
        return super.touchesShouldCancel(in: view)
    }
}
