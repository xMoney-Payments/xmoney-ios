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

    /// Base64 strings from the backend may be unpadded; normalize length.
    private static func padded(_ value: String) -> String {
        let remainder = value.count % 4
        guard remainder > 0 else { return value }
        return value + String(repeating: "=", count: 4 - remainder)
    }
}
