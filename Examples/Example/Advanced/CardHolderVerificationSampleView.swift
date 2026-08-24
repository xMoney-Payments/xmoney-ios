import SwiftUI
import XMoneyCore
import XMoneyPaymentSheet

/**
 * Card holder verification — optional pre-pay name check.
 *
 * Requires the site to have name-check validation enabled. The callback runs
 * after account-validation; return `true` to continue pay, `false` to block.
 */
struct CardHolderVerificationSampleView: View {
    @EnvironmentObject private var theme: ExampleThemeState
    @State private var lastMatch: String?
    @State private var lastResult: PaymentResult?
    @State private var heldIntent: PaymentIntent?
    @State private var didProcess = false
    @State private var consumed = false
    @State private var error: String?
    @State private var loading = false
    @State private var showSheet = false

    var body: some View {
        let style = exampleForcedStyle(theme.isDark)
        let wallet = exampleWalletAppearance(isDark: theme.isDark)
        let configuration = PaymentConfig(
            publicKey: ExampleSecrets.publicKey,
            card: .init(
                savedCards: .init(enabled: true),
                cardHolderVerification: CardHolderVerification(
                    name: CardHolderName(firstName: "John", lastName: "Doe"),
                    onCardHolderVerification: { result in
                        lastMatch = result.status.rawValue
                        return result.status == .matched
                    }
                )
            ),
            paymentMethods: .init(applePay: .init(enabled: true, appearance: wallet)),
            options: .init(style: style, appearance: exampleAppearance())
        )

        SampleScaffold(
            title: "Name check",
            subtitle: "Pays only when the cardholder name matches John Doe.",
            showTestCards: true,
            nameCheckHint: true
        ) {
            ExampleCard {
                Text("Expected name")
                    .exampleLabelMedium()
                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                Text("John Doe")
                    .font(ExampleFont.titleLarge)
                Text("Use a test card whose account-validation result matches that name, or the SDK will block pay.")
                    .font(ExampleFont.bodyMedium)
                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
            }
            if !consumed {
                ExampleButton(
                    label: lastResult == .canceled ? "Continue" : "Pay",
                    loading: loading,
                    action: { present(configuration: configuration) }
                )
                if lastResult == .canceled {
                    ExampleStatusChip("You closed checkout before finishing.", .neutral)
                }
            }
            if let lastMatch {
                ExampleStatusChip("Verification: \(lastMatch)", .neutral)
            }
            if let error { ExampleStatusChip(error, .error) }
            if consumed, let lastResult {
                ExampleResultPanel(result: lastResult)
                ExampleButton(label: "New payment", variant: .secondary) {
                    self.lastResult = nil
                    self.lastMatch = nil
                    heldIntent = nil
                    consumed = false
                    didProcess = false
                }
            }
        }
        .id(theme.isDark)
        .background(
            Group {
                if let intent = heldIntent {
                    Color.clear.paymentSheet(
                        isPresented: $showSheet,
                        configuration: configuration,
                        intent: intent,
                        onEvent: handleEvent,
                        onCompletion: handleResult
                    )
                }
            }
        )
        .onAppear {}
    }

    private func present(configuration: PaymentConfig) {
        loading = true
        error = nil
        lastResult = nil
        lastMatch = nil
        Task {
            do {
                let intent: PaymentIntent
                if let heldIntent {
                    intent = heldIntent
                } else {
                    intent = try await DemoCheckoutBackend.createPaymentIntent()
                }
                await MainActor.run {
                    heldIntent = intent
                    didProcess = false
                    showSheet = true
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

    private func handleEvent(_ event: PaymentSheetEvent) {
        switch event {
        case .ready: loading = false
        case let .processing(isProcessing):
            if isProcessing { didProcess = true }
        }
    }

    private func handleResult(_ result: PaymentResult) {
        lastResult = result
        loading = false
        consumed = orderConsumed(result, didProcess: didProcess)
        if consumed { heldIntent = nil }
        showSheet = false
    }
}
