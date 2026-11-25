import XCTest
@testable import XMoneyCore

final class HTTPClientRedactionTests: XCTestCase {
    func testRedactsCustomerPiiAndCardFields() {
        let body: [String: Any] = [
            "email": "ada@example.com",
            "phone": "+40722111222",
            "firstName": "Ada",
            "lastName": "Lovelace",
            "fullName": "Ada Lovelace",
            "address": "1 Market",
            "city": "London",
            "zipCode": "EC1",
            "postalCode": "EC1",
            "region": "Greater London",
            "country": "GB",
            "customerDetails": ["email": "nested@example.com"],
            "digitalWalletData": "token-value",
            "cardNumber": "4242",
            "code": 400,
            "message": "declined",
        ]
        let redacted = HTTPClient.redactSensitiveValues(in: body) as? [String: Any]
        XCTAssertEqual(redacted?["email"] as? String, "<redacted>")
        XCTAssertEqual(redacted?["phone"] as? String, "<redacted>")
        XCTAssertEqual(redacted?["firstName"] as? String, "<redacted>")
        XCTAssertEqual(redacted?["lastName"] as? String, "<redacted>")
        XCTAssertEqual(redacted?["fullName"] as? String, "<redacted>")
        XCTAssertEqual(redacted?["address"] as? String, "<redacted>")
        XCTAssertEqual(redacted?["city"] as? String, "<redacted>")
        XCTAssertEqual(redacted?["zipCode"] as? String, "<redacted>")
        XCTAssertEqual(redacted?["postalCode"] as? String, "<redacted>")
        XCTAssertEqual(redacted?["region"] as? String, "<redacted>")
        XCTAssertEqual(redacted?["country"] as? String, "<redacted>")
        XCTAssertEqual(redacted?["digitalWalletData"] as? String, "<redacted>")
        XCTAssertEqual(redacted?["cardNumber"] as? String, "<redacted>")
        XCTAssertEqual(redacted?["customerDetails"] as? String, "<redacted>")
        XCTAssertEqual(redacted?["code"] as? Int, 400)
        XCTAssertEqual(redacted?["message"] as? String, "declined")
    }
}
