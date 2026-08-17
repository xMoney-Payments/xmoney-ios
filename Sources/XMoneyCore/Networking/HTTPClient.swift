import Foundation
import OSLog

final class HTTPClient {
    static var isDebugLoggingEnabled = false

    private static let logger = Logger(subsystem: "com.xmoney.paymentsheet", category: "HTTP")

    private static let sensitiveJSONKeys: Set<String> = [
        "authorization",
        "cardnumber",
        "card_number",
        "cardcvv",
        "cvv",
        "cvc",
        "pan",
        "number",
        "password",
        "token",
        "sessiontoken",
        "session_token",
        "bearer",
        "digitalwalletdata",
        "payload",
        "checksum",
    ]

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func getJSON(
        url: URL,
        bearer: String? = nil
    ) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        return try await sendExpectingJSON(request)
    }

    func postJSON(
        url: URL,
        body: [String: Any],
        bearer: String? = nil
    ) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await sendExpectingJSON(request)
    }

    func delete(url: URL, bearer: String?) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        _ = try await sendExpectingJSON(request)
    }

    func postMultipart(
        url: URL,
        fields: [String: String]
    ) async throws -> [String: Any] {
        let boundary = "xmoney-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        var body = Data()
        for (key, value) in fields {
            let safeKey = try Self.sanitizedMultipartToken(key, boundary: boundary, label: "name")
            let safeValue = try Self.sanitizedMultipartToken(value, boundary: boundary, label: "value")
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(safeKey)\"\r\n\r\n")
            body.append("\(safeValue)\r\n")
        }
        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        return try await sendExpectingJSON(request)
    }

    private func sendExpectingJSON(_ request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await session.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        Self.log(request: request, statusCode: statusCode, responseBody: data)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = (json["message"] as? String)
                ?? (json["error"] as? String)
                ?? "Request failed with status \(http.statusCode)"
            throw PaymentError.network(message)
        }
        return json
    }

    /// Opt-in request/response logging. Request bodies are never logged (multipart
    /// card submissions pass through here). Response bodies are redacted.
    private static func log(request: URLRequest, statusCode: Int, responseBody: Data) {
        guard isDebugLoggingEnabled else { return }

        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "?"
        let marker = (200...299).contains(statusCode) ? "✅" : "⛔️"

        #if os(iOS)
        logger.debug("[\(marker, privacy: .public)] \(method, privacy: .public) \(url, privacy: .private) -> \(statusCode)")
        #else
        logger.debug("\(marker) \(method) \(url) -> \(statusCode)")
        #endif

        if let json = try? JSONSerialization.jsonObject(with: responseBody),
           let redacted = redactSensitiveValues(in: json) {
            let body = String(describing: redacted)
            let truncated = body.count > 2000 ? String(body.prefix(2000)) + "…(truncated)" : body
            #if os(iOS)
            logger.debug("response: \(truncated, privacy: .private)")
            #else
            logger.debug("response: \(truncated)")
            #endif
        } else if !responseBody.isEmpty {
            logger.debug("response: <\(responseBody.count) bytes>")
        }
    }

    private static func redactSensitiveValues(in value: Any) -> Any? {
        switch value {
        case let dictionary as [String: Any]:
            var redacted: [String: Any] = [:]
            for (key, nested) in dictionary {
                if sensitiveJSONKeys.contains(key.lowercased()) {
                    redacted[key] = "<redacted>"
                } else if let nestedRedacted = redactSensitiveValues(in: nested) {
                    redacted[key] = nestedRedacted
                }
            }
            return redacted
        case let array as [Any]:
            return array.compactMap { redactSensitiveValues(in: $0) }
        default:
            return value
        }
    }

    private static func sanitizedMultipartToken(
        _ value: String,
        boundary: String,
        label: String
    ) throws -> String {
        if value.contains("\r") || value.contains("\n") || value.contains(boundary) {
            throw PaymentError.network("Invalid multipart field \(label)")
        }
        return value
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
