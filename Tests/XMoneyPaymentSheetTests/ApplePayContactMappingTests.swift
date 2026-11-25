import Contacts
import PassKit
import XCTest
@testable import XMoneyApplePay
import XMoneyCore

final class ApplePayContactMappingTests: XCTestCase {
    func testBillingContactMapsOntoCustomerDetails() {
        let contact = PKContact()
        var name = PersonNameComponents()
        name.givenName = "Ada"
        name.familyName = "Lovelace"
        contact.name = name

        let postal = CNMutablePostalAddress()
        postal.street = "1 Market St\nSuite 2"
        postal.city = "San Francisco"
        postal.state = "CA"
        postal.postalCode = "94105"
        postal.isoCountryCode = "US"
        contact.postalAddress = postal
        contact.emailAddress = "ada@example.com"
        contact.phoneNumber = CNPhoneNumber(stringValue: "+14155551212")

        let parts = WalletContactParts(contact)
        XCTAssertEqual(parts.firstName, "Ada")
        XCTAssertEqual(parts.lastName, "Lovelace")
        XCTAssertEqual(parts.line1, "1 Market St")
        XCTAssertEqual(parts.line2, "Suite 2")
        XCTAssertEqual(parts.city, "San Francisco")
        XCTAssertEqual(parts.state, "CA")
        XCTAssertEqual(parts.postalCode, "94105")
        XCTAssertEqual(parts.countryCode, "US")
        XCTAssertEqual(parts.email, "ada@example.com")
        XCTAssertEqual(parts.phone, "+14155551212")

        let details = CustomerDetails.mergingWallet(billing: parts, shipping: nil)
        XCTAssertEqual(details?.fullName, "Ada Lovelace")
        XCTAssertEqual(details?.city, "San Francisco")
        XCTAssertEqual(details?.postalCode, "94105")
        XCTAssertEqual(details?.country, "US")
        XCTAssertEqual(details?.region, "California")
        XCTAssertEqual(details?.address, "1 Market St, Suite 2")
        XCTAssertEqual(details?.email, "ada@example.com")
    }

    func testRequiredContactFieldsFollowVisibility() {
        let visibility = CustomerDetailsVisibility.resolve(fields: ["firstName", "email", "phone", "address"])
        let fields = ApplePayHandler.contactFields(collects: true, visibility: visibility)
        XCTAssertEqual(fields.billing, [.name, .postalAddress])
        XCTAssertEqual(fields.shipping, [.emailAddress, .phoneNumber])

        let emailOnly = CustomerDetailsVisibility.resolve(fields: ["email"])
        let emailFields = ApplePayHandler.contactFields(collects: true, visibility: emailOnly)
        XCTAssertEqual(emailFields.billing, [])
        XCTAssertEqual(emailFields.shipping, [.emailAddress])

        let off = ApplePayHandler.contactFields(collects: false, visibility: visibility)
        XCTAssertTrue(off.billing.isEmpty)
        XCTAssertTrue(off.shipping.isEmpty)
    }
}
