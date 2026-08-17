import SwiftUI
#if !COCOAPODS
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

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.isHidden = true
        controller.view.isUserInteractionEnabled = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented else {
            context.coordinator.paymentSheet?.dismiss()
            context.coordinator.isActive = false
            return
        }

        guard !context.coordinator.isActive else { return }
        context.coordinator.isActive = true

        let paymentSheet = PaymentSheet(configuration: configuration)
        context.coordinator.paymentSheet = paymentSheet
        paymentSheet.present(
            from: uiViewController,
            intent: intent,
            onEvent: onEvent,
            completion: { result in
                context.coordinator.isActive = false
                context.coordinator.paymentSheet = nil
                // Defer binding writes off the presentation completion stack.
                DispatchQueue.main.async {
                    isPresented = false
                    onCompletion(result)
                }
            }
        )
    }

    final class Coordinator {
        var paymentSheet: PaymentSheet?
        var isActive = false
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
