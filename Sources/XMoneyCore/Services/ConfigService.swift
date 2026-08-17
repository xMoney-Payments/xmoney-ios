import Foundation

struct ConfigService {
    let http: HTTPClient
    let env: PaymentEnvironment

    init(http: HTTPClient, env: PaymentEnvironment) {
        self.http = http
        self.env = env
    }

    func getSiteConfig(sessionToken: String) async throws -> SiteConfig {
        let url = APIURL.make(base: env.apiNextBaseURL, path: SdkConstants.configPath)
        let result = try await http.getJSON(url: url, bearer: sessionToken)
        return SiteConfig(apiMap: result)
    }
}
