import Foundation

/// Collected shopper details before they are mapped onto the payment request.
package struct CustomerDetails: Equatable, Sendable {
    package var fullName: String?
    package var email: String?
    package var phone: String?
    package var country: String?
    package var region: String?
    package var city: String?
    package var postalCode: String?
    package var address: String?

    package init(
        fullName: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        country: String? = nil,
        region: String? = nil,
        city: String? = nil,
        postalCode: String? = nil,
        address: String? = nil
    ) {
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.country = country
        self.region = region
        self.city = city
        self.postalCode = postalCode
        self.address = address
    }

    /// Drops sections the backend did not ask for. Nil when nothing remains.
    package func pruned(to visibility: CustomerDetailsVisibility) -> CustomerDetails? {
        guard visibility.isActive else { return nil }
        var pruned = CustomerDetails()
        if visibility.showFullName { pruned.fullName = fullName }
        if visibility.showEmail { pruned.email = email }
        if visibility.showPhone { pruned.phone = phone }
        if visibility.showAddressSection {
            pruned.country = country
            pruned.region = region
            pruned.city = city
            pruned.postalCode = postalCode
            pruned.address = address
        }
        return pruned.nonEmpty()
    }

    /// JSON object sent as the `customerDetails` multipart field. Nil when empty.
    package func apiJSON() -> String? {
        guard let payload = apiPayload() else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    package func apiPayload() -> [String: String]? {
        var api: [String: String] = [:]
        let name = CustomerDetails.splitFullName(fullName)
        if !name.firstName.isEmpty {
            api["firstName"] = name.firstName
            api["lastName"] = name.lastName
        }
        if let country = CustomerDetails.trimmed(country) { api["country"] = country }
        if let city = CustomerDetails.trimmed(city) { api["city"] = city }
        if let postalCode = CustomerDetails.trimmed(postalCode) { api["zipCode"] = postalCode }

        let street = CustomerDetails.trimmed(address) ?? ""
        let regionName = CustomerDetails.trimmed(region) ?? ""
        var line = street
        if !regionName.isEmpty {
            line = street.isEmpty ? regionName : "\(street), \(regionName)"
        }
        if !line.isEmpty { api["address"] = line }

        if let phone = CustomerDetails.trimmed(phone) { api["phone"] = phone }
        if let email = CustomerDetails.trimmed(email) { api["email"] = email }
        return api.isEmpty ? nil : api
    }

    /// Splits on the first space, matching `splitFullName` in the checkout SDK.
    /// A one-word name is valid: `lastName` is sent as `""` and must not be required.
    package static func splitFullName(_ name: String?) -> (firstName: String, lastName: String) {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", "") }
        guard let space = trimmed.firstIndex(of: " ") else { return (trimmed, "") }
        let last = trimmed[trimmed.index(after: space)...].trimmingCharacters(in: .whitespacesAndNewlines)
        return (String(trimmed[..<space]), last)
    }

    /// Billing wins for name and address. Shipping wins for email and phone.
    /// Given and family names are joined, then split again on the first space.
    /// The phone is the wallet string, not `+{dial}{national}`.
    /// A known region becomes its canonical name. Anything else is kept raw.
    package static func mergingWallet(billing: WalletContactParts?, shipping: WalletContactParts?) -> CustomerDetails? {
        guard billing != nil || shipping != nil else { return nil }
        let firstName = nonBlank(billing?.firstName) ?? nonBlank(shipping?.firstName) ?? ""
        let lastName = nonBlank(billing?.lastName) ?? nonBlank(shipping?.lastName) ?? ""
        let email = nonBlank(shipping?.email) ?? nonBlank(billing?.email) ?? ""
        let phone = nonBlank(shipping?.phone) ?? nonBlank(billing?.phone) ?? ""
        let line1 = nonBlank(billing?.line1) ?? nonBlank(shipping?.line1) ?? ""
        let line2 = nonBlank(billing?.line2) ?? nonBlank(shipping?.line2) ?? ""
        let city = nonBlank(billing?.city) ?? nonBlank(shipping?.city) ?? ""
        let state = nonBlank(billing?.state) ?? nonBlank(shipping?.state) ?? ""
        let postalCode = nonBlank(billing?.postalCode) ?? nonBlank(shipping?.postalCode) ?? ""
        let countryCode = nonBlank(billing?.countryCode) ?? nonBlank(shipping?.countryCode) ?? ""

        let hasData = !firstName.isEmpty || !lastName.isEmpty || !email.isEmpty || !phone.isEmpty
            || !line1.isEmpty || !line2.isEmpty || !city.isEmpty || !state.isEmpty
            || !postalCode.isEmpty || !countryCode.isEmpty
        guard hasData else { return nil }

        let street = [line1, line2].filter { !$0.isEmpty }.joined(separator: ", ")
        return CustomerDetails(
            fullName: [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " "),
            email: email,
            phone: phone,
            country: countryCode,
            region: Subdivisions.regionName(countryCode: countryCode, administrativeArea: state)
                ?? CustomerDetails.trimmed(state),
            city: city,
            postalCode: postalCode,
            address: street
        ).nonEmpty()
    }

    private func nonEmpty() -> CustomerDetails? {
        var copy = self
        copy.fullName = CustomerDetails.trimmed(copy.fullName)
        copy.email = CustomerDetails.trimmed(copy.email)
        copy.phone = CustomerDetails.trimmed(copy.phone)
        copy.country = CustomerDetails.trimmed(copy.country)
        copy.region = CustomerDetails.trimmed(copy.region)
        copy.city = CustomerDetails.trimmed(copy.city)
        copy.postalCode = CustomerDetails.trimmed(copy.postalCode)
        copy.address = CustomerDetails.trimmed(copy.address)
        let hasValue = copy.fullName != nil || copy.email != nil || copy.phone != nil || copy.country != nil
            || copy.region != nil || copy.city != nil || copy.postalCode != nil || copy.address != nil
        return hasValue ? copy : nil
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func nonBlank(_ value: String?) -> String? {
        trimmed(value)
    }
}

package struct WalletContactParts: Equatable, Sendable {
    package var firstName: String
    package var lastName: String
    package var email: String
    package var phone: String
    package var line1: String
    package var line2: String
    package var city: String
    package var state: String
    package var postalCode: String
    package var countryCode: String

    package init(
        firstName: String = "",
        lastName: String = "",
        email: String = "",
        phone: String = "",
        line1: String = "",
        line2: String = "",
        city: String = "",
        state: String = "",
        postalCode: String = "",
        countryCode: String = ""
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.line1 = line1
        self.line2 = line2
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.countryCode = countryCode
    }
}

/// In-progress personal-details form. Survives sheet rebuilds.
package final class PersonalDetailsProgress {
    package var committed: PersonalDetailsValues?
    /// Latest edits, including ones that have not passed Continue.
    package var draft: PersonalDetailsValues?
    package var showsIncompleteError = false

    package init() {}

    package var isComplete: Bool { committed != nil }

    /// Values to show when the details page opens again.
    package var seed: PersonalDetailsValues {
        draft ?? committed ?? PersonalDetailsValues()
    }

    package func commit(_ values: PersonalDetailsValues) {
        committed = values
        draft = values
        showsIncompleteError = false
    }

    /// Drops a previous Continue when those values no longer satisfy `visibility`. The draft stays.
    package func revalidate(visibility: CustomerDetailsVisibility) {
        guard let committed else { return }
        if !CustomerDetailsValidator.validate(committed, visibility: visibility).isEmpty {
            self.committed = nil
        }
    }

    /// Keeps the edits. A previous Continue stays in effect only while the edits are still valid.
    package func leave(with values: PersonalDetailsValues, visibility: CustomerDetailsVisibility) {
        draft = values
        guard committed != nil else { return }
        if CustomerDetailsValidator.validate(values, visibility: visibility).isEmpty {
            committed = values
        } else {
            committed = nil
        }
    }
}

package struct PersonalDetailsValues: Equatable, Sendable {
    package var fullName: String
    package var email: String
    package var phoneCountry: String
    package var phoneNational: String
    package var country: String
    package var region: String
    package var address: String
    package var city: String
    package var postalCode: String

    package init(
        fullName: String = "",
        email: String = "",
        phoneCountry: String = "",
        phoneNational: String = "",
        country: String = "",
        region: String = "",
        address: String = "",
        city: String = "",
        postalCode: String = ""
    ) {
        self.fullName = fullName
        self.email = email
        self.phoneCountry = phoneCountry
        self.phoneNational = phoneNational
        self.country = country
        self.region = region
        self.address = address
        self.city = city
        self.postalCode = postalCode
    }

    package func makeCustomerDetails(visibility: CustomerDetailsVisibility) -> CustomerDetails? {
        guard visibility.isActive else { return nil }
        var draft = CustomerDetails()
        if visibility.showFullName { draft.fullName = fullName }
        if visibility.showEmail { draft.email = email }
        if visibility.showPhone {
            draft.phone = PhoneNumber.payload(
                dialCode: Countries.byCode(phoneCountry)?.dialCode,
                nationalInput: phoneNational
            )
        }
        if visibility.showAddressSection {
            let format = AddressFormats.format(countryCode: country)
            draft.country = country
            if format.showRegion {
                draft.region = Subdivisions.regionName(countryCode: country, administrativeArea: region)
            }
            draft.city = city
            if format.showPostal { draft.postalCode = postalCode }
            draft.address = address
        }
        return draft.pruned(to: visibility)
    }
}
