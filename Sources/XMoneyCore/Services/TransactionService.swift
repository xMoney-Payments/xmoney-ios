import Foundation

struct TransactionService {
    let http: HTTPClient
    let env: PaymentEnvironment

    init(http: HTTPClient, env: PaymentEnvironment) {
        self.http = http
        self.env = env
    }

    func getTransaction(id: String, sessionToken: String) async throws -> Transaction {
        let url = APIURL.make(
            base: env.apiNextBaseURL,
            path: "\(SdkConstants.transactionsPath)/\(id)"
        )
        let result = try await http.getJSON(url: url, bearer: sessionToken)
        return Transaction(apiMap: result)
    }

    func poll(
        transactionId: String,
        sessionToken: String,
        interval: TimeInterval = 2.0,
        timeout: TimeInterval = 600.0
    ) async throws -> Transaction {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let tx = try await getTransaction(id: transactionId, sessionToken: sessionToken)
            if tx.isComplete { return tx }
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        throw PaymentError.pollTimeout("Polling timed out")
    }
}
