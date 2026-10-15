import XCTest
@testable import XMoneyCore

final class CustomerDetailsTests: XCTestCase {
    func testVisibilityTreatsAnyAddressFieldAsTheWholeBlock() {
        let nameOnly = CustomerDetailsVisibility.resolve(fields: ["firstName"])
        XCTAssertTrue(nameOnly.showFullName)
        XCTAssertFalse(nameOnly.showAddressSection)
        XCTAssertTrue(nameOnly.isActive)

        let lastName = CustomerDetailsVisibility.resolve(fields: ["lastName"])
        XCTAssertTrue(lastName.showFullName)

        let zip = CustomerDetailsVisibility.resolve(fields: ["zipCode"])
        XCTAssertTrue(zip.showAddressSection)
        XCTAssertTrue(zip.showFullName == false)
        XCTAssertTrue(zip.isActive)

        XCTAssertFalse(CustomerDetailsVisibility.resolve(fields: []).isActive)
        XCTAssertFalse(CustomerDetailsVisibility.resolve(fields: ["cardId", "saveCard"]).isActive)
    }

    func testEmptyCountryHidesRegionAndPostal() {
        let format = AddressFormats.format(countryCode: "")
        XCTAssertFalse(format.showRegion)
        XCTAssertFalse(format.showPostal)
        XCTAssertNil(format.regionType)
    }

    func testAddressFormatFollowsCountryRules() {
        XCTAssertEqual(AddressFormats.regionType(countryCode: "US"), "state")
        XCTAssertEqual(AddressFormats.regionType(countryCode: "CA"), "province")
        XCTAssertEqual(AddressFormats.format(countryCode: "us").regionLabelKey, "personalDetails.region.state")
        XCTAssertEqual(AddressFormats.format(countryCode: "US").regionRequiredError, "stateRequired")
        XCTAssertEqual(AddressFormats.format(countryCode: "CA").regionSelectKey, "personalDetails.region.provinceSelect")
        XCTAssertFalse(AddressFormats.format(countryCode: "RO").showRegion)
        XCTAssertFalse(AddressFormats.format(countryCode: "AE").showPostal)
        XCTAssertEqual(AddressFormats.format(countryCode: "AE").regionType, "emirate")
        XCTAssertEqual(AddressFormats.format(countryCode: "US").postalType, "zipCode")
        XCTAssertEqual(AddressFormats.format(countryCode: "IE").postalInvalidError, "eircodeInvalid")

        for country in Countries.all {
            let format = AddressFormats.format(countryCode: country.code)
            XCTAssertEqual(format.showPostal, AddressFormats.usesPostalCode(country.code), country.code)
            XCTAssertEqual(format.showRegion, AddressFormats.usesRegion(country.code), country.code)
            XCTAssertEqual(format.regionType, AddressFormats.regionType(countryCode: country.code), country.code)
        }
    }

    func testPostalPatternsAcceptOfficialFormatsAndRejectLookalikes() {
        let cases: [(String, [String], [String])] = [
            ("US", ["10001", "10001-1234"], ["10001 1234", "P.O. Box 12"]),
            ("CA", ["K1A 0B1", "K1A0B1"], ["12345"]),
            ("GB", ["SW1A 1AA", "M1 1AE"], ["GIR 0AA", "BFPO 801"]),
            ("IE", ["D02 AF30", "D02AF30"], ["D02-AF30"]),
            ("AU", ["2000"], ["20000"]),
            ("IN", ["110001"], ["110 001"]),
            ("JP", ["100-0001", "1000001"], ["100 0001"]),
            ("BR", ["01310-100", "01310100"], ["01310 100"]),
            ("RO", ["010011"], ["01001"]),
            ("PL", ["00-001", "00001"], ["00 001"]),
            ("NL", ["1012 JS", "1012js"], ["1012-JS"]),
            ("PT", ["1000-001", "1000001"], ["1000 001"]),
            ("GR", ["104 31", "10431"], ["105-52"]),
            ("SG", ["018956"], ["018 956"]),
        ]
        for (code, valid, invalid) in cases {
            let format = AddressFormats.format(countryCode: code)
            for value in valid {
                XCTAssertTrue(AddressFormats.isPostalCodeValid(value, format: format), "\(code) \(value)")
            }
            for value in invalid {
                XCTAssertFalse(AddressFormats.isPostalCodeValid(value, format: format), "\(code) \(value)")
            }
        }
        let generic = AddressFormats.format(countryCode: "AF")
        XCTAssertTrue(AddressFormats.isPostalCodeValid("1001", format: generic))
        XCTAssertTrue(AddressFormats.isPostalCodeValid("PO Box 12", format: generic))
        XCTAssertFalse(AddressFormats.isPostalCodeValid("P.O. Box 12", format: generic))
        XCTAssertTrue(AddressFormats.isPostalCodeValid("P.O. Box 123", format: AddressFormats.format(countryCode: "AE")))
    }

    func testPhoneValidationAndPayload() {
        XCTAssertTrue(PhoneNumber.isNationalValid("0722 123 456"))
        XCTAssertTrue(PhoneNumber.isNationalValid("(072) 212-3456"))
        XCTAssertFalse(PhoneNumber.isNationalValid("12345"))
        XCTAssertFalse(PhoneNumber.isNationalValid("12a3456"))
        XCTAssertEqual(PhoneNumber.formatNationalForPayload("0722123456"), "722123456")
        XCTAssertEqual(PhoneNumber.payload(dialCode: "40", nationalInput: "0722 123 456"), "+40722123456")
        XCTAssertEqual(PhoneNumber.payload(dialCode: nil, nationalInput: "722123456"), "")
    }

    func testApiPayloadAppendsRegionAndSplitsName() {
        let details = CustomerDetails(
            fullName: "Jane Doe",
            country: "US",
            region: "California",
            city: "San Francisco",
            postalCode: "94105",
            address: "1 Market St"
        )
        let api = details.apiPayload()
        XCTAssertEqual(api?["firstName"], "Jane")
        XCTAssertEqual(api?["lastName"], "Doe")
        XCTAssertEqual(api?["address"], "1 Market St, California")
        XCTAssertNil(api?["state"])
        XCTAssertNil(api?["region"])
        XCTAssertEqual(api?["zipCode"], "94105")

        // A one-word name is valid. lastName stays "" and is not required.
        let single = CustomerDetails(fullName: "Madonna").apiPayload()
        XCTAssertEqual(single?["firstName"], "Madonna")
        XCTAssertEqual(single?["lastName"], "")

        let streetOnly = CustomerDetails(country: "US", address: "1 Market St").apiPayload()
        XCTAssertEqual(streetOnly?["address"], "1 Market St")
        XCTAssertNil(streetOnly?["state"])
    }

    func testSubdivisionAliasesAndWalletMerge() {
        XCTAssertFalse(Subdivisions.list(countryCode: "US").isEmpty)
        XCTAssertEqual(Subdivisions.regionName(countryCode: "US", administrativeArea: "CA"), "California")
        XCTAssertEqual(Subdivisions.regionName(countryCode: "US", administrativeArea: "California"), "California")
        XCTAssertEqual(Subdivisions.regionName(countryCode: "AU", administrativeArea: "NSW"), "New South Wales")
        XCTAssertEqual(Subdivisions.regionName(countryCode: "MX", administrativeArea: "AGS."), "Aguascalientes")

        let contact = WalletContactParts(
            firstName: "Jane",
            lastName: "Doe",
            line1: "1 Market St",
            city: "San Francisco",
            state: "CA",
            postalCode: "94105",
            countryCode: "US"
        )
        let merged = CustomerDetails.mergingWallet(billing: contact, shipping: nil)
        XCTAssertEqual(merged?.region, "California")
        XCTAssertEqual(merged?.apiPayload()?["address"], "1 Market St, California")

        let unknown = WalletContactParts(
            line1: "1600 Pennsylvania Ave",
            city: "Washington",
            state: "D.C.",
            countryCode: "US"
        )
        let kept = CustomerDetails.mergingWallet(billing: unknown, shipping: nil)
        XCTAssertEqual(kept?.region, "D.C.")
        XCTAssertEqual(kept?.apiPayload()?["address"], "1600 Pennsylvania Ave, D.C.")

        let visibility = CustomerDetailsVisibility.resolve(fields: ["email"])
        let pruned = merged?.pruned(to: visibility)
        XCTAssertNil(pruned?.address)
        XCTAssertNil(pruned?.region)
    }

    func testFormValuesBuildPhoneAndOmitHiddenPostal() {
        let visibility = CustomerDetailsVisibility.resolve(fields: ["phone", "country", "address"])
        var values = PersonalDetailsValues(
            phoneCountry: "RO",
            phoneNational: "0722123456",
            country: "AE",
            address: "1 Sheikh Zayed Rd",
            city: "Dubai",
            postalCode: "00000"
        )
        let details = values.makeCustomerDetails(visibility: visibility)
        XCTAssertEqual(details?.phone, "+40722123456")
        XCTAssertEqual(details?.country, "AE")
        XCTAssertNil(details?.postalCode)
        XCTAssertNil(details?.region)
        XCTAssertNil(details?.email)

        values.country = "US"
        values.region = "CA"
        values.city = "San Francisco"
        values.postalCode = "94105"
        values.address = "1 Market St"
        let us = values.makeCustomerDetails(visibility: visibility)
        XCTAssertEqual(us?.region, "California")
        XCTAssertEqual(us?.postalCode, "94105")
    }

    func testValidationMessagesUseSdkErrorCodes() {
        let visibility = CustomerDetailsVisibility.resolve(fields: ["email", "phone", "firstName", "zipCode"])
        let errors = CustomerDetailsValidator.validate(PersonalDetailsValues(email: "not-an-email"), visibility: visibility)
        XCTAssertEqual(errors[.email]?.code, "emailInvalid")
        XCTAssertEqual(errors[.fullName]?.code, "fullNameRequired")
        XCTAssertEqual(errors[.phoneCountry]?.code, "phoneCountryRequired")
        XCTAssertEqual(errors[.country]?.code, "countryRequired")
        XCTAssertEqual(
            errors[.email]?.localizedMessage(locale: "en"),
            "Please enter a valid email address."
        )
        XCTAssertEqual(Strings.text("personalDetails.enterDetails", locale: "en"), "Enter your personal details")
        XCTAssertEqual(Strings.text("personalDetails.completeDetails", locale: "ro"), "Completați datele")
        XCTAssertEqual(Strings.text("personalDetails.continue", locale: "hu"), "Tovább")
        XCTAssertEqual(Strings.text("personalDetails.back", locale: "pl"), "Wstecz")
    }

    func testLeaveKeepsValidEditsAsTheCommittedDetails() {
        let visibility = CustomerDetailsVisibility.resolve(fields: ["email"])
        let progress = PersonalDetailsProgress()
        progress.commit(PersonalDetailsValues(email: "a@b.co"))
        let edited = PersonalDetailsValues(email: "c@d.co")
        progress.leave(with: edited, visibility: visibility)
        XCTAssertEqual(progress.committed, edited)
        XCTAssertEqual(progress.seed, edited)
    }

    func testLeaveClearsCommittedWhenEditsAreInvalid() {
        let visibility = CustomerDetailsVisibility.resolve(fields: ["email"])
        let progress = PersonalDetailsProgress()
        progress.commit(PersonalDetailsValues(email: "a@b.co"))
        let edited = PersonalDetailsValues(email: "nope")
        progress.leave(with: edited, visibility: visibility)
        XCTAssertNil(progress.committed)
        XCTAssertEqual(progress.seed, edited)
        XCTAssertFalse(progress.isComplete)
    }

    func testLeaveDoesNotCommitWhenContinueWasNeverPressed() {
        let visibility = CustomerDetailsVisibility.resolve(fields: ["email"])
        let progress = PersonalDetailsProgress()
        let edited = PersonalDetailsValues(email: "a@b.co")
        progress.leave(with: edited, visibility: visibility)
        XCTAssertNil(progress.committed)
        XCTAssertEqual(progress.seed, edited)
    }

    func testRevalidateKeepsDetailsThatStillSatisfyTheNewFields() {
        let progress = PersonalDetailsProgress()
        let values = PersonalDetailsValues(email: "a@b.co")
        progress.commit(values)
        progress.revalidate(visibility: CustomerDetailsVisibility.resolve(fields: ["email"]))
        XCTAssertEqual(progress.committed, values)
        XCTAssertEqual(progress.draft, values)
    }

    func testRevalidateClearsCommittedDetailsWhenANewFieldIsMissing() {
        let progress = PersonalDetailsProgress()
        let values = PersonalDetailsValues(email: "a@b.co")
        progress.commit(values)
        progress.revalidate(visibility: CustomerDetailsVisibility.resolve(fields: ["email", "phone"]))
        XCTAssertNil(progress.committed)
        XCTAssertEqual(progress.draft, values)
        XCTAssertFalse(progress.isComplete)
    }

    func testSheetStateKeepsTheSamePersonalDetailsProgress() {
        let progress = PersonalDetailsProgress()
        progress.commit(PersonalDetailsValues(email: "a@b.co"))
        let state = SheetState(
            sessionToken: "tok",
            orderInfo: OrderPayloadInfo(
                cardTransactionMode: nil,
                isVerifyCard: false,
                amount: 10,
                currency: "EUR",
                externalOrderId: "order-1",
                isRecurring: false
            ),
            savedCards: [],
            applePayAvailable: false,
            personalDetails: progress
        )
        let updated = state.withSavedCards([])
        XCTAssertTrue(updated.personalDetails === progress)
        XCTAssertEqual(updated.personalDetails.committed?.email, "a@b.co")
    }

    func testInvalidLeaveLeavesTheRebuiltRowIncomplete() {
        let visibility = CustomerDetailsVisibility.resolve(fields: ["email"])
        let progress = PersonalDetailsProgress()
        progress.commit(PersonalDetailsValues(email: "a@b.co"))
        let state = SheetState(
            sessionToken: "tok",
            orderInfo: OrderPayloadInfo(
                cardTransactionMode: nil,
                isVerifyCard: false,
                amount: 10,
                currency: "EUR",
                externalOrderId: "order-1",
                isRecurring: false
            ),
            savedCards: [],
            applePayAvailable: false,
            customerDetailsVisibility: visibility,
            personalDetails: progress
        )
        state.personalDetails.leave(
            with: PersonalDetailsValues(email: "nope"),
            visibility: state.customerDetailsVisibility
        )
        XCTAssertFalse(state.personalDetails.isComplete)
        XCTAssertEqual(state.personalDetails.seed.email, "nope")
    }

    func testPaymentFieldsIncludeCustomerDetailsJSON() throws {
        let env = try XCTUnwrap(PaymentEnvironment(publicKey: "pk_test_x"))
        let service = PaymentService(http: HTTPClient(), env: env)
        let details = CustomerDetails(fullName: "Ada Lovelace", email: "ada@example.com")
        let fields = service.cardFields(
            card: CardInput(number: "4242424242424242"),
            orderPayload: "{}",
            orderChecksum: "sum",
            customerDetails: details
        )
        let raw = try XCTUnwrap(fields["customerDetails"])
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: String])
        XCTAssertEqual(parsed["firstName"], "Ada")
        XCTAssertEqual(parsed["lastName"], "Lovelace")
        XCTAssertEqual(parsed["email"], "ada@example.com")
        XCTAssertNil(service.savedCardFields(cardId: "1", orderPayload: "{}", orderChecksum: "sum")["customerDetails"])
    }
}
