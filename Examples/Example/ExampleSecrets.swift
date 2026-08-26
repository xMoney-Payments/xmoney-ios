import Foundation

enum ExampleSecrets {
    static var publicKey: String { string("XMPublicKey") }
    static var apiKey: String { string("XMAPIKey") }
    static var apiBase: String {
        normalizedBaseURL(string("XMAPIHost", fallback: "demo.xmoney.com"))
    }

    /// xcconfig treats `//` as a comment, so `https://host` becomes `https:`.
    static func normalizedBaseURL(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "https:" || trimmed == "http:" {
            return "https://demo.xmoney.com"
        }
        if trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://") {
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return "https://\(trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
    }
    static var currency: String { string("XMCurrency", fallback: "EUR") }
    static var orderDescription: String {
        string("XMDescription", fallback: "Embeddable Configuration - Payment Card")
    }
    static var merchantIdentifier: String { string("XMMerchantIdentifier") }

    private static func string(_ key: String, fallback: String = "") -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? fallback
    }
}
