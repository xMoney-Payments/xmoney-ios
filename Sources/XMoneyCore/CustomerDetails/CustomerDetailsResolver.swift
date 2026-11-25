import Foundation

/// Turns `customerDetails.fields` and `defaultValues` into the form the card UI already uses.
package enum CustomerDetailsResolver {
    private static let addressFields = ["country", "state", "city", "zipCode", "address"]
    private static let maxDialCodeLength = 6
    /// Used when several countries share a calling code and no country default narrows it.
    private static let preferredCountryByDialCode = ["1": "US", "7": "RU", "44": "GB"]

    package struct ParsedPhone: Equatable {
        package let country: String
        package let national: String
    }

    /// Field names `CustomerDetailsVisibility.resolve` already understands.
    /// Every flag left off is absent from the list.
    package static func inlineCheckoutFields(_ fields: PaymentConfig.CustomerDetailsConfig.Fields) -> [String] {
        var resolved: [String] = []
        if fields.fullName {
            resolved.append(contentsOf: ["firstName", "lastName"])
        }
        if fields.email {
            resolved.append("email")
        }
        if fields.phone {
            resolved.append("phone")
        }
        if fields.address {
            resolved.append(contentsOf: addressFields)
        }
        return resolved
    }

    /// Keeps only defaults that can be shown on the card form.
    /// Anything else is dropped. Values are not logged.
    package static func resolve(
        _ defaults: PaymentConfig.CustomerDetailsConfig.DefaultValues?,
        visibility: CustomerDetailsVisibility
    ) -> PersonalDetailsValues {
        guard let defaults, visibility.isActive else { return PersonalDetailsValues() }

        var resolved = PersonalDetailsValues()
        if visibility.showFullName {
            let fullName = text(defaults.fullName)
            if !fullName.isEmpty { resolved.fullName = fullName }
        }
        if visibility.showEmail {
            let email = text(defaults.email)
            if !email.isEmpty { resolved.email = email }
        }

        let country = visibility.showAddressSection ? countryCode(defaults.country) : ""
        if visibility.showPhone, let phone = parsePhone(defaults.phone, preferredCountryCode: country) {
            resolved.phoneCountry = phone.country
            resolved.phoneNational = phone.national
        }
        if visibility.showAddressSection {
            let city = text(defaults.city)
            let address = text(defaults.address)
            if !city.isEmpty { resolved.city = city }
            if !address.isEmpty { resolved.address = address }
            if !country.isEmpty {
                resolved.country = country
                let format = AddressFormats.format(countryCode: country)
                if format.showRegion, let region = Subdivisions.find(countryCode: country, value: defaults.region ?? "")?.name {
                    resolved.region = region
                }
                let postalCode = text(defaults.postalCode)
                if format.showPostal, !postalCode.isEmpty {
                    resolved.postalCode = postalCode
                }
            }
        }
        return resolved
    }

    /// Form values for ``CustomerDetailsValidator``.
    /// Invalid email, postal, and region values are kept so the validator can reject them.
    /// An unparseable phone is left blank, which fails when phone is required.
    package static func formValues(
        from details: CustomerDetails,
        visibility: CustomerDetailsVisibility
    ) -> PersonalDetailsValues {
        var values = PersonalDetailsValues()
        if visibility.showFullName {
            values.fullName = text(details.fullName)
        }
        if visibility.showEmail {
            values.email = text(details.email)
        }
        let country = text(details.country).uppercased()
        if visibility.showPhone, let phone = parsePhone(details.phone, preferredCountryCode: country) {
            values.phoneCountry = phone.country
            values.phoneNational = phone.national
        }
        if visibility.showAddressSection {
            values.country = country
            values.region = text(details.region)
            values.address = text(details.address)
            values.city = text(details.city)
            values.postalCode = text(details.postalCode)
        }
        return values
    }

    /// Splits an E.164 number (`+40722123456`) into a phone country and national digits.
    /// Returns nil when the value does not start with `+` or the dial code matches no country.
    package static func parsePhone(_ value: String?, preferredCountryCode: String = "") -> ParsedPhone? {
        let raw = text(value)
        guard raw.hasPrefix("+") else { return nil }
        let digits = String(raw.filter { $0 >= "0" && $0 <= "9" })
        guard digits.count >= 2 else { return nil }

        let maxLength = min(maxDialCodeLength, digits.count - 1)
        for length in stride(from: maxLength, through: 1, by: -1) {
            let dial = String(digits.prefix(length))
            let candidates = Countries.all.filter { $0.dialCode == dial }
            guard let match = candidates.first(where: { $0.code == preferredCountryCode })
                ?? candidates.first(where: { $0.code == preferredCountryByDialCode[dial] })
                ?? candidates.first else {
                continue
            }
            let national = String(digits.dropFirst(length))
            guard !national.isEmpty else { continue }
            return ParsedPhone(country: match.code, national: national)
        }
        return nil
    }

    private static func text(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func countryCode(_ value: String?) -> String {
        let code = text(value).uppercased()
        guard !code.isEmpty, Countries.byCode(code) != nil else { return "" }
        return code
    }
}
