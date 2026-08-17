import UIKit
import XMoneyPaymentSheet

final class ViewController: UIViewController {
    private let paymentSheet: PaymentSheet

    init() {
        paymentSheet = PaymentSheet(
            configuration: PaymentConfig(
                publicKey: "pk_test_example",
                paymentMethods: .init(applePay: .init(enabled: true))
            )
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "xMoney UIKit Example"

        let button = UIButton(type: .system)
        button.setTitle("Present Payment Sheet", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(presentCheckout), for: .touchUpInside)
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    @objc private func presentCheckout() {
        let intent = PaymentIntent(
            orderPayload: OrderPayload("<base64-order-payload-from-backend>"),
            orderChecksum: OrderChecksum("<checksum-from-backend>")
        )

        paymentSheet.present(from: self, intent: intent, onEvent: { event in
            switch event {
            case .ready:
                print("Sheet ready")
            case let .processing(isProcessing):
                print("Processing:", isProcessing)
            }
        }, completion: { result in
            switch result {
            case let .complete(transaction):
                print("Success:", transaction.id ?? "no id")
            case let .failed(error):
                print("Error:", error.code, error.message)
            case .canceled:
                print("Canceled")
            }
        })
    }
}
