import PassKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

extension ApplePayMerchantSessionParser {
    static func merchantSession(from response: [String: Any]) -> PKPaymentMerchantSession? {
        guard let dictionary = merchantSessionDictionary(from: response) else { return nil }
        return PKPaymentMerchantSession(dictionary: dictionary)
    }
}
