import Foundation

/// Soft-cancel grace after the user dismisses the 3DS WebView (~1–2 poll intervals).
let threeDSCancelReconcileGraceNanoseconds: UInt64 = 4_000_000_000

private struct ThreeDSGraceTimeout: Error {}

func requireTransactionIdForThreeDS(_ transactionId: String?) throws -> String {
    guard let transactionId else {
        throw PaymentError.threeDS("Missing transaction id")
    }
    return transactionId
}

func resultFromTransaction(_ tx: Transaction) -> EngineResult {
    let status = tx.status ?? ""
    let succeeded = tx.isSuccessfulComplete
    return EngineResult(
        status: succeeded ? .complete : .failed,
        transaction: tx,
        errorCode: succeeded ? nil : "PAYMENT_ERROR",
        errorMessage: succeeded ? nil : "Transaction \(status)"
    )
}

func isTransactionComplete(_ tx: Transaction) -> Bool {
    tx.isComplete
}

/// After the user cancels the 3DS UI: one immediate status check, then a short
/// wait on the in-flight poll so a just-completed auth is not reported as canceled.
func reconcileCanceledThreeDS(
    fetchTransaction: () async throws -> Transaction,
    pollTask: Task<EngineResult, Error>,
    graceNanoseconds: UInt64 = threeDSCancelReconcileGraceNanoseconds
) async -> EngineResult {
    if let immediate = try? await fetchTransaction(), isTransactionComplete(immediate) {
        pollTask.cancel()
        return resultFromTransaction(immediate)
    }

    do {
        return try await withThrowingTaskGroup(of: EngineResult.self) { group in
            group.addTask {
                try await pollTask.value
            }
            group.addTask {
                try await Task.sleep(nanoseconds: graceNanoseconds)
                throw ThreeDSGraceTimeout()
            }

            do {
                guard let first = try await group.next() else {
                    group.cancelAll()
                    pollTask.cancel()
                    return EngineResult(status: .canceled, transaction: nil, errorCode: nil, errorMessage: nil)
                }
                group.cancelAll()
                pollTask.cancel()
                return first
            } catch is ThreeDSGraceTimeout {
                group.cancelAll()
                pollTask.cancel()
                return EngineResult(status: .canceled, transaction: nil, errorCode: nil, errorMessage: nil)
            } catch {
                group.cancelAll()
                pollTask.cancel()
                throw error
            }
        }
    } catch {
        pollTask.cancel()
        return EngineResult(status: .canceled, transaction: nil, errorCode: nil, errorMessage: nil)
    }
}
