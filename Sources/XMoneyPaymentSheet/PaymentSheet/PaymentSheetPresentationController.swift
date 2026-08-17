import UIKit

protocol PaymentSheetHeightProviding: AnyObject {
    var preferredSheetHeight: CGFloat { get }
}

// MARK: - Transitioning delegate

final class PaymentSheetTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    weak var heightProvider: PaymentSheetHeightProviding? {
        didSet {
            presentationController?.heightProvider = heightProvider
        }
    }
    var cornerRadius: CGFloat = 32
    var canDismiss: () -> Bool = { true }
    var onRequestClose: () -> Void = {}
    private(set) weak var presentationController: PaymentSheetPresentationController?

    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        let controller = PaymentSheetPresentationController(
            presentedViewController: presented,
            presenting: presenting
        )
        controller.cornerRadius = cornerRadius
        controller.heightProvider = heightProvider
        controller.canDismiss = { [weak self] in self?.canDismiss() ?? false }
        controller.onRequestClose = { [weak self] in self?.onRequestClose() }
        presentationController = controller
        return controller
    }

    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        PaymentSheetAnimator(isPresenting: true)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PaymentSheetAnimator(isPresenting: false)
    }
}

// MARK: - Presentation controller

final class PaymentSheetPresentationController: UIPresentationController {
    var cornerRadius: CGFloat = 32
    weak var heightProvider: PaymentSheetHeightProviding?
    var canDismiss: () -> Bool = { true }
    var onRequestClose: () -> Void = {}

    private let dimmingView = UIView()
    private var panGesture: UIPanGestureRecognizer?
    private var keyboardHeight: CGFloat = 0
    private var keyboardObservers: [NSObjectProtocol] = []

    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
        registerKeyboardObservers()
    }

    deinit {
        keyboardObservers.forEach(NotificationCenter.default.removeObserver)
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView else { return .zero }
        let bounds = containerView.bounds
        let maxHeight = bounds.height * 0.95
        let contentHeight = heightProvider?.preferredSheetHeight ?? bounds.height * 0.5
        let height = min(max(contentHeight, 100), maxHeight)
        let y = bounds.height - height - keyboardHeight
        return CGRect(x: 0, y: max(0, y), width: bounds.width, height: height)
    }

    override func presentationTransitionWillBegin() {
        guard let containerView else { return }
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        dimmingView.alpha = 0
        dimmingView.frame = containerView.bounds
        dimmingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.insertSubview(dimmingView, at: 0)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dimmingTapped))
        dimmingView.addGestureRecognizer(tap)

        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.dimmingView.alpha = 1
        })
    }

    override func dismissalTransitionWillBegin() {
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.dimmingView.alpha = 0
        })
    }

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
    }

    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        stylePresentedView()
    }

    func updateLayout(animated: Bool) {
        guard let presentedView else { return }
        presentedView.transform = .identity
        let target = frameOfPresentedViewInContainerView
        guard abs(presentedView.frame.height - target.height) > 0.5
            || abs(presentedView.frame.origin.y - target.origin.y) > 0.5 else {
            return
        }
        let updates = { presentedView.frame = target }
        if animated {
            UIView.animate(
                withDuration: 0.28,
                delay: 0,
                options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction],
                animations: updates
            )
        } else {
            updates()
        }
    }

    private func stylePresentedView() {
        guard let presentedView else { return }
        presentedView.layer.cornerRadius = cornerRadius
        presentedView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        presentedView.clipsToBounds = true

        if panGesture == nil {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.cancelsTouchesInView = false
            pan.delegate = self
            presentedView.addGestureRecognizer(pan)
            panGesture = pan
        }
    }

    @objc private func dimmingTapped() {
        guard canDismiss() else { return }
        onRequestClose()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let presentedView else { return }
        guard canDismiss() else {
            if gesture.state == .changed || gesture.state == .ended || gesture.state == .cancelled {
                UIView.animate(withDuration: 0.2) {
                    presentedView.transform = .identity
                }
            }
            return
        }
        let translation = gesture.translation(in: presentedView)
        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                presentedView.transform = CGAffineTransform(translationX: 0, y: translation.y)
            }
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: presentedView).y
            if translation.y > 120 || velocity > 900 {
                presentedView.transform = .identity
                onRequestClose()
            } else {
                UIView.animate(withDuration: 0.25) {
                    presentedView.transform = .identity
                }
            }
        default:
            break
        }
    }

    private func scrollViewBlockingDismiss(at point: CGPoint, in root: UIView) -> UIScrollView? {
        let hit = root.hitTest(point, with: nil)
        var view: UIView? = hit
        while let current = view {
            if let scroll = current as? UIScrollView,
               scroll.isScrollEnabled,
               scroll.contentSize.height > scroll.bounds.height + 0.5 {
                return scroll
            }
            view = current.superview
        }
        return nil
    }

    private func registerKeyboardObservers() {
        let center = NotificationCenter.default
        keyboardObservers = [
            center.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] note in
                self?.handleKeyboard(note)
            },
            center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] _ in
                self?.keyboardHeight = 0
                self?.updateLayout(animated: true)
            },
        ]
    }

    private func handleKeyboard(_ note: Notification) {
        guard let containerView,
              let endFrame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let converted = containerView.convert(endFrame, from: nil)
        let overlap = max(0, containerView.bounds.maxY - converted.minY)
        keyboardHeight = overlap
        updateLayout(animated: true)
    }
}

extension PaymentSheetPresentationController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panGesture, let presentedView else { return true }
        let point = gestureRecognizer.location(in: presentedView)
        // Let nested scrollers (saved cards list) own the drag.
        if let scroll = scrollViewBlockingDismiss(at: point, in: presentedView) {
            let offset = scroll.contentOffset.y + scroll.adjustedContentInset.top
            let velocity = (gestureRecognizer as? UIPanGestureRecognizer)?.velocity(in: presentedView) ?? .zero
            // Only allow dismiss-pan when the inner list is at the top and user pulls down.
            if offset > 1 || velocity.y <= 0 {
                return false
            }
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Don't run dismiss pan together with a scroll view pan.
        !(otherGestureRecognizer.view is UIScrollView)
    }
}

// MARK: - Animator

private final class PaymentSheetAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let isPresenting: Bool

    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.32
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let key: UITransitionContextViewControllerKey = isPresenting ? .to : .from
        guard let controller = transitionContext.viewController(forKey: key) else {
            transitionContext.completeTransition(false)
            return
        }

        let container = transitionContext.containerView
        if isPresenting {
            container.addSubview(controller.view)
            let finalFrame = transitionContext.finalFrame(for: controller)
            controller.view.frame = finalFrame.offsetBy(dx: 0, dy: finalFrame.height)
            UIView.animate(
                withDuration: transitionDuration(using: transitionContext),
                delay: 0,
                usingSpringWithDamping: 0.92,
                initialSpringVelocity: 0.4,
                options: [.curveEaseOut]
            ) {
                controller.view.frame = finalFrame
            } completion: { finished in
                transitionContext.completeTransition(finished)
            }
        } else {
            let initialFrame = transitionContext.initialFrame(for: controller)
            UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, options: .curveEaseIn) {
                controller.view.frame = initialFrame.offsetBy(dx: 0, dy: initialFrame.height)
            } completion: { finished in
                transitionContext.completeTransition(finished)
            }
        }
    }
}
