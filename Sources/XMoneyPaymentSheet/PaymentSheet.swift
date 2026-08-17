import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

public enum PaymentSheetEvent {
    case ready
    case processing(Bool)
}

@MainActor
public final class PaymentSheet {
    private let configuration: PaymentConfig
    private var coordinator: PaymentSheetCoordinator?

    public init(configuration: PaymentConfig) {
        self.configuration = configuration
    }

    public func present(
        from presenter: UIViewController,
        intent: PaymentIntent,
        onEvent: ((PaymentSheetEvent) -> Void)? = nil,
        completion: @escaping (PaymentResult) -> Void
    ) {
        let start: () -> Void = { [weak self] in
            guard let self else { return }
            do {
                let coordinator = try PaymentSheetCoordinator(
                    configuration: self.configuration,
                    intent: intent,
                    onEvent: { onEvent?($0) },
                    completion: { [weak self] result in
                        self?.coordinator = nil
                        completion(OrderConsumption.merchantResult(result))
                    }
                )
                self.coordinator = coordinator
                coordinator.present(from: presenter)
            } catch let error as PaymentError {
                completion(.failed(error.merchantFacing()))
            } catch {
                completion(.failed(PaymentError.unknown(
                    code: "PRESENT_ERROR",
                    message: error.localizedDescription
                ).merchantFacing()))
            }
        }

        if let existing = coordinator {
            if existing.isProcessing { return }
            existing.dismiss()
            coordinator = nil
            DispatchQueue.main.async(execute: start)
        } else {
            start()
        }
    }

    public func dismiss() {
        coordinator?.dismiss()
    }
}
