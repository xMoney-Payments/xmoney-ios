import Foundation

struct AccountService {
    let http: HTTPClient
    let env: PaymentEnvironment

    init(http: HTTPClient, env: PaymentEnvironment) {
        self.http = http
        self.env = env
    }

    func getSessionToken(orderPayload: String, orderChecksum: String) async throws -> String {
        let url = APIURL.make(base: env.apiNextBaseURL, path: SdkConstants.sessionTokenPath)
        let result = try await http.postJSON(
            url: url,
            body: ["payload": orderPayload, "checksum": orderChecksum]
        )
        guard let token = SessionTokenResponse(apiMap: result).token else {
            throw PaymentError.session("Missing session token")
        }
        return token
    }

    func validateAccount(
        card: CardInput,
        name: CardHolderName,
        currency: String,
        sessionToken: String
    ) async throws -> CardHolderVerificationResult {
        let payload = Self.buildValidationPayload(
            card: card,
            name: name,
            currency: currency,
            transactionLocalDateTime: Self.isoNow()
        )
        let url = APIURL.make(base: env.apiNextBaseURL, path: SdkConstants.accountValidationPath)
        let result = try await http.postJSON(url: url, body: payload, bearer: sessionToken)
        return AccountValidationResponse(apiMap: result).nameValidationResults
    }

    static func buildValidationPayload(
        card: CardInput,
        name: CardHolderName,
        currency: String,
        transactionLocalDateTime: String
    ) -> [String: Any] {
        let yearTrimmed = card.expiryYear.trimmingCharacters(in: .whitespacesAndNewlines)
        let year = yearTrimmed.count == 2 ? "20\(yearTrimmed)" : yearTrimmed
        let monthRaw = card.expiryMonth.trimmingCharacters(in: .whitespacesAndNewlines)
        let paddedMonth: String = {
            if monthRaw.count >= 2 { return String(monthRaw.suffix(2)) }
            return String(repeating: "0", count: 2 - monthRaw.count) + monthRaw
        }()
        return [
            "accountDetails": [
                "account": [
                    "type": "PAN",
                    "number": card.number,
                    "expiry": "\(year)-\(paddedMonth)",
                    "cvc": card.cvv,
                ],
                "name": name.toMap(),
            ],
            "currency": currency,
            "transactionLocalDateTime": transactionLocalDateTime,
        ]
    }

    static func isoNow() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }
}
