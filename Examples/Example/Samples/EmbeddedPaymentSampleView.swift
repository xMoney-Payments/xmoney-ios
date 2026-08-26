import SwiftUI
import XMoneyApplePay
import XMoneyCore
import XMoneyPaymentElement

/**
 * Minimal Embedded Payment Element integration.
 *
 * Copy this file as a starting point. Fetch `PaymentIntent` from **your** server
 * (`payload` + `checksum`). The app should hold only `publicKey`.
 *
 * Call `ApplePay.register()` before `prepare` so Embedded can offer Apple Pay.
 * After a consumed terminal result hide the element and bind a **new** intent.
 * Pre-pay cancel does not consume — the element stays mounted.
 */
struct EmbeddedPaymentSampleView: View {
    @EnvironmentObject private var theme: ExampleThemeState
    @State private var useUIKit = false
    @State private var intent: PaymentIntent?
    @State private var lastResult: PaymentResult?
    @State private var error: String?
    @State private var loading = true
    @State private var ready = false
    @State private var payment: EmbeddedPayment?

    var body: some View {
        let style = exampleForcedStyle(theme.isDark)
        let wallet = exampleWalletAppearance(isDark: theme.isDark)
        let appearance = exampleAppearance()
        let configuration = PaymentConfig(
            publicKey: ExampleSecrets.publicKey,
            card: .init(savedCards: .init(enabled: true)),
            paymentMethods: .init(applePay: .init(enabled: true, appearance: wallet)),
            options: .init(style: style, appearance: appearance)
        )

        SampleScaffold(
            title: "Embedded Element",
            subtitle: "Payment form lives in your layout.",
            scrollable: true,
            showTestCards: true,
            showUIKitToggle: true,
            useUIKit: $useUIKit
        ) {
            SampleOrderCard()
            if consumed, let lastResult {
                ExampleResultPanel(result: lastResult)
                ExampleButton(label: "New payment", variant: .secondary, action: loadOrder)
            } else if loading && intent == nil {
                ExampleLoader(message: "Preparing checkout…")
            } else if let intent, let payment {
                MerchantReadyGate(ready: ready, message: "Preparing checkout…") {
                    Group {
                        if useUIKit {
                            PaymentElementHost(payment: payment, intent: intent) { event in
                                if case .ready = event { ready = true }
                            }
                        } else {
                            PaymentElementView(payment: payment, intent: intent) { event in
                                if case .ready = event { ready = true }
                            }
                            .frame(maxWidth: .infinity)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if let error { ExampleStatusChip(error, .error) }
        }
        .id("\(theme.isDark)-\(useUIKit)")
        .onAppear {
            ApplePay.register()
            ensurePayment(configuration)
            if intent == nil { loadOrder() }
        }
        .onChange(of: theme.isDark) { _ in
            payment = EmbeddedPayment(configuration: configuration, onResult: handleResult)
            ready = false
        }
    }

    private var consumed: Bool {
        lastResult != nil && (payment?.isOrderConsumed ?? false)
    }

    private func ensurePayment(_ configuration: PaymentConfig) {
        if payment == nil {
            payment = EmbeddedPayment(configuration: configuration, onResult: handleResult)
        }
    }

    private func handleResult(_ result: PaymentResult) {
        lastResult = result
        if result == .canceled, payment?.isOrderConsumed == false {
            lastResult = nil
        }
    }

    private func loadOrder() {
        loading = true
        error = nil
        lastResult = nil
        ready = false
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
