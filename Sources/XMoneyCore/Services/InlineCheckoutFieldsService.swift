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

    /// `unavailable` is true when the request cannot be made or fails.
    /// A successful response may still list no fields.
    func getFields(sessionToken: String) async -> InlineFieldsResult {
        guard !sessionToken.isEmpty else { return InlineFieldsResult(fields: [], unavailable: true) }
        do {
            let url = APIURL.make(base: env.apiNextBaseURL, path: SdkConstants.inlineCheckoutFieldsPath)
            let result = try await http.getJSON(url: url, bearer: sessionToken)
            let fields = APIMap.stringList(result["data"])
            #if DEBUG
            Self.logger.debug("inline-checkout fields: \(fields.joined(separator: ","), privacy: .public)")
            #endif
            return InlineFieldsResult(fields: fields, unavailable: false)
        } catch {
            #if DEBUG
            Self.logger.debug("inline-checkout fields failed: \(String(describing: error), privacy: .public)")
            #endif
            return InlineFieldsResult(fields: [], unavailable: true)
        }
    }
}

struct InlineFieldsResult: Sendable {
    var fields: [String]
    var unavailable: Bool
}
