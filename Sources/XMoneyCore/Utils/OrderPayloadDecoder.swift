import Foundation

enum OrderPayloadDecoder {
    static func decode(_ orderPayload: String) -> OrderInput? {
        guard let data = Data(base64Encoded: padded(orderPayload)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return OrderInput(apiMap: json)
    }

    static func info(from orderPayload: String) -> OrderPayloadInfo {
        decode(orderPayload)?.toInfo() ?? OrderPayloadInfo(
            cardTransactionMode: nil,
            isVerifyCard: false,
            amount: nil,
            currency: nil,
            externalOrderId: nil,
            isRecurring: false
        )
    }

    static func backUrlHost(from orderPayload: String) -> String? {
        backURL(from: orderPayload)?.host
    }

    static func backURL(from orderPayload: String) -> URL? {
        guard let backUrl = decode(orderPayload)?.backUrl, !backUrl.isEmpty else { return nil }
        return URL(string: backUrl)
    }

    static func matchesReturnURL(_ returnURL: URL, backURL: URL) -> Bool {
        guard (returnURL.scheme ?? "").lowercased() == (backURL.scheme ?? "").lowercased() else {
            return false
        }
        guard (returnURL.host ?? "").lowercased() == (backURL.host ?? "").lowercased() else {
            return false
        }
        let returnPath = normalizedPath(returnURL.path)
        let backPath = normalizedPath(backURL.path)
        if returnPath == backPath { return true }
        if backPath == "/" { return returnPath.hasPrefix("/") }
        return returnPath.hasPrefix(backPath + "/")
    }

    private static func normalizedPath(_ path: String) -> String {
        if path.isEmpty { return "/" }
        if path.count > 1, path.hasSuffix("/") { return String(path.dropLast()) }
        return path
    }

    /// Base64 strings from the backend may be unpadded; normalize length.
    private static func padded(_ value: String) -> String {
        let remainder = value.count % 4
        guard remainder > 0 else { return value }
        return value + String(repeating: "=", count: 4 - remainder)
    }
}
