import PassKit
#if !COCOAPODS
import XMoneyCore
#endif

enum ApplePayCapabilities {
    static func canMakePayments() -> Bool {
        PKPaymentAuthorizationController.canMakePayments()
    }

    static func mapNetworks(_ networks: [String]) -> [PKPaymentNetwork] {
        var result: [PKPaymentNetwork] = []
        for network in networks {
            switch network.lowercased() {
            case "visa": result.append(.visa)
            case "mastercard": result.append(.masterCard)
            case "amex": result.append(.amex)
            case "discover": result.append(.discover)
            default: break
            }
        }
        return result.isEmpty ? [.visa, .masterCard] : result
    }
}
