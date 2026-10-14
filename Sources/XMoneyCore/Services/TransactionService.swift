import Foundation

struct TransactionService {
    let http: HTTPClient
    let env: PaymentEnvironment

    init(http: HTTPClient, env: PaymentEnvironment) {
        self.http = http
        self.env = env
    }

    func getTransaction(id: String, sessionToken: String) async throws -> Transaction {
        do {
            return try await fetch(id: id, sessionToken: sessionToken)
        } catch let failure as HTTPStatusFailure {
            throw failure.error
        }
    }

    /// Transient network and server errors are retried until the deadline. The shopper may be
    /// in a bank app, and iOS drops in-flight requests when it suspends this one.
    /// Before any error is surfaced, including the timeout, the transaction is fetched once more.
    func poll(
        transactionId: String,
        sessionToken: String,
        interval: TimeInterval = 2.0,
        timeout: TimeInterval = 600.0
    ) async throws -> Transaction {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            do {
                let tx = try await fetch(id: transactionId, sessionToken: sessionToken)
                if tx.isComplete { return tx }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard Self.isTransient(error) else {
                    return try await finalCheck(
                        id: transactionId,
                        sessionToken: sessionToken,
                        orThrow: Self.surfaced(error)
                    )
                }
            }
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        return try await finalCheck(
            id: transactionId,
            sessionToken: sessionToken,
            orThrow: PaymentError.pollTimeout("Polling timed out")
        )
    }

    /// Only a real 4xx or a malformed request stops the poll early. Returning from the background,
    /// iOS reports errors such as `NSPOSIXErrorDomain` 53 that are not `URLError`s at all.
    static func isTransient(_ error: Error) -> Bool {
        if let failure = error as? HTTPStatusFailure {
            return failure.statusCode == 408
                || failure.statusCode == 429
                || !(400...499).contains(failure.statusCode)
        }
        if let urlError = error as? URLError {
            return !permanentURLErrorCodes.contains(urlError.code)
        }
        return true
    }

    private static let permanentURLErrorCodes: Set<URLError.Code> = [
        .badURL,
        .unsupportedURL,
        .appTransportSecurityRequiresSecureConnection,
    ]

    private static func surfaced(_ error: Error) -> Error {
        (error as? HTTPStatusFailure)?.error ?? error
    }

    private func finalCheck(id: String, sessionToken: String, orThrow error: Error) async throws -> Transaction {
        try Task.checkCancellation()
        if let tx = try? await fetch(id: id, sessionToken: sessionToken), tx.isComplete {
            return tx
        }
        throw error
    }

    private func fetch(id: String, sessionToken: String) async throws -> Transaction {
        let url = APIURL.make(
            base: env.apiNextBaseURL,
            path: "\(SdkConstants.transactionsPath)/\(id)"
        )
        let result = try await http.getJSON(url: url, bearer: sessionToken, exposingStatus: true)
        return Transaction(apiMap: result)
    }
}
