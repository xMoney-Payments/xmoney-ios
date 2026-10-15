import Foundation
#if DEBUG
import OSLog
#endif

struct InlineCheckoutFieldsService {
    let http: HTTPClient
    let env: PaymentEnvironment

    init(http: HTTPClient, env: PaymentEnvironment) {
        self.http = http
        self.env = env
    }

    #if DEBUG
    private static let logger = Logger(subsystem: "com.xmoney.paymentsheet", category: "customer-details")
    #endif

    /// `[]` when the request cannot be made or fails. An empty list turns collection off.
    func getFields(sessionToken: String) async -> [String] {
        guard !sessionToken.isEmpty else { return [] }
        do {
            let url = APIURL.make(base: env.apiNextBaseURL, path: SdkConstants.inlineCheckoutFieldsPath)
            let result = try await http.getJSON(url: url, bearer: sessionToken)
            let fields = APIMap.stringList(result["data"])
            #if DEBUG
            Self.logger.debug("inline-checkout fields: \(fields.joined(separator: ","), privacy: .public)")
            #endif
            return fields
        } catch {
            #if DEBUG
            Self.logger.debug("inline-checkout fields failed: \(String(describing: error), privacy: .public)")
            #endif
            return []
        }
    }
}
