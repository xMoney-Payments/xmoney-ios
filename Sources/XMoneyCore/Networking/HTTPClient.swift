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
        "digitalwallettype",
        "payload",
        "checksum",
        "email",
        "phone",
        "firstname",
        "lastname",
        "fullname",
        "address",
        "city",
        "zipcode",
        "postalcode",
        "region",
        "country",
        "customerdetails",
    ]

    private let session: URLSession
    /// Test seam. When set, used instead of `URLSession` (CI iOS 18 ignores `URLProtocol`).
    private let execute: (@Sendable (URLRequest) async throws -> (Data, URLResponse))?

    init(
        session: URLSession = .shared,
        execute: (@Sendable (URLRequest) async throws -> (Data, URLResponse))? = nil
    ) {
        self.session = session
        self.execute = execute
    }

    /// With `exposingStatus`, a non-2xx response throws `HTTPStatusFailure` instead of `PaymentError`.
    func getJSON(
        url: URL,
        bearer: String? = nil,
        exposingStatus: Bool = false
    ) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        return try await sendExpectingJSON(request, exposingStatus: exposingStatus)
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
        fields: [String: String],
        accept: String
    ) async throws -> [String: Any] {
        let boundary = "xmoney-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyBrowserHeaders(&request)
        // Crypto asks for JSON. Accept */* plus a Safari user agent makes TwisPay return HTML.
        request.setValue(accept, forHTTPHeaderField: "Accept")
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

        Self.logOutgoingMultipart(url: url, fields: fields)
        return try await sendExpectingJSON(request)
    }

    private func sendExpectingJSON(
        _ request: URLRequest,
        exposingStatus: Bool = false
    ) async throws -> [String: Any] {
        let (data, response): (Data, URLResponse)
        do {
            if let execute {
                (data, response) = try await execute(request)
            } else {
                (data, response) = try await session.data(for: request)
            }
        } catch {
            let mapped = Self.mappedCancellation(error)
            if !(mapped is CancellationError) {
                Self.logTransportFailure(request: request, error: error)
            }
            throw mapped
        }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        Self.log(request: request, statusCode: statusCode, responseBody: data)
        Self.logUnreadablePaymentResponse(
            request: request,
            statusCode: statusCode,
            json: json,
            responseBody: data,
            contentType: (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")
        )

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = (json["message"] as? String)
                ?? (json["error"] as? String)
                ?? "Request failed with status \(http.statusCode)"
            Self.logHTTPFailure(
                request: request,
                statusCode: http.statusCode,
                message: message,
                responseBody: data
            )
            let error = PaymentError.network(message)
            if exposingStatus {
                throw HTTPStatusFailure(statusCode: http.statusCode, error: error)
            }
            throw error
        }
        return json
    }

    /// URLSession often surfaces task cancel as `URLError.cancelled` ("cancelled")
    /// instead of `CancellationError`. Map both so overlapping binds / `.task`
    /// teardown are not reported as payment failures.
    private static func mappedCancellation(_ error: Error) -> Error {
        if error is CancellationError { return CancellationError() }
        if let url = error as? URLError, url.code == .cancelled { return CancellationError() }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled {
            return CancellationError()
        }
        return error
    }

    /// Field names only. Values such as the order payload, checksum, and card data stay out of the log.
    private static func logOutgoingMultipart(url: URL, fields: [String: String]) {
        let kind = PaymentKind.kind(fields: fields)
        let names = fields.keys.sorted().joined(separator: ",")
        let payloadChars = fields["jsonRequest"]?.count ?? 0
        let accept = PaymentKind.acceptHeader(fields: fields)
        logger.info(
            "POST \(url.absoluteString, privacy: .public) kind=\(kind, privacy: .public) accept=\(accept, privacy: .public) jsonRequestChars=\(payloadChars) fields=\(names, privacy: .public)"
        )
    }

    /// A 2xx payment body with no numeric `code` is what `parse` reports as "Invalid payment result".
    private static func logUnreadablePaymentResponse(
        request: URLRequest,
        statusCode: Int,
        json: [String: Any],
        responseBody: Data,
        contentType: String?
    ) {
        guard request.url?.absoluteString.contains("payment-request") == true else { return }
        guard !isPaymentSuccessCode(json["code"]) else { return }
        let keys = json.keys.sorted().joined(separator: ",")
        logger.error(
            "payment-request http=\(statusCode) content-type=\(contentType ?? "", privacy: .public) missing code keys=\(keys, privacy: .public) path=\(Self.publicRequestPath(request), privacy: .public)"
        )
        guard isDebugLoggingEnabled else { return }
        let detail = visibleHTMLText(responseBody) ?? failureSnippet(responseBody)
        logger.error("payment-request detail body=\(detail, privacy: .private)")
    }

    /// The hosted TwisPay page is HTML. The stylesheet links hide the message the page actually shows.
    private static func visibleHTMLText(_ data: Data) -> String? {
        guard let html = String(data: data, encoding: .utf8) else { return nil }
        let prefix = html.prefix(64).lowercased()
        guard prefix.contains("<!doctype") || prefix.contains("<html") else { return nil }
        var text = html
        for pattern in ["(?is)<script\\b[^>]*>.*?</script>", "(?is)<style\\b[^>]*>.*?</style>", "(?is)<[^>]+>"] {
            text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        let collapsed = text.split { $0.isWhitespace }.joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return collapsed.count > 400 ? String(collapsed.prefix(400)) + "…" : collapsed
    }

    private static func isPaymentSuccessCode(_ value: Any?) -> Bool {
        guard let code = APIMap.intValue(value) else { return false }
        return code == 200 || code == 201
    }

    /// Method and path only. Query strings can carry tokens, so they stay out of public logs.
    private static func publicRequestPath(_ request: URLRequest) -> String {
        guard let url = request.url else { return "?" }
        let path = url.path
        return path.isEmpty ? "/" : path
    }

    private static func logTransportFailure(request: URLRequest, error: Error) {
        let ns = error as NSError
        logger.error(
            "request failed \(request.httpMethod ?? "?", privacy: .public) \(Self.publicRequestPath(request), privacy: .public) domain=\(ns.domain, privacy: .public) code=\(ns.code)"
        )
        guard isDebugLoggingEnabled else { return }
        logger.error("request failed detail \(error.localizedDescription, privacy: .private)")
    }

    private static func logHTTPFailure(
        request: URLRequest,
        statusCode: Int,
        message: String,
        responseBody: Data
    ) {
        logger.error(
            "request failed \(request.httpMethod ?? "?", privacy: .public) \(Self.publicRequestPath(request), privacy: .public) status=\(statusCode)"
        )
        guard isDebugLoggingEnabled else { return }
        let snippet = failureSnippet(responseBody)
        logger.error(
            "request failed detail message=\(message, privacy: .private) body=\(snippet, privacy: .private)"
        )
    }

    private static func failureSnippet(_ responseBody: Data) -> String {
        let raw: String
        if let json = try? JSONSerialization.jsonObject(with: responseBody),
           let redacted = redactSensitiveValues(in: json) {
            raw = String(describing: redacted)
        } else {
            raw = "<\(responseBody.count) bytes>"
        }
        return raw.count > 500 ? String(raw.prefix(500)) + "…(truncated)" : raw
    }

    /// Opt-in request/response logging. Request bodies are never logged (multipart)
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

    static func redactSensitiveValues(in value: Any) -> Any? {
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

    /// The secure API copies these into the 3DS browser data, so only the payment request needs them.
    private func applyBrowserHeaders(_ request: inout URLRequest) {
        for (name, value) in DeviceMetadata.httpHeaders() {
            request.setValue(value, forHTTPHeaderField: name)
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

struct HTTPStatusFailure: Error {
    let statusCode: Int
    let error: PaymentError
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
