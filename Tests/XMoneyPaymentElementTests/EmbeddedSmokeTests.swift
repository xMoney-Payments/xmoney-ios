import XCTest
@testable import XMoneyPaymentElement
import XMoneyCore

final class EmbeddedSmokeTests: XCTestCase {
    func testCheckoutThemeResolvesPrimary() {
        let config = PaymentConfig(publicKey: "pk_test_x")
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

    @MainActor
    func testUpdateAppearanceAndLocaleBeforePrepare() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        embedded.updateAppearance(.init())
        embedded.updateLocale("el-GR")
        embedded.updateStyle(.alwaysDark)
        embedded.updateWalletAppearance(.init(color: .white, radius: 12, type: .pay))
        XCTAssertEqual(embedded._controller.paymentConfig?.options.locale, "el-GR")
        XCTAssertEqual(embedded._controller.paymentConfig?.options.style, .alwaysDark)
        XCTAssertEqual(embedded._controller.paymentConfig?.paymentMethods.applePay.appearance.color, .white)
        XCTAssertFalse(embedded.isInteractionEnabled)
        embedded.confirm()
    }

    @MainActor
    func testConfirmIsNoOpWhileUpdatingOrderFlag() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        XCTAssertFalse(embedded.isInteractionEnabled)
        embedded.confirm()
    }

    func testEmbeddedContentInsetsAreZero() {
        let insets = PaymentFormView.ContentInsets.embedded
        XCTAssertEqual(insets.horizontal, 0)
        XCTAssertEqual(insets.top, 0)
        XCTAssertEqual(insets.bottom, 0)
        XCTAssertNotEqual(insets, .sheet)
    }
}
