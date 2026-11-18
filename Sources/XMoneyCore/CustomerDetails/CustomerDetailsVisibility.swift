import Foundation

/// Which personal-details sections the card form collects.
/// `firstName` or `lastName` shows the name. `email` and `phone` show those fields.
/// `country`, `state`, `city`, `zipCode`, or `address` shows the address section.
package struct CustomerDetailsVisibility: Equatable, Sendable {
    package let showFullName: Bool
    package let showEmail: Bool
    package let showPhone: Bool
    package let showAddressSection: Bool

    package var isActive: Bool {
        showFullName || showEmail || showPhone || showAddressSection
    }

    package var showsContactSection: Bool {
        showFullName || showEmail || showPhone
    }

    package static let inactive = CustomerDetailsVisibility(
        showFullName: false,
        showEmail: false,
        showPhone: false,
        showAddressSection: false
    )

    package static func resolve(fields: [String]) -> CustomerDetailsVisibility {
        let set = Set(fields)
        let showFullName = set.contains("firstName") || set.contains("lastName")
        let showEmail = set.contains("email")
        let showPhone = set.contains("phone")
        let showAddressSection = ["country", "state", "city", "zipCode", "address"].contains { set.contains($0) }
        return CustomerDetailsVisibility(
            showFullName: showFullName,
            showEmail: showEmail,
            showPhone: showPhone,
            showAddressSection: showAddressSection
        )
    }
}
