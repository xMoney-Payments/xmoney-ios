import SwiftUI
import XMoneyApplePay
import XMoneyCore
import XMoneyPaymentElement

private let amountStepMinor: Int64 = 500
private let amountMinMinor: Int64 = 500

/**
 * Update the bound order without unmounting Payment Element.
 *
 * Create a new `payload` + `checksum` on **your** server, then pass that
 * `PaymentIntent` into the mounted Element. Pay is locked until it returns
 * (`isInteractionEnabled`). The Pay button keeps its current title — this
 * does not emit `.processing`.
 */
struct UpdateOrderSampleView: View {
    @EnvironmentObject private var theme: ExampleThemeState
    @State private var amountMinor = SAMPLE_AMOUNT_MINOR
    @State private var hostIntent: PaymentIntent?
    @State private var lastResult: PaymentResult?
    @State private var error: String?
    @State private var payment: EmbeddedPayment?
    @State private var ready = false
    @State private var interactionEnabled = false

    var body: some View {
        let style = exampleForcedStyle(theme.isDark)
        let wallet = exampleWalletAppearance(isDark: theme.isDark)
        let configuration = PaymentConfig(
            publicKey: ExampleSecrets.publicKey,
            card: .init(savedCards: .init(enabled: true)),
            paymentMethods: .init(applePay: .init(enabled: true, appearance: wallet)),
            options: .init(style: style, appearance: exampleAppearance())
        )

        SampleScaffold(
            title: "Update order",
            subtitle: "updateOrder() a new PaymentIntent — Pay locked until Ready.",
            scrollable: true,
            showTestCards: true
        ) {
            UpdateOrderCard(amountMinor: amountMinor, enabled: !consumed && interactionEnabled) { amountMinor = $0 }
            if consumed, let lastResult {
                ExampleResultPanel(result: lastResult)
                ExampleButton(label: "New payment", variant: .secondary) {
                    self.lastResult = nil
                    hostIntent = nil
                    ready = false
                    interactionEnabled = false
                    amountMinor = SAMPLE_AMOUNT_MINOR
                }
            } else if hostIntent == nil {
                ExampleLoader(message: "Preparing checkout…")
            } else if let hostIntent, let payment {
                MerchantReadyGate(ready: ready, message: "Preparing checkout…") {
                    PaymentElementHost(payment: payment, intent: hostIntent) { event in
                        if case .ready = event {
                            ready = true
                            interactionEnabled = payment.isInteractionEnabled
                        }
                    }
                }
            }
            if let error { ExampleStatusChip(error, .error) }
        }
        .onAppear {
            ApplePay.register()
            if payment == nil {
                payment = EmbeddedPayment(configuration: configuration, onResult: handleResult)
            }
        }
        .onChange(of: theme.isDark) { _ in
            applyLiveTheme(configuration)
        }
        .task(id: "\(amountMinor)-\(consumed)-\(payment != nil)") {
            guard !consumed, payment != nil else { return }
            if hostIntent != nil {
                await MainActor.run { interactionEnabled = false }
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            error = nil
            do {
                let next = try await DemoCheckoutBackend.createPaymentIntent(amountMinor: amountMinor)
                await MainActor.run {
                    if hostIntent != nil { interactionEnabled = false }
                    hostIntent = next
                }
            } catch {
                guard !isCancellation(error) else { return }
                await MainActor.run { self.error = error.localizedDescription }
            }
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
}

private struct UpdateOrderCard: View {
    let amountMinor: Int64
    let enabled: Bool
    let onAmountChange: (Int64) -> Void
    @EnvironmentObject private var theme: ExampleThemeState
    @Environment(\.exampleSemantics) private var semantics

    var body: some View {
        ExampleCard {
            Text("ORDER")
                .exampleLabelMedium()
                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
            Text(ExampleSecrets.orderDescription.isEmpty ? "Checkout item" : ExampleSecrets.orderDescription)
                .font(ExampleFont.titleLarge)
            HStack {
                Text(formatMoney(amountMinor, currency: ExampleSecrets.currency))
                    .font(ExampleFont.headlineMedium)
                Spacer()
                AmountStepper(amountMinor: amountMinor, enabled: enabled, onAmountChange: onAmountChange)
            }
        }
    }
}

struct AmountStepper: View {
    let amountMinor: Int64
    let enabled: Bool
    let onAmountChange: (Int64) -> Void
    @Environment(\.exampleSemantics) private var semantics
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        let ink = theme.isDark ? ExampleColors.darkText : ExampleColors.lightText
        HStack(spacing: 0) {
            Button {
                onAmountChange(max(amountMinMinor, amountMinor - amountStepMinor))
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ink)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(!enabled || amountMinor <= amountMinMinor)
            Text(formatMoney(amountStepMinor, currency: ExampleSecrets.currency))
                .font(ExampleFont.labelLarge)
                .foregroundColor(ink)
                .padding(.horizontal, 4)
            Button {
                onAmountChange(amountMinor + amountStepMinor)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ink)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
        }
        .overlay(Capsule().stroke(semantics.hairline, lineWidth: 1))
    }
}
