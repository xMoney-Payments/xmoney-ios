import Foundation

package enum OrderConsumption {
    /// Consume on complete, failed, or cancel after the user authorized (e.g. 3DS abandon).
    /// Pre-authorize Apple Pay dismiss does not consume.
    package static func shouldConsume(status: EngineResult.Status, didAuthorize: Bool) -> Bool {
        switch status {
        case .complete, .failed:
            return true
        case .canceled:
            return didAuthorize
        }
    }

    package static func merchantResult(_ result: EngineResult) -> PaymentResult {
        switch result.status {
        case .complete:
            guard let transaction = result.transaction else {
                return .failed(PaymentError.payment("Missing transaction").merchantFacing())
            }
            return .complete(transaction)
        case .canceled:
            return .canceled
        case .failed:
            if result.errorCode == "CANCELED" {
                return .canceled
            }
            let code = result.errorCode ?? "PAYMENT_ERROR"
            let message = result.errorMessage ?? PaymentError.genericPayment
            return .failed(PaymentError.from(code: code, message: message).merchantFacing())
        }
    }
}
