import Foundation

struct DigitalWalletsService {
    let http: HTTPClient
    let env: PaymentEnvironment

    init(http: HTTPClient, env: PaymentEnvironment) {
        self.http = http
        self.env = env
    }

    func getParams(walletType: String, sessionToken: String) async throws -> WalletParams {
        let path = SdkConstants.digitalWalletParamsPath(walletType)
        let url = APIURL.make(base: env.apiNextBaseURL, path: path)
        let raw = try await http.getJSON(url: url, bearer: sessionToken)
        return WalletParams(apiMap: raw)
    }

    func validateMerchant(validationURL: String, sessionToken: String) async throws -> [String: Any] {
        let url = APIURL.make(base: env.apiNextBaseURL, path: SdkConstants.applePayValidateMerchantPath)
        return try await http.postJSON(
            url: url,
            body: ["validationURL": validationURL],
            bearer: sessionToken
        )
    }
}
