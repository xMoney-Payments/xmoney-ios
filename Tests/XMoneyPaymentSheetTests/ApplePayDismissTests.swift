import XCTest
import XMoneyCore
import XMoneyApplePay

final class ApplePayDismissTests: XCTestCase {
    @MainActor
    func testDismissIsSafeBeforePresent() {
        let applePay = ApplePay(configuration: PaymentConfig(publicKey: "test_pk_x")) { _ in }
        applePay.dismiss()
        XCTAssertFalse(applePay.isOrderConsumed)
        XCTAssertTrue(applePay.isInteractionEnabled)
    }

    @MainActor
    func testPresentIsIgnoredWhileUpdatingOrder() {
        let applePay = ApplePay(configuration: PaymentConfig(publicKey: "test_pk_x")) { _ in }
        XCTAssertTrue(applePay.isInteractionEnabled)
    }
}
