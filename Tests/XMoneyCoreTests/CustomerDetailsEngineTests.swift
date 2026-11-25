import XCTest
@testable import XMoneyCore

@MainActor
final class CustomerDetailsEngineTests: XCTestCase {
    func testMissingDetailsAreRejected() async throws {
        let session = try makeSession(card: true, fields: .init(email: true))
        _ = try await session.bind(intent: intent)
        let missing = await session.submitNewCard(card, presenter: Presenter(), customerDetails: nil)
        XCTAssertEqual(rejection(missing), .invalidCustomerDetails)
    }

    func testBlankEmailIsRejected() async throws {
        let session = try makeSession(card: true, fields: .init(email: true))
        _ = try await session.bind(intent: intent)
        let blank = await session.submitNewCard(
            card,
            presenter: Presenter(),
            customerDetails: CustomerDetails(email: "  ")
        )
        XCTAssertEqual(rejection(blank), .invalidCustomerDetails)
    }

    func testMalformedEmailIsRejected() async throws {
        let session = try makeSession(card: true, fields: .init(email: true))
        _ = try await session.bind(intent: intent)
        let malformed = await session.submitNewCard(
            card,
            presenter: Presenter(),
            customerDetails: CustomerDetails(email: "not-an-email")
        )
        XCTAssertEqual(rejection(malformed), .invalidCustomerDetails)
    }

    func testValidEmailIsNotRejectedAsIncomplete() async throws {
        let session = try makeSession(card: true, fields: .init(email: true))
        _ = try await session.bind(intent: intent)
        let accepted = await session.submitNewCard(
            card,
            presenter: Presenter(),
            customerDetails: CustomerDetails(email: "ada@example.com")
        )
        XCTAssertNil(rejection(accepted))
    }

    func testInvalidUsPostalCodeIsRejected() async throws {
        let session = try makeSession(card: true, fields: .init(address: true))
        _ = try await session.bind(intent: intent)
        let details = CustomerDetails(
            country: "US",
            region: "California",
            city: "San Francisco",
            postalCode: "12",
            address: "1 Market"
        )
        let invalidPostal = await session.submitNewCard(card, presenter: Presenter(), customerDetails: details)
        XCTAssertEqual(rejection(invalidPostal), .invalidCustomerDetails)
    }

    func testRegionRequiredCountryWithoutRegionIsRejected() async throws {
        let session = try makeSession(card: true, fields: .init(address: true))
        _ = try await session.bind(intent: intent)
        var details = CustomerDetails()
        details.fullName = "Ada Lovelace"
        details.country = "US"
        details.address = "1 Market"
        details.city = "San Francisco"
        details.postalCode = "94105"
        let missingRegion = await session.submitNewCard(card, presenter: Presenter(), customerDetails: details)
        XCTAssertEqual(rejection(missingRegion), .invalidCustomerDetails)
    }

    func testDisabledCollectionIgnoresTheFieldsOverride() async throws {
        let session = try makeSession(card: false, fields: .init(email: true), fieldsStatus: 500)
        let state = try await session.bind(intent: intent)
        XCTAssertFalse(state.customerDetailsVisibility.isActive)
    }

    func testFieldsFailureBlocksCardCollectionAndIsIgnoredWhenCardIsOff() async throws {
        let blocked = try makeSession(card: true, fields: nil, fieldsStatus: 500)
        do {
            _ = try await blocked.bind(intent: intent)
            XCTFail("expected the fields failure to block load")
        } catch let error as PaymentError {
            guard case .load = error else {
                XCTFail("expected load error, got \(error)")
                return
            }
        }

        let open = try makeSession(card: false, fields: nil, fieldsStatus: 500)
        let state = try await open.bind(intent: intent)
        XCTAssertFalse(state.customerDetailsVisibility.isActive)
    }

    func testCryptoSubmitFieldSet() throws {
        let service = PaymentService(http: HTTPClient(), env: try XCTUnwrap(PaymentEnvironment(publicKey: "pk_test_stub")))
        var details = CustomerDetails()
        details.email = "ada@example.com"
        let fields = service.cryptoFields(orderPayload: "payload", orderChecksum: "checksum", customerDetails: details)
        XCTAssertEqual(fields["paymentMethod"], "crypto")
        XCTAssertNil(fields["cardNumber"])
        XCTAssertTrue(fields["customerDetails"]?.contains("ada@example.com") == true)
        XCTAssertEqual(PaymentKind.acceptHeader(fields: fields), "application/json")
    }

    private func rejection(_ result: EngineResult) -> PaymentError? {
        guard result.status == .failed, result.errorMessage == "Customer details are incomplete" else { return nil }
        return .invalidCustomerDetails
    }

    private func makeSession(
        card: Bool,
        fields: PaymentConfig.CustomerDetailsConfig.Fields?,
        fieldsStatus: Int = 200,
        handler: (@Sendable (URLRequest) -> (Int, Data))? = nil
    ) throws -> PaymentSession {
        let http = HTTPClient(execute: { @Sendable request in
            let (status, data) = handler?(request) ?? stub(request, fieldsStatus: fieldsStatus)
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://invalid.local")!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (data, response)
        })
        var config = PaymentConfig(publicKey: "pk_test_stub")
        config.customerDetails.card = card
        config.customerDetails.fields = fields
        return try PaymentSession(configuration: config, intent: intent, http: http)
    }

    private let intent = PaymentIntent(orderPayload: OrderPayload("e30="), orderChecksum: OrderChecksum("cs"))
    private let card = CardInput(number: "4242424242424242", expiryMonth: "12", expiryYear: "30", cvv: "123")
}

private final class Presenter: ThreeDSPresenter {
    func presentThreeDS(url: URL) async -> ThreeDSChallengeEnd { .userCanceled(bankHandoff: false) }
    func dismissThreeDS() {}
}

private func stub(_ request: URLRequest, fieldsStatus: Int) -> (Int, Data) {
    let path = request.url?.path ?? ""
    if path.contains("session-token") { return (200, json(["token": "sess-1"])) }
    if path.contains("inline-checkout/fields") {
        if fieldsStatus != 200 { return (fieldsStatus, json(["message": "no"])) }
        return (200, json(["data": ["email"]]))
    }
    if path.contains("transaction") {
        return (200, json(["data": ["id": "tx-1", "status": "complete", "responseStatus": "complete-ok"]]))
    }
    return (200, json([:]))
}

private func json(_ value: [String: Any]) -> Data {
    try! JSONSerialization.data(withJSONObject: value)
}
