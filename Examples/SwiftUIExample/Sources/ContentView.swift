import SwiftUI
import XMoneyPaymentSheet

@main
struct SwiftUIExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var showSheet = false

    private let configuration = PaymentConfig(
        publicKey: "pk_test_example",
        paymentMethods: .init(applePay: .init(enabled: true))
    )

    private let intent = PaymentIntent(
        orderPayload: OrderPayload("<base64-order-payload-from-backend>"),
        orderChecksum: OrderChecksum("<checksum-from-backend>")
    )

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("xMoney SwiftUI Example")
                    .font(.title2)
                Button("Present Payment Sheet") {
                    showSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Payment Sheet")
            .paymentSheet(
                isPresented: $showSheet,
                configuration: configuration,
                intent: intent,
                onEvent: { event in
                    switch event {
                    case .ready:
                        print("Sheet ready")
                    case let .processing(isProcessing):
                        print("Processing:", isProcessing)
                    }
                },
                onCompletion: { result in
                    switch result {
                    case let .complete(transaction):
                        print("Success:", transaction.id ?? "no id")
                    case let .failed(error):
                        print("Error:", error.code, error.message)
                    case .canceled:
                        print("Canceled")
                    }
                }
            )
        }
    }
}
