import XCTest
@testable import XMoneyPaymentSheet
import XMoneyPaymentElement

final class PaymentSheetAssetsTests: XCTestCase {
    func testReferencedAssetsResolve() {
        let names = [
            "card-visa",
            "card-mastercard",
            "card-amex",
            "card-discover",
            "card-generic",
            "card-stack",
            "check",
            "chevron-down",
            "lock",
            "plus",
            "xmoney-wordmark",
        ]
        for name in names {
            XCTAssertNotNil(EmbeddedAssets.image(named: name), "Missing asset: \(name)")
        }
        XCTAssertNotNil(EmbeddedAssets.image(named: "xmoney-xmark"), "Missing asset: xmoney-xmark")
        XCTAssertNotNil(EmbeddedAssets.image(named: "xmoney-3ds-brand"), "Missing asset: xmoney-3ds-brand")
    }
}
