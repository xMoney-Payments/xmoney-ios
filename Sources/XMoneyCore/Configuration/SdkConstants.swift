import Foundation

enum SdkConstants {
    static let secureBaseURLStage = "https://secure-stage.xmoney.com"
    static let secureBaseURLProd = "https://secure.xmoney.com"
    static let apiNextBaseURLStage = "https://api-stage-next.xmoney.com"
    static let apiNextBaseURLProd = "https://api-next.xmoney.com"

    static let confirmPaymentPath = "payment-request"

    // api-next inline-checkout endpoints
    static let sessionTokenPath = "api/v1/inline-checkout/session-token"
    static let configPath = "api/v1/inline-checkout/config"
    static let cardsPath = "api/v1/inline-checkout/cards"
    static let transactionsPath = "api/v1/inline-checkout/transactions"
    static let accountValidationPath = "api/v1/account-validation"

    // digital wallet endpoints
    static func digitalWalletParamsPath(_ walletType: String) -> String {
        "api/v1/digital-wallet/\(walletType)/params"
    }
    static let applePayValidateMerchantPath =
        "api/v1/digital-wallet/applePay/validate-merchant"
}
