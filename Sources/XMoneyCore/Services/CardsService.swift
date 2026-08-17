import Foundation

struct CardsService {
    let http: HTTPClient
    let env: PaymentEnvironment

    init(http: HTTPClient, env: PaymentEnvironment) {
        self.http = http
        self.env = env
    }

    func getCards(sessionToken: String) async throws -> [SavedCard] {
        let url = APIURL.make(
            base: env.apiNextBaseURL,
            path: SdkConstants.cardsPath,
            query: [URLQueryItem(name: "hasToken", value: "true")]
        )
        let result = try await http.getJSON(url: url, bearer: sessionToken)
        return SavedCardsResponse(apiMap: result).data
    }

    func deleteCard(cardId: String, sessionToken: String) async throws {
        let url = APIURL.make(
            base: env.apiNextBaseURL,
            path: "\(SdkConstants.cardsPath)/\(cardId)"
        )
        try await http.delete(url: url, bearer: sessionToken)
    }
}
