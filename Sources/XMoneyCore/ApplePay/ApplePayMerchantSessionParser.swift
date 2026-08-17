import Foundation

package enum ApplePayMerchantSessionParser {
    package static let gatewayValidationURL =
        "https://apple-pay-gateway.apple.com/paymentservices/startSession"

    package static func merchantSessionDictionary(from response: [String: Any]) -> [String: Any]? {
        if let data = response["data"] as? [String: Any] {
            return data
        }
        return response
    }
}
