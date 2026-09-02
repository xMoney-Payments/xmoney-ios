import SwiftUI
import XMoneyApplePay
import XMoneyCore
import XMoneyPaymentElement

/**
 * Merchant-owned Pay button. The SDK form stays visible; `SubmitButtonConfig.visible`
 * is false and the app calls `EmbeddedPayment.confirm()` after `.ready`.
 */
struct MerchantPayButtonSampleView: View {
    @EnvironmentObject private var theme: ExampleThemeState
    @State private var intent: PaymentIntent?
    @State private var lastResult: PaymentResult?
    @State private var error: String?
    @State private var loading = true
    @State private var ready = false
    @State private var processing = false
    @State private var payment: EmbeddedPayment?

    var body: some View {
        let style = exampleForcedStyle(theme.isDark)
        let wallet = exampleWalletAppearance(isDark: theme.isDark)
        let configuration = PaymentConfig(
            publicKey: ExampleSecrets.publicKey,
            card: .init(
                savedCards: .init(enabled: true),
                submitButton: .init(visible: false)
            ),
            paymentMethods: .init(applePay: .init(enabled: true, appearance: wallet)),
            options: .init(style: style, appearance: exampleAppearance())
        )

        SampleScaffold(
            title: "Merchant Pay button",
            subtitle: "SDK form, your CTA. confirm() after Ready.",
            scrollable: true,
            showTestCards: true
        ) {
            SampleOrderCard()
            if consumed, let lastResult {
                ExampleResultPanel(result: lastResult)
                ExampleButton(label: "New payment", variant: .secondary, action: loadOrder)
            } else if loading && intent == nil {
                ExampleLoader(message: "Preparing checkout…")
            } else if let intent, let payment {
                MerchantReadyGate(ready: ready, message: "Preparing checkout…") {
                    PaymentElementHost(payment: payment, intent: intent) { event in
                        switch event {
                        case .ready: ready = true
                        case let .processing(isProcessing): processing = isProcessing
                        }
                    }
                }
                if ready {
                    ExampleButton(
                        label: "Pay",
                        enabled: payment.isInteractionEnabled,
                        loading: processing,
                        action: { payment.confirm() }
                    )
                }
            }
            if let error { ExampleStatusChip(error, .error) }
        }
        .onAppear {
            ApplePay.register()
            if payment == nil {
                payment = EmbeddedPayment(configuration: configuration, onResult: handleResult)
            }
            if intent == nil { loadOrder() }
        }
        .onChange(of: theme.isDark) { _ in
            applyLiveTheme(configuration)
        }
    }

    private var consumed: Bool {
        lastResult != nil && (payment?.isOrderConsumed ?? false)
    }

    private func handleResult(_ result: PaymentResult) {
        lastResult = result
        if result == .canceled, payment?.isOrderConsumed == false {
            lastResult = nil
        }
    }

    private func applyLiveTheme(_ configuration: PaymentConfig) {
        payment?.updateStyle(configuration.options.style)
        payment?.updateWalletAppearance(configuration.paymentMethods.applePay.appearance)
        payment?.updateAppearance(configuration.options.appearance)
    }

    private func loadOrder() {
        loading = true
        error = nil
        lastResult = nil
        ready = false
        processing = false
        intent = nil
        Task {
            do {
                let next = try await DemoCheckoutBackend.createPaymentIntent()
                await MainActor.run {
                    intent = next
                    loading = false
                }
            } catch {
                if isCancellation(error) { return }
                await MainActor.run {
                    self.error = error.localizedDescription
                    loading = false
                }
            }
        }
    }
}
