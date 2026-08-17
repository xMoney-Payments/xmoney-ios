import Foundation

struct PaymentService {
    let http: HTTPClient
    let env: PaymentEnvironment

    init(http: HTTPClient, env: PaymentEnvironment) {
        self.http = http
        self.env = env
    }

    func cardFields(card: CardInput, orderPayload: String, orderChecksum: String) -> [String: String] {
        var fields: [String: String] = [
            "cardNumber": CardFieldValidators.normalizeDigits(card.number),
            "cardExpiryMonth": card.expiryMonth,
            "cardExpiryYear": card.expiryYear,
            "cardCvv": card.cvv,
            "jsonRequest": orderPayload,
            "checksum": orderChecksum,
        ]
        if card.saveCard { fields["saveCard"] = "true" }
        if let name = card.holderName, !name.isEmpty { fields["cardHolderName"] = name }
        DeviceMetadata.fields().forEach { fields[$0.key] = $0.value }
        return fields
    }

    func savedCardFields(cardId: String, orderPayload: String, orderChecksum: String) -> [String: String] {
        var fields: [String: String] = [
            "jsonRequest": orderPayload,
            "checksum": orderChecksum,
            "cardId": cardId,
        ]
        DeviceMetadata.fields().forEach { fields[$0.key] = $0.value }
        return fields
    }

    func walletFields(
        walletType: String,
        token: String,
        orderPayload: String,
        orderChecksum: String
    ) -> [String: String] {
        var fields: [String: String] = [
            "jsonRequest": orderPayload,
            "checksum": orderChecksum,
            "digitalWalletType": walletType,
            "digitalWalletData": token,
        ]
        DeviceMetadata.fields().forEach { fields[$0.key] = $0.value }
        return fields
    }

    func confirmPayment(fields: [String: String]) async throws -> ConfirmPaymentResponse {
        let url = APIURL.make(base: env.secureBaseURL, path: SdkConstants.confirmPaymentPath)
        let result = try await http.postMultipart(url: url, fields: fields)
        return ConfirmPaymentResponse(apiMap: result)
    }

    struct ParsedResponse {
        let submission: PaymentSubmissionResult
        let transactionId: String?
    }

    func parse(_ result: ConfirmPaymentResponse) throws -> ParsedResponse {
        guard let data = result.data, result.code == 200 else {
            let message = result.status.map { "Payment error: \($0)" } ?? "Invalid payment result"
            throw PaymentError.payment(message)
        }

        let transaction = data.transaction
        let transactionId = transaction?.transactionId
        let status = transaction?.status
        let responseStatus = transaction?.responseStatus

        if status == "pending-redirect", responseStatus == "3d-pending" {
            let urlString = data.threeDSFlowUrl ?? transaction?.redirectUrl
            if let urlString, let url = URL(string: urlString), url.scheme?.lowercased() == "https" {
                return ParsedResponse(submission: .needs3DS(url: url), transactionId: transactionId)
            }
            throw PaymentError.threeDS("Missing 3DS URL")
        }

        if let backURLString = data.orderRequestBackUrl,
           var components = URLComponents(string: backURLString) {
            var query = components.queryItems ?? []
            if let encoded = data.result {
                query.append(URLQueryItem(name: "result", value: encoded))
            }
            if let responseStatus {
                query.append(URLQueryItem(name: "status", value: responseStatus))
            }
            components.queryItems = query
            if let url = components.url {
                return ParsedResponse(submission: .redirect(url: url), transactionId: transactionId)
            }
        }

        if let transactionId {
            return ParsedResponse(submission: .transaction(id: transactionId), transactionId: transactionId)
        }
        throw PaymentError.payment("Invalid payment result")
    }
}
