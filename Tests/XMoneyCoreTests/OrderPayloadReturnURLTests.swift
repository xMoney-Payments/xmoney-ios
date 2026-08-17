import Foundation
import XCTest
@testable import XMoneyCore

final class OrderPayloadReturnURLTests: XCTestCase {
    func testMatchesSchemeHostAndPathPrefix() {
        let back = URL(string: "https://merchant.example/pay/return")!
        XCTAssertTrue(OrderPayloadDecoder.matchesReturnURL(
            URL(string: "https://merchant.example/pay/return")!,
            backURL: back
        ))
        XCTAssertTrue(OrderPayloadDecoder.matchesReturnURL(
            URL(string: "https://merchant.example/pay/return?status=ok")!,
            backURL: back
        ))
        XCTAssertTrue(OrderPayloadDecoder.matchesReturnURL(
            URL(string: "https://merchant.example/pay/return/extra")!,
            backURL: back
        ))
        XCTAssertFalse(OrderPayloadDecoder.matchesReturnURL(
            URL(string: "http://merchant.example/pay/return")!,
            backURL: back
        ))
        XCTAssertFalse(OrderPayloadDecoder.matchesReturnURL(
            URL(string: "https://evil.example/pay/return")!,
            backURL: back
        ))
        XCTAssertFalse(OrderPayloadDecoder.matchesReturnURL(
            URL(string: "https://merchant.example/other")!,
            backURL: back
        ))
        XCTAssertFalse(OrderPayloadDecoder.matchesReturnURL(
            URL(string: "https://merchant.example/pay/returnx")!,
            backURL: back
        ))
    }

    func testQueryStatusIsNotEnoughWithoutBackURL() {
        XCTAssertNil(OrderPayloadDecoder.backURL(from: "e30="))
    }
}
