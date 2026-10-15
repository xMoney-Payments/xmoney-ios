import Foundation

package struct AddressFormat: Equatable, Sendable {
    package let postalType: String
    package let showRegion: Bool
    package let showPostal: Bool
    package let regionType: String?
    package let postalPattern: NSRegularExpression
    package let skipPostalFormat: Bool

    package var regionLabelKey: String { "personalDetails.region.\(regionType ?? "generic")" }
    package var regionPlaceholderKey: String { "personalDetails.region.\(regionType ?? "generic")Placeholder" }
    package var regionSelectKey: String { "personalDetails.region.\(regionType ?? "generic")Select" }
    package var regionRequiredError: String { regionType.map { "\($0)Required" } ?? "regionRequired" }

    package var postalLabelKey: String { "personalDetails.postal.\(postalType)" }
    package var postalPlaceholderKey: String { "personalDetails.postal.\(postalType)Placeholder" }
    package var postalRequiredError: String { "\(postalType)Required" }
    package var postalInvalidError: String { "\(postalType)Invalid" }
}

package enum AddressFormats {
    private static let defaultPostalType = "postalCode"
    private static let defaultPattern = pattern("^[A-Za-z0-9][A-Za-z0-9\\s-]{1,11}$")

    package static let noPostalCountries: Set<String> = [
        "AE", "AG", "AO", "AW", "BF", "BI", "BJ", "BO", "BS", "BW", "BZ", "CD", "CF", "CG", "CI",
        "CK", "CM", "DJ", "DM", "ER", "FJ", "GA", "GD", "GH", "GM", "GN", "GQ", "GW", "GY", "HK",
        "JM", "KE", "KI", "KM", "KN", "LC", "LR", "LS", "LY", "ML", "MR", "MW", "NA", "NE", "NR",
        "NU", "PA", "RW", "SB", "SC", "SL", "SO", "SR", "SS", "ST", "SZ", "TD", "TG", "TL", "TO",
        "TV", "TZ", "UG", "VU", "WS", "YE", "ZM", "ZW",
    ]

    package static let regionTypeByCountry: [String: String] = [
        "AD": "province", "AE": "emirate", "AM": "province", "AR": "province", "AU": "state",
        "BB": "parish", "BR": "state", "BS": "island", "BY": "oblast", "CA": "province",
        "CL": "province", "CN": "province", "CO": "department", "CR": "province", "CV": "island",
        "EG": "province", "ES": "province", "HK": "area", "HN": "department", "ID": "province",
        "IE": "county", "IN": "state", "IQ": "province", "IT": "province", "JM": "parish",
        "JP": "prefecture", "KI": "island", "KN": "island", "KR": "do_si", "KY": "island",
        "KZ": "province", "MN": "province", "MX": "state", "MY": "state", "MZ": "province",
        "NG": "state", "NI": "department", "NR": "district", "PA": "province", "PE": "province",
        "PF": "island", "PG": "province", "PH": "province", "RU": "oblast", "SO": "province",
        "SR": "province", "SV": "province", "TH": "province", "TR": "province", "TV": "island",
        "TW": "county", "UA": "oblast", "US": "state", "UY": "province", "UZ": "province",
        "VE": "state", "VN": "province",
    ]

    package static func regionType(countryCode: String) -> String? {
        let code = normalize(countryCode)
        guard !code.isEmpty else { return nil }
        return regionTypeByCountry[code]
    }

    package static func usesPostalCode(_ countryCode: String) -> Bool {
        let code = normalize(countryCode)
        guard !code.isEmpty else { return false }
        return !noPostalCountries.contains(code)
    }

    package static func usesRegion(_ countryCode: String) -> Bool {
        regionType(countryCode: countryCode) != nil
    }

    package static func format(countryCode: String) -> AddressFormat {
        let code = normalize(countryCode)
        if code.isEmpty {
            return AddressFormat(
                postalType: defaultPostalType,
                showRegion: false,
                showPostal: false,
                regionType: nil,
                postalPattern: defaultPattern,
                skipPostalFormat: false
            )
        }
        let override = postalOverrides[code]
        let region = regionTypeByCountry[code]
        return AddressFormat(
            postalType: override?.type ?? defaultPostalType,
            showRegion: region != nil,
            showPostal: !noPostalCountries.contains(code),
            regionType: region,
            postalPattern: override?.pattern ?? defaultPattern,
            skipPostalFormat: false
        )
    }

    package static func isPostalCodeValid(_ value: String, format: AddressFormat) -> Bool {
        guard format.showPostal else { return true }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        if format.skipPostalFormat { return true }
        let range = NSRange(normalized.startIndex..., in: normalized)
        guard let match = format.postalPattern.firstMatch(in: normalized, range: range) else { return false }
        return match.range == range
    }

    private static func normalize(_ countryCode: String) -> String {
        countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private struct PostalOverride {
        let type: String
        let pattern: NSRegularExpression
    }

    private static let postalOverrides: [String: PostalOverride] = [
        "US": PostalOverride(type: "zipCode", pattern: pattern("^\\d{5}(-\\d{4})?$")),
        "CA": PostalOverride(type: "postalCode", pattern: pattern("^[A-Za-z]\\d[A-Za-z][ -]?\\d[A-Za-z]\\d$")),
        "GB": PostalOverride(type: "postcode", pattern: pattern("^[A-Za-z]{1,2}\\d[A-Za-z\\d]?\\s*\\d[A-Za-z]{2}$", caseInsensitive: true)),
        "IE": PostalOverride(type: "eircode", pattern: pattern("^[A-Za-z0-9]{3}\\s?[A-Za-z0-9]{4}$", caseInsensitive: true)),
        "AU": PostalOverride(type: "postcode", pattern: pattern("^\\d{4}$")),
        "NZ": PostalOverride(type: "postcode", pattern: pattern("^\\d{4}$")),
        "IN": PostalOverride(type: "pin", pattern: pattern("^\\d{6}$")),
        "JP": PostalOverride(type: "postalCode", pattern: pattern("^\\d{3}-?\\d{4}$")),
        "CN": PostalOverride(type: "postalCode", pattern: pattern("^\\d{6}$")),
        "MX": PostalOverride(type: "postalCode", pattern: pattern("^\\d{5}$")),
        "BR": PostalOverride(type: "postalCode", pattern: pattern("^\\d{5}-?\\d{3}$")),
        "RO": PostalOverride(type: "postalCode", pattern: pattern("^\\d{6}$")),
        "BG": PostalOverride(type: "postalCode", pattern: pattern("^\\d{4}$")),
        "GR": PostalOverride(type: "postalCode", pattern: pattern("^\\d{3}\\s?\\d{2}$")),
        "HU": PostalOverride(type: "postalCode", pattern: pattern("^\\d{4}$")),
        "PL": PostalOverride(type: "postalCode", pattern: pattern("^\\d{2}-?\\d{3}$")),
        "DE": PostalOverride(type: "postalCode", pattern: pattern("^\\d{5}$")),
        "FR": PostalOverride(type: "postalCode", pattern: pattern("^\\d{5}$")),
        "IT": PostalOverride(type: "postalCode", pattern: pattern("^\\d{5}$")),
        "ES": PostalOverride(type: "postalCode", pattern: pattern("^\\d{5}$")),
        "NL": PostalOverride(type: "postalCode", pattern: pattern("^\\d{4}\\s?[A-Za-z]{2}$", caseInsensitive: true)),
        "BE": PostalOverride(type: "postalCode", pattern: pattern("^\\d{4}$")),
        "AT": PostalOverride(type: "postalCode", pattern: pattern("^\\d{4}$")),
        "CH": PostalOverride(type: "postalCode", pattern: pattern("^\\d{4}$")),
        "PT": PostalOverride(type: "postalCode", pattern: pattern("^\\d{4}-?\\d{3}$")),
        "SE": PostalOverride(type: "postalCode", pattern: pattern("^\\d{3}\\s?\\d{2}$")),
        "NO": PostalOverride(type: "postalCode", pattern: pattern("^\\d{4}$")),
        "DK": PostalOverride(type: "postalCode", pattern: pattern("^\\d{4}$")),
        "FI": PostalOverride(type: "postalCode", pattern: pattern("^\\d{5}$")),
        "CZ": PostalOverride(type: "postalCode", pattern: pattern("^\\d{3}\\s?\\d{2}$")),
        "SK": PostalOverride(type: "postalCode", pattern: pattern("^\\d{3}\\s?\\d{2}$")),
        "HR": PostalOverride(type: "postalCode", pattern: pattern("^\\d{5}$")),
        "SI": PostalOverride(type: "postalCode", pattern: pattern("^\\d{4}$")),
        "RS": PostalOverride(type: "postalCode", pattern: pattern("^\\d{5,6}$")),
        "UA": PostalOverride(type: "postalCode", pattern: pattern("^\\d{5}$")),
        "TR": PostalOverride(type: "postalCode", pattern: pattern("^\\d{5}$")),
        "SA": PostalOverride(type: "postalCode", pattern: pattern("^\\d{5}(-\\d{4})?$")),
        "ZA": PostalOverride(type: "postalCode", pattern: pattern("^\\d{4}$")),
        "SG": PostalOverride(type: "postalCode", pattern: pattern("^\\d{6}$")),
    ]

    private static func pattern(_ source: String, caseInsensitive: Bool = false) -> NSRegularExpression {
        var options: NSRegularExpression.Options = []
        if caseInsensitive { options.insert(.caseInsensitive) }
        return try! NSRegularExpression(pattern: source, options: options)
    }
}
