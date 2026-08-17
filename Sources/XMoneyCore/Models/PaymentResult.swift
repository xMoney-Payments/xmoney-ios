import Foundation

package enum PaymentSubmissionResult {
    case needs3DS(url: URL)
    case redirect(url: URL)
    case transaction(id: String)
}

package struct EngineResult {
    package enum Status: String {
        case complete
        case failed
        case canceled
    }

    package let status: Status
    package let transaction: Transaction?
    package let errorCode: String?
    package let errorMessage: String?

    package init(
        status: Status,
        transaction: Transaction?,
        errorCode: String?,
        errorMessage: String?
    ) {
        self.status = status
        self.transaction = transaction
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }

    package static func failed(_ error: PaymentError) -> EngineResult {
        EngineResult(
            status: .failed,
            transaction: nil,
            errorCode: error.code,
            errorMessage: error.merchantMessage()
        )
    }
}

public enum PaymentResult: Equatable, Sendable {
    case complete(Transaction)
    case failed(PaymentError)
    case canceled
}
