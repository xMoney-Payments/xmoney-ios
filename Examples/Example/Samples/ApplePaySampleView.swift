import SwiftUI
import UIKit
import XMoneyApplePay
import XMoneyCore

/**
 * Minimal standalone Apple Pay integration.
 *
 * Copy this file as a starting point. Fetch `PaymentIntent` from **your** server.
 * After a terminal consumed result bind a new intent. Pre-auth cancel (user
 * dismisses PassKit) delivers `canceled` and does not consume.
 */
struct ApplePaySampleView: View {
    @EnvironmentObject private var theme: ExampleThemeState
    @State private var useUIKit = false
    @State private var intent: PaymentIntent?
    @State private var lastResult: PaymentResult?
    @State private var error: String?
    @State private var loading = true
    @State private var bound = false
    @State private var presenter: UIViewController?
    @State private var applePay: ApplePay?

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    var body: some View {
        let style = exampleForcedStyle(theme.isDark)
        let wallet = exampleWalletAppearance(isDark: theme.isDark)
        let configuration = PaymentConfig(
            publicKey: ExampleSecrets.publicKey,
            card: .init(savedCards: .init(enabled: false)),
            paymentMethods: .init(applePay: .init(enabled: true, appearance: wallet)),
            options: .init(style: style, appearance: exampleAppearance())
        )

        SampleScaffold(
            title: "Apple Pay",
            subtitle: "Standalone wallet button in your screen.",
            scrollable: false,
            showTestCards: true,
            showUIKitToggle: true,
            useUIKit: $useUIKit
        ) {
            SampleOrderCard()
            if isSimulator {
                ExampleStatusChip(
                    "Apple Pay needs a physical device, an Apple Pay Merchant ID in Signing & Capabilities, and that ID matching xMoney wallet params. Simulator cannot authorize.",
                    .neutral
                )
            }
            if consumed, let lastResult {
                ExampleResultPanel(result: lastResult)
                ExampleButton(label: "New payment", variant: .secondary, action: loadOrder)
            } else if loading && intent == nil {
                ExampleLoader(message: "Preparing Apple Pay…")
            } else if let intent {
                MerchantReadyGate(ready: bound, message: "Preparing Apple Pay…") {
                    if applePay?.isAvailable == true, applePay?.isReady == true {
                        ApplePayButtonView(
                            appearance: wallet,
                            isEnabled: applePay?.isInteractionEnabled ?? true,
                            isDarkBackground: theme.isDark,
                            onTap: { present(intent: intent) }
                        )
                        .frame(height: 56)
                    }
                }
                if bound, applePay?.isReady != true {
                    ExampleStatusChip("Apple Pay isn’t available on this device.", .neutral)
                }
                if lastResult == .canceled && !consumed {
                    ExampleStatusChip("You closed Apple Pay before finishing.", .neutral)
                }
            }
            if let error { ExampleStatusChip(error, .error) }
        }
        .id("\(theme.isDark)-\(useUIKit)")
        .background(HiddenPresenter(presenter: $presenter))
        .onAppear {
            applePay = ApplePay(configuration: configuration, onResult: handleResult)
            if intent == nil { loadOrder() }
        }
        .onChange(of: theme.isDark) { _ in
            applePay = ApplePay(configuration: configuration, onResult: handleResult)
            bound = false
            if let intent {
                Task { try? await applePay?.updateOrder(intent: intent) }
            }
        }
        .task(id: intent.map { "\($0.orderPayload):\($0.orderChecksum)" }) {
            guard let intent, let applePay else { return }
            bound = false
            do {
                try await applePay.updateOrder(intent: intent)
                await MainActor.run { bound = true }
            } catch {
                guard !isCancellation(error) else { return }
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }

    private var consumed: Bool {
        applePay?.isOrderConsumed ?? false
    }

    private func handleResult(_ result: PaymentResult) {
        lastResult = result
    }

    private func present(intent: PaymentIntent) {
        guard let applePay, let presenter else { return }
        applePay.present(from: presenter, intent: intent) { event in
            if case .ready = event { bound = true }
        }
    }

    private func loadOrder() {
        loading = true
        error = nil
        lastResult = nil
        bound = false
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
