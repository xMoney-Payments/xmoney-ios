import Foundation
import XMoneyCore

/**
 * Demo-only checkout backend for the example app.
 *
 * Do **not** copy this into a merchant app. This client sends `API_KEY` because
 * the public demo server (`demo.xmoney.com`) is a stand-in for *your* backend.
 *
 * In production:
 * - The iOS app holds only `publicKey`
 * - Your server creates the order and returns `payload` + `checksum`
 * - The app builds `PaymentIntent` from those two values
 */
enum DemoCheckoutBackend {
    static func secretsError() -> String? {
        let key = ExampleSecrets.publicKey
        if key.isEmpty || key.localizedCaseInsensitiveContains("replace") {
            return "Set PUBLIC_KEY in Examples/Secrets.xcconfig"
        }
        let api = ExampleSecrets.apiKey
        if api.isEmpty || api.localizedCaseInsensitiveContains("your_api_key") {
            return "Set API_KEY in Examples/Secrets.xcconfig"
        }
        return nil
    }

    static func createPaymentIntent(
        amountMinor: Int64 = SAMPLE_AMOUNT_MINOR,
        currency: String = ExampleSecrets.currency,
        description: String = ExampleSecrets.orderDescription
    ) async throws -> PaymentIntent {
        if let message = secretsError() {
            throw DemoBackendError(message)
        }

        let amount = Decimal(amountMinor) / 100
        let body: [String: Any] = [
            "amount": NSDecimalNumber(decimal: amount).doubleValue,
            "currency": currency,
            "description": description,
            "publicKey": ExampleSecrets.publicKey,
            "apiKey": ExampleSecrets.apiKey,
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let base = ExampleSecrets.apiBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/orders") else {
            throw DemoBackendError("Invalid API host")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        request.timeoutInterval = 30

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            let json = (try? JSONSerialization.jsonObject(with: responseData)) as? [String: Any] ?? [:]
            if http?.statusCode ?? 500 >= 400 {
                let message = (json["error"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? (json["message"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? "HTTP \(http?.statusCode ?? 0)"
                throw DemoBackendError(message)
            }
            let payload = json["payload"] as? String ?? ""
            let checksum = json["checksum"] as? String ?? ""
            if payload.isEmpty || checksum.isEmpty {
                throw DemoBackendError("Missing payload or checksum in API response")
            }
            return PaymentIntent(
                orderPayload: OrderPayload(payload),
                orderChecksum: OrderChecksum(checksum)
            )
        } catch {
            if isCancellation(error) { throw CancellationError() }
            throw error
        }
    }
}

struct DemoBackendError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
