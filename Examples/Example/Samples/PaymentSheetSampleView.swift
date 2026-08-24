import SwiftUI
import UIKit
import XMoneyCore
import XMoneyPaymentSheet

/**
 * Minimal Payment Sheet integration.
 *
 * Copy this file as a starting point. In production, replace `DemoCheckoutBackend`
 * with a call to **your** server that returns `payload` + `checksum` only.
 * Never ship a secret API key in the iOS app.
 *
 * After COMPLETE, FAILED, or post-submit CANCELED the order checksum is consumed —
 * create a new `PaymentIntent` before presenting again. Cancel **before** pay
 * (header close) does not consume; present the same intent again.
 */
struct PaymentSheetSampleView: View {
    @EnvironmentObject private var theme: ExampleThemeState
    @State private var useUIKit = false
    @State private var lastResult: PaymentResult?
    @State private var heldIntent: PaymentIntent?
    @State private var didProcess = false
    @State private var consumed = false
    @State private var error: String?
    @State private var loading = false
    @State private var showSheet = false
    @State private var presenter: UIViewController?
    @State private var paymentSheet: PaymentSheet?

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
            title: "Payment Sheet",
            subtitle: "SDK owns the full checkout UI.",
            showTestCards: true,
            showUIKitToggle: true,
            useUIKit: $useUIKit
        ) {
            if !consumed {
                SampleOrderCard()
                ExampleButton(
                    label: lastResult == .canceled ? "Continue" : "Pay",
                    loading: loading,
                    action: { present(configuration: configuration) }
                )
                if lastResult == .canceled {
                    ExampleStatusChip("You closed checkout before finishing.", .neutral)
                }
            }
            if let error { ExampleStatusChip(error, .error) }
            if consumed, let lastResult {
                ExampleResultPanel(result: lastResult)
                ExampleButton(label: "New payment", variant: .secondary) {
                    self.lastResult = nil
                    heldIntent = nil
                    consumed = false
                    didProcess = false
                }
            }
        }
        .id("\(theme.isDark)-\(useUIKit)")
        .background(HiddenPresenter(presenter: $presenter))
        .background(
            Group {
                if !useUIKit, let intent = heldIntent {
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
        .onAppear {
            paymentSheet = PaymentSheet(configuration: configuration)
        }
        .onChange(of: theme.isDark) { _ in
            paymentSheet = PaymentSheet(configuration: configuration)
        }
    }

    private func present(configuration: PaymentConfig) {
        loading = true
        error = nil
        lastResult = nil
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
                    if useUIKit {
                        guard let presenter else {
                            error = "Presenter not ready"
                            loading = false
                            return
                        }
                        let sheet = paymentSheet ?? PaymentSheet(configuration: configuration)
                        paymentSheet = sheet
                        sheet.present(from: presenter, intent: intent, onEvent: handleEvent, completion: handleResult)
                    } else {
                        showSheet = true
                    }
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
        case .ready:
            loading = false
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
