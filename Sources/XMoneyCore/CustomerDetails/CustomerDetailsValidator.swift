import Foundation

package enum PersonalDetailsField: String, CaseIterable, Sendable {
    case fullName
    case phoneCountry
    case phone
    case email
    case country
    case region
    case address
    case city
    case postalCode
}

package struct PersonalDetailsFieldError: Equatable, Sendable {
    package let code: String

    package func localizedMessage(locale: String) -> String {
        Strings.text("personalDetails.errors.\(code)", locale: locale)
    }
}

package enum CustomerDetailsValidator {
    package static let contactOrder: [PersonalDetailsField] = [.fullName, .phoneCountry, .phone, .email]

    package static func addressOrder(countryCode: String) -> [PersonalDetailsField] {
        let format = AddressFormats.format(countryCode: countryCode)
        var order: [PersonalDetailsField] = [.country]
        if format.showRegion { order.append(.region) }
        order.append(.address)
        order.append(.city)
        if format.showPostal { order.append(.postalCode) }
        return order
    }

    package static func activeFields(
        visibility: CustomerDetailsVisibility,
        countryCode: String
    ) -> [PersonalDetailsField] {
        var names: [PersonalDetailsField] = []
        if visibility.showFullName { names.append(.fullName) }
        if visibility.showPhone {
            names.append(.phoneCountry)
            names.append(.phone)
        }
        if visibility.showEmail { names.append(.email) }
        if visibility.showAddressSection {
            names.append(contentsOf: addressOrder(countryCode: countryCode))
        }
        return names
    }

    package static func validate(
        _ values: PersonalDetailsValues,
        visibility: CustomerDetailsVisibility
    ) -> [PersonalDetailsField: PersonalDetailsFieldError] {
        var errors: [PersonalDetailsField: PersonalDetailsFieldError] = [:]
        for field in activeFields(visibility: visibility, countryCode: values.country) {
            if let error = validateField(field, values: values, visibility: visibility) {
                errors[field] = error
            }
        }
        return errors
    }

    package static func validateField(
        _ field: PersonalDetailsField,
        values: PersonalDetailsValues,
        visibility: CustomerDetailsVisibility
    ) -> PersonalDetailsFieldError? {
        switch field {
        case .fullName:
            guard visibility.showFullName else { return nil }
            return values.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? PersonalDetailsFieldError(code: "fullNameRequired") : nil
        case .email:
            guard visibility.showEmail else { return nil }
            let email = values.email.trimmingCharacters(in: .whitespacesAndNewlines)
            if email.isEmpty { return PersonalDetailsFieldError(code: "emailRequired") }
            if email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) == nil {
                return PersonalDetailsFieldError(code: "emailInvalid")
            }
            return nil
        case .phoneCountry:
            guard visibility.showPhone else { return nil }
            return values.phoneCountry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? PersonalDetailsFieldError(code: "phoneCountryRequired") : nil
        case .phone:
            guard visibility.showPhone else { return nil }
            let national = values.phoneNational.trimmingCharacters(in: .whitespacesAndNewlines)
            if national.isEmpty { return PersonalDetailsFieldError(code: "phoneRequired") }
            if !PhoneNumber.isNationalValid(national) { return PersonalDetailsFieldError(code: "phoneInvalid") }
            return nil
        case .country, .region, .address, .city, .postalCode:
            guard visibility.showAddressSection else { return nil }
            return validateAddress(field, values: values)
        }
    }

    private static func validateAddress(
        _ field: PersonalDetailsField,
        values: PersonalDetailsValues
    ) -> PersonalDetailsFieldError? {
        let format = AddressFormats.format(countryCode: values.country)
        switch field {
        case .region:
            guard format.showRegion else { return nil }
            if !Subdivisions.isSelectionComplete(countryCode: values.country, regionValue: values.region) {
                return PersonalDetailsFieldError(code: format.regionRequiredError)
            }
            return nil
        case .postalCode:
            guard format.showPostal else { return nil }
            let value = values.postalCode.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty { return PersonalDetailsFieldError(code: format.postalRequiredError) }
            if !AddressFormats.isPostalCodeValid(value, format: format) {
                return PersonalDetailsFieldError(code: format.postalInvalidError)
            }
            return nil
        case .country:
            return blank(values.country) ? PersonalDetailsFieldError(code: "countryRequired") : nil
        case .address:
            return blank(values.address) ? PersonalDetailsFieldError(code: "addressRequired") : nil
        case .city:
            return blank(values.city) ? PersonalDetailsFieldError(code: "cityRequired") : nil
        default:
            return nil
        }
    }

    private static func blank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
