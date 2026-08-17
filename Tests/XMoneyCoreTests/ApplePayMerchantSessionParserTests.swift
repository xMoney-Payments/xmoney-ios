import XCTest
@testable import XMoneyCore

final class ApplePayMerchantSessionParserTests: XCTestCase {
    func testMerchantSessionDictionaryPrefersDataEnvelope() {
        let response: [String: Any] = [
            "data": ["epochTimestamp": 1_234_567_890, "merchantSessionIdentifier": "abc"],
            "status": "ok",
        ]

        let dictionary = ApplePayMerchantSessionParser.merchantSessionDictionary(from: response)

        XCTAssertEqual(dictionary?["merchantSessionIdentifier"] as? String, "abc")
    }

    func testMerchantSessionDictionaryFallsBackToTopLevel() {
        let response: [String: Any] = [
            "epochTimestamp": 1_234_567_890,
            "merchantSessionIdentifier": "top-level",
        ]

        let dictionary = ApplePayMerchantSessionParser.merchantSessionDictionary(from: response)

        XCTAssertEqual(dictionary?["merchantSessionIdentifier"] as? String, "top-level")
    }
}
