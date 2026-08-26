import SwiftUI
import UIKit
import XMoneyApplePay
import XMoneyCore
import XMoneyPaymentElement

/// Hosts `PaymentElement` and sizes itself to the form’s intrinsic height so Pay is not clipped.
struct PaymentElementHost: View {
    let payment: EmbeddedPayment
    let intent: PaymentIntent
    var onEvent: (EmbeddedEvent) -> Void = { _ in }
    @State private var height: CGFloat = 160

    var body: some View {
        PaymentElementHostRepresentable(
            payment: payment,
            intent: intent,
            onEvent: onEvent,
            onHeightChange: { new in
                if abs(height - new) > 1 { height = new }
            }
        )
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}

private struct PaymentElementHostRepresentable: UIViewControllerRepresentable {
    let payment: EmbeddedPayment
    let intent: PaymentIntent
    var onEvent: (EmbeddedEvent) -> Void
    var onHeightChange: (CGFloat) -> Void

    func makeUIViewController(context: Context) -> PaymentElementHostController {
        let controller = PaymentElementHostController(payment: payment, onEvent: onEvent)
        controller.onHeightChange = onHeightChange
        controller.element.onContentSizeChange = { [weak controller] in
            controller?.publishHeight()
        }
        context.coordinator.controller = controller
        context.coordinator.lastKey = orderKey
        Task { @MainActor in
            try? await controller.element.prepare(intent: intent)
            controller.publishHeight()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: PaymentElementHostController, context: Context) {
        uiViewController.onEvent = onEvent
        uiViewController.onHeightChange = onHeightChange
        uiViewController.element.onContentSizeChange = { [weak uiViewController] in
            uiViewController?.publishHeight()
        }
        let key = orderKey
        guard context.coordinator.lastKey != key else { return }
        context.coordinator.lastKey = key
        Task { @MainActor in
            try? await uiViewController.element.updateOrder(intent: intent)
            uiViewController.publishHeight()
        }
    }

    @available(iOS 16.0, *)
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiViewController: PaymentElementHostController,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let height = max(uiViewController.element.intrinsicContentSize.height, 160)
        return CGSize(width: width, height: height)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private var orderKey: String {
        "\(intent.orderPayload):\(intent.orderChecksum)"
    }

    final class Coordinator {
        var controller: PaymentElementHostController?
        var lastKey: String?
    }
}

final class PaymentElementHostController: UIViewController {
    let element: PaymentElement
    var onEvent: (EmbeddedEvent) -> Void
    var onHeightChange: ((CGFloat) -> Void)?

    init(payment: EmbeddedPayment, onEvent: @escaping (EmbeddedEvent) -> Void) {
        self.element = PaymentElement(payment: payment, onEvent: onEvent)
        self.onEvent = onEvent
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        element.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(element)
        NSLayoutConstraint.activate([
            element.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            element.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            element.topAnchor.constraint(equalTo: view.topAnchor),
            element.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        publishHeight()
    }

    func publishHeight() {
        view.layoutIfNeeded()
        let height = max(element.intrinsicContentSize.height, 160)
        onHeightChange?(height)
    }
}
