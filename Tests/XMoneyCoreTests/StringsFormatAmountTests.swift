import XCTest
@testable import XMoneyCore

final class StringsFormatAmountTests: XCTestCase {
    func testFormatAmountUsesOptionsLocaleNotDeviceDefault() {
        let us = Strings.formatAmount(10.5, currency: "EUR", locale: "en-US")
        let el = Strings.formatAmount(10.5, currency: "EUR", locale: "el-GR")
        let ro = Strings.formatAmount(10.5, currency: "EUR", locale: "ro-RO")
        XCTAssertNotNil(us)
        XCTAssertNotNil(el)
        XCTAssertNotNil(ro)
        XCTAssertNotEqual(us, el)
        XCTAssertNotEqual(us, ro)
    }

    func testFormatAmountFallsBackForUnknownLocaleIdentifier() {
        let formatted = Strings.formatAmount(10, currency: "EUR", locale: "not-a-locale")
        XCTAssertNotNil(formatted)
        XCTAssertFalse(formatted!.isEmpty)
    }
}
