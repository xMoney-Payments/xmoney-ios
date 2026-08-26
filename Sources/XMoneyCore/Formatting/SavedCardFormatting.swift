import Foundation

package enum SavedCardFormatting {
    package static func savedCardsSummarySubtitle(_ cards: [SavedCard]) -> String {
        cards
            .map { savedCardIssuerLabel($0) }
            .filter { $0 != "Card" }
            .reduce(into: [String]()) { acc, label in
                if !acc.contains(label) { acc.append(label) }
            }
            .joined(separator: ", ")
    }

    package static func savedCardDisplayName(_ card: SavedCard) -> String {
        let issuer = savedCardIssuerLabel(card)
        let masked = savedCardMaskedNumber(card)
        return masked.isEmpty ? issuer : "\(issuer) \(masked)"
    }

    package static func savedCardMeta(_ card: SavedCard, locale: String) -> String {
        let brand = savedCardBrandLabel(card)
        let expiry = card.cardExpiryDate?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        let base = expiry.isEmpty ? brand : "\(brand) · \(expiry)"
        if card.isDefault {
            return "\(base) · \(Strings.text("sheet.default", locale: locale))"
        }
        return base
    }

    package static func savedCardBrandForIcon(_ card: SavedCard) -> String? {
        savedCardNetworkBrand(card)
    }

    package static func savedCardIssuerLabel(_ card: SavedCard) -> String {
        if let bank = card.bankName?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !bank.isEmpty {
            return bank
        }
        if let cardType = card.cardType?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
           !cardType.isEmpty,
           !isKnownCardBrand(cardType) {
            return cardType
        }
        let masked = card.cardNumber?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        if !masked.isEmpty {
            let prefix = masked.prefix { char in
                char != "•" && char != "*" && !char.isNumber
            }
            let trimmed = String(prefix).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "Card"
    }

    package static func savedCardMaskedNumber(_ card: SavedCard) -> String {
        let raw = card.cardNumber?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        if raw.isEmpty { return "••••" }

        if let regex = try? NSRegularExpression(pattern: "[•*]{4}\\s*(\\d{4})"),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
           let range = Range(match.range(at: 1), in: raw) {
            return "•••• \(raw[range])"
        }

        let digits = raw.filter { $0.isNumber }
        if digits.count >= 4 {
            return "•••• \(digits.suffix(4))"
        }
        return raw
    }

    // MARK: - Private

    private static func savedCardBrandLabel(_ card: SavedCard) -> String {
        guard let brand = savedCardNetworkBrand(card) else { return "Card" }
        switch brand.lowercased() {
        case "visa": return "Visa"
        case "mastercard": return "Mastercard"
        case "maestro": return "Maestro"
        case "amex", "american express": return "Amex"
        default:
            return brand.prefix(1).uppercased() + brand.dropFirst()
        }
    }

    private static func savedCardNetworkBrand(_ card: SavedCard) -> String? {
        if let brand = card.cardBrand?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !brand.isEmpty {
            return brand
        }
        if let cardType = card.cardType?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
           !cardType.isEmpty,
           isKnownCardBrand(cardType) {
            return cardType
        }
        return nil
    }

    package static func isKnownCardBrand(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
        return [
            "visa",
            "mastercard",
            "maestro",
            "amex",
            "american express",
            "discover",
            "diners",
            "jcb",
        ].contains(normalized)
    }
}
