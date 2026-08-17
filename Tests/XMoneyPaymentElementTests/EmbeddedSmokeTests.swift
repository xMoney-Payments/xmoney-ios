import XCTest
@testable import XMoneyPaymentElement
import XMoneyCore

final class EmbeddedSmokeTests: XCTestCase {
    func testCheckoutThemeResolvesPrimary() {
        let config = PaymentConfig(publicKey: "test_pk_x")
        let theme = CheckoutTheme.resolve(config: config, isDark: false)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        theme.primary.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Int(r * 255), 0x7C)
        XCTAssertEqual(Int(g * 255), 0x4D)
        XCTAssertEqual(Int(b * 255), 0xFF)
    }

    func testBrandPrimaryIsXMoneyPurple() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        CheckoutTheme.brandPrimary.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Int(r * 255), 0x7C)
        XCTAssertEqual(Int(g * 255), 0x4D)
        XCTAssertEqual(Int(b * 255), 0xFF)
    }

    func testEmbeddedEventCasesExist() {
        let ready = EmbeddedEvent.ready
        let processing = EmbeddedEvent.processing(true)
        if case .ready = ready {} else { XCTFail() }
        if case .processing(let value) = processing {
            XCTAssertTrue(value)
        } else {
            XCTFail()
        }
    }
}
