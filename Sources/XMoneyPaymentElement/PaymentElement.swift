import UIKit
import SwiftUI
import XMoneyCore

public final class PaymentElement: UIView {
    private let payment: EmbeddedPayment
    private let onEvent: (EmbeddedEvent) -> Void
    private let loaderHost = UIView()
    private var loader: XCoinFlipLoaderView?
    private var formView: PaymentFormView?
    /// Bumps on each ``prepare(intent:)`` so overlapping async prepares discard stale results.
    private var prepareGeneration = 0

    public init(
        payment: EmbeddedPayment,
        onEvent: @escaping (EmbeddedEvent) -> Void = { _ in }
    ) {
        self.payment = payment
        self.onEvent = onEvent
        super.init(frame: .zero)
        payment._controller.attachHostView(self)
        setupLoader()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @MainActor
    public func prepare(intent: PaymentIntent) async throws {
        prepareGeneration += 1
        let generation = prepareGeneration
        showLoader()
        try await payment.prepare(intent: intent) { [weak self] event in
            Task { @MainActor in
                guard let self, self.prepareGeneration == generation else { return }
                self.onEvent(event)
                switch event {
                case .ready:
                    break
                case let .processing(isProcessing):
                    self.formView?.setProcessing(isProcessing)
                    self.formView?.setOrderConsumed(self.payment.isOrderConsumed)
                }
            }
        }
        guard !Task.isCancelled, prepareGeneration == generation else { return }
        renderForm()
    }

    public var isOrderConsumed: Bool { payment.isOrderConsumed }

    private func setupLoader() {
        loaderHost.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loaderHost)
        NSLayoutConstraint.activate([
            loaderHost.topAnchor.constraint(equalTo: topAnchor),
            loaderHost.leadingAnchor.constraint(equalTo: leadingAnchor),
            loaderHost.trailingAnchor.constraint(equalTo: trailingAnchor),
            loaderHost.bottomAnchor.constraint(equalTo: bottomAnchor),
            loaderHost.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),
        ])
        showLoader()
    }

    private func showLoader() {
        formView?.removeFromSuperview()
        formView = nil
        loaderHost.isHidden = false
        loader?.removeFromSuperview()
        let flip = XCoinFlipLoaderView()
        flip.translatesAutoresizingMaskIntoConstraints = false
        loaderHost.addSubview(flip)
        NSLayoutConstraint.activate([
            flip.centerXAnchor.constraint(equalTo: loaderHost.centerXAnchor),
            flip.centerYAnchor.constraint(equalTo: loaderHost.centerYAnchor),
        ])
        loader = flip
    }

    private func renderForm() {
        let controller = payment._controller
        guard let config = controller.paymentConfig, let state = controller.sheetState else { return }

        loader?.stopAnimating()
        loader?.removeFromSuperview()
        loader = nil
        loaderHost.isHidden = true

        formView?.removeFromSuperview()
        let form = PaymentFormView(config: config, state: state)
        form.translatesAutoresizingMaskIntoConstraints = false
        form.onPayCard = { [weak self] input in
            self?.payment._controller.payWithCard(input)
        }
        form.onSelectSaved = { [weak self] card in
            self?.payment._controller.paySavedCard(card)
        }
        form.onDeleteSaved = { [weak self] card in
            try await self?.payment._controller.deleteSavedCardAndReload(card)
            if let state = self?.payment._controller.sheetState {
                self?.formView?.update(state: state)
            }
        }
        form.onApplePay = { [weak self] in
            self?.payment._controller.startApplePay()
        }
        form.onContentSizeChange = { [weak self] in
            self?.invalidateIntrinsicContentSize()
        }
        form.setProcessing(controller.isProcessing)
        form.setOrderConsumed(controller.isOrderConsumed)
        addSubview(form)
        NSLayoutConstraint.activate([
            form.topAnchor.constraint(equalTo: topAnchor),
            form.leadingAnchor.constraint(equalTo: leadingAnchor),
            form.trailingAnchor.constraint(equalTo: trailingAnchor),
            form.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        formView = form
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    public override var intrinsicContentSize: CGSize {
        if let formView {
            return CGSize(width: UIView.noIntrinsicMetric, height: max(formView.contentHeight, 160))
        }
        return CGSize(width: UIView.noIntrinsicMetric, height: 160)
    }
}

public struct PaymentElementView: UIViewRepresentable {
    public let payment: EmbeddedPayment
    public let intent: PaymentIntent
    public var onEvent: (EmbeddedEvent) -> Void

    public init(
        payment: EmbeddedPayment,
        intent: PaymentIntent,
        onEvent: @escaping (EmbeddedEvent) -> Void = { _ in }
    ) {
        self.payment = payment
        self.intent = intent
        self.onEvent = onEvent
    }

    public func makeUIView(context: Context) -> PaymentElement {
        let element = PaymentElement(payment: payment, onEvent: onEvent)
        context.coordinator.element = element
        let key = orderKey
        context.coordinator.lastOrderKey = key
        context.coordinator.prepareTask?.cancel()
        context.coordinator.prepareTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            try? await element.prepare(intent: intent)
        }
        return element
    }

    public func updateUIView(_ uiView: PaymentElement, context: Context) {
        let key = orderKey
        guard context.coordinator.lastOrderKey != key else { return }
        context.coordinator.lastOrderKey = key
        context.coordinator.prepareTask?.cancel()
        context.coordinator.prepareTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            try? await uiView.prepare(intent: intent)
        }
    }

    @available(iOS 16.0, *)
    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: PaymentElement,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let height = uiView.intrinsicContentSize.height
        return CGSize(width: width, height: height > 0 ? height : 160)
    }

    public static func dismantleUIView(_ uiView: PaymentElement, coordinator: Coordinator) {
        coordinator.prepareTask?.cancel()
        coordinator.prepareTask = nil
        coordinator.element = nil
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private var orderKey: String {
        "\(intent.orderPayload):\(intent.orderChecksum)"
    }

    public final class Coordinator {
        var element: PaymentElement?
        var lastOrderKey: String?
        var prepareTask: Task<Void, Never>?
    }
}
