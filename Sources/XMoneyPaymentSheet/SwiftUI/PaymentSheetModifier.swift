import SwiftUI
#if canImport(XMoneyCore)
import XMoneyCore
#endif

private struct PaymentSheetPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let configuration: PaymentConfig
    let intent: PaymentIntent
    let onEvent: ((PaymentSheetEvent) -> Void)?
    let onCompletion: (PaymentResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> PaymentSheetHostController {
        let controller = PaymentSheetHostController()
        controller.onBecamePresentable = { [weak coordinator = context.coordinator] in
            coordinator?.flushIfNeeded()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: PaymentSheetHostController, context: Context) {
        let coordinator = context.coordinator
        coordinator.host = uiViewController
        uiViewController.onBecamePresentable = { [weak coordinator] in
            coordinator?.flushIfNeeded()
        }

        guard isPresented else {
            coordinator.cancel()
            return
        }

        guard !coordinator.isActive else { return }

        coordinator.enqueue { [weak coordinator, configuration, intent, onEvent, onCompletion] presenter in
            guard let coordinator else { return }
            let paymentSheet = PaymentSheet(configuration: configuration)
            coordinator.paymentSheet = paymentSheet
            paymentSheet.present(
                from: presenter,
                intent: intent,
                onEvent: onEvent,
                completion: { result in
                    coordinator.isActive = false
                    coordinator.paymentSheet = nil
                    // Defer binding writes off the presentation completion stack.
                    DispatchQueue.main.async {
                        isPresented = false
                        onCompletion(result)
                    }
                }
            )
        }
    }

    @MainActor
    final class Coordinator {
        var paymentSheet: PaymentSheet?
        var isActive = false
        weak var host: PaymentSheetHostController?
        private var pending: ((UIViewController) -> Void)?

        func enqueue(_ present: @escaping (UIViewController) -> Void) {
            pending = present
            flushIfNeeded()
        }

        func flushIfNeeded() {
            guard !isActive, let pending, let host else { return }
            let presenter = PresentationAnchor.resolve(from: host)
            guard PresentationAnchor.isPresentable(presenter) else { return }
            self.pending = nil
            isActive = true
            pending(presenter)
        }

        func cancel() {
            pending = nil
            paymentSheet?.dismiss()
            isActive = false
        }
    }
}

private final class PaymentSheetHostController: UIViewController {
    var onBecamePresentable: (() -> Void)?

    override func loadView() {
        let view = WindowObservingView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.onMovedToWindow = { [weak self] in
            self?.onBecamePresentable?()
        }
        self.view = view
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onBecamePresentable?()
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

public struct PaymentSheetModifier: ViewModifier {
    @Binding private var isPresented: Bool
    private let configuration: PaymentConfig
    private let intent: PaymentIntent
    private let onEvent: ((PaymentSheetEvent) -> Void)?
    private let onCompletion: (PaymentResult) -> Void

    public init(
        isPresented: Binding<Bool>,
        configuration: PaymentConfig,
        intent: PaymentIntent,
        onEvent: ((PaymentSheetEvent) -> Void)? = nil,
        onCompletion: @escaping (PaymentResult) -> Void
    ) {
        _isPresented = isPresented
        self.configuration = configuration
        self.intent = intent
        self.onEvent = onEvent
        self.onCompletion = onCompletion
    }

    public func body(content: Content) -> some View {
        content.background(
            PaymentSheetPresenter(
                isPresented: $isPresented,
                configuration: configuration,
                intent: intent,
                onEvent: onEvent,
                onCompletion: onCompletion
            )
        )
    }
}

public extension View {
    /// Presents the xMoney payment sheet when `isPresented` becomes `true`.
    func paymentSheet(
        isPresented: Binding<Bool>,
        configuration: PaymentConfig,
        intent: PaymentIntent,
        onEvent: ((PaymentSheetEvent) -> Void)? = nil,
        onCompletion: @escaping (PaymentResult) -> Void
    ) -> some View {
        modifier(
            PaymentSheetModifier(
                isPresented: isPresented,
                configuration: configuration,
                intent: intent,
                onEvent: onEvent,
                onCompletion: onCompletion
            )
        )
    }
}
