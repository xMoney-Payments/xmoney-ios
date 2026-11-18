import Foundation

struct PaymentService {
    let http: HTTPClient
    let env: PaymentEnvironment

    init(http: HTTPClient, env: PaymentEnvironment) {
        self.http = http
        self.env = env
    }

    func cardFields(
        card: CardInput,
        orderPayload: String,
        orderChecksum: String,
        customerDetails: CustomerDetails? = nil
    ) -> [String: String] {
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
        appendCustomerDetails(customerDetails, to: &fields)
        DeviceMetadata.fields().forEach { fields[$0.key] = $0.value }
        return fields
    }

    func savedCardFields(
        cardId: String,
        orderPayload: String,
        orderChecksum: String,
        customerDetails: CustomerDetails? = nil
    ) -> [String: String] {
        var fields: [String: String] = [
            "jsonRequest": orderPayload,
            "checksum": orderChecksum,
            "cardId": cardId,
        ]
        appendCustomerDetails(customerDetails, to: &fields)
        DeviceMetadata.fields().forEach { fields[$0.key] = $0.value }
        return fields
    }

    func walletFields(
        walletType: String,
        token: String,
        orderPayload: String,
        orderChecksum: String,
        customerDetails: CustomerDetails? = nil
    ) -> [String: String] {
        var fields: [String: String] = [
            "jsonRequest": orderPayload,
            "checksum": orderChecksum,
            "digitalWalletType": walletType,
            "digitalWalletData": token,
        ]
        appendCustomerDetails(customerDetails, to: &fields)
        DeviceMetadata.fields().forEach { fields[$0.key] = $0.value }
        return fields
    }

    func cryptoFields(
        orderPayload: String,
        orderChecksum: String,
        customerDetails: CustomerDetails? = nil
    ) -> [String: String] {
        var fields: [String: String] = [
            "jsonRequest": orderPayload,
            "checksum": orderChecksum,
            "transactionType": "crypto",
        ]
        appendCustomerDetails(customerDetails, to: &fields)
        DeviceMetadata.fields().forEach { fields[$0.key] = $0.value }
        return fields
    }

    private func appendCustomerDetails(_ details: CustomerDetails?, to fields: inout [String: String]) {
        guard let json = details?.apiJSON() else { return }
        fields["customerDetails"] = json
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
        guard let data = result.data, result.code == 200 || result.code == 201 else {
            let message = result.status.map { "Payment error: \($0)" } ?? "Invalid payment result"
            throw PaymentError.payment(message)
        }

        let transaction = data.transaction
        let transactionId = transaction?.transactionId ?? data.transactionId
        let status = transaction?.status
        let responseStatus = transaction?.responseStatus

        if status == "pending-redirect", responseStatus == "3d-pending" {
            let urlString = data.threeDSFlowUrl ?? transaction?.redirectUrl
            if let urlString, let url = URL(string: urlString), url.scheme?.lowercased() == "https" {
                return ParsedResponse(submission: .needs3DS(url: url), transactionId: transactionId)
            }
            throw PaymentError.threeDS("Missing 3DS URL")
        }

        if data.isRedirect || data.is3d {
            let url = try gatewayRedirectURL(data)
            return ParsedResponse(submission: .needs3DS(url: url), transactionId: transactionId)
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

    /// The challenge opens in `SFSafariViewController`, which can only load GET URLs.
    private func gatewayRedirectURL(_ data: ConfirmPaymentData) throws -> URL {
        guard let urlString = data.threeDSFlowUrl ?? data.redirectUrl,
              var components = URLComponents(string: urlString),
              components.scheme?.lowercased() == "https" else {
            throw PaymentError.threeDS("Missing 3DS URL")
        }
        guard data.redirectFormMethod == "GET" else {
            throw PaymentError.threeDS("Unsupported 3DS redirect method")
        }
        if !data.redirectParams.isEmpty {
            var query = components.queryItems ?? []
            for (key, value) in data.redirectParams.sorted(by: { $0.key < $1.key }) {
                query.append(URLQueryItem(name: key, value: value))
            }
            components.queryItems = query
        }
        guard let url = components.url else {
            throw PaymentError.threeDS("Missing 3DS URL")
        }
        return url
    }
}
