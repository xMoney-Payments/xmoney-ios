import UIKit
import XCTest
@testable import XMoneyPaymentElement
@testable import XMoneyPaymentSheet
@testable import XMoneyCore

@MainActor
final class SheetPinnedChromeTests: XCTestCase {
    func testCloseAndPayStayPutWhenTheFormOverflows() {
        let state = SheetState(
            sessionToken: "tok",
            orderInfo: OrderPayloadInfo(
                cardTransactionMode: nil,
                isVerifyCard: false,
                amount: 19.99,
                currency: "EUR",
                externalOrderId: "order-1",
                isRecurring: false
            ),
            savedCards: [],
            applePayAvailable: false
        )
        let config = PaymentConfig(publicKey: "pk_test_x")
        let sheet = PaymentSheetViewController(config: config, state: state)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let host = UIViewController()
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.addChild(sheet)
        sheet.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(sheet.view)
        let height = sheet.view.heightAnchor.constraint(equalToConstant: 874)
        NSLayoutConstraint.activate([
            sheet.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            sheet.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            sheet.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor),
            height,
        ])
        sheet.didMove(toParent: host)
        host.view.layoutIfNeeded()

        let fullHeight = sheet.preferredSheetHeight
        let clamped: CGFloat = 360
        XCTAssertGreaterThan(fullHeight, clamped, "form should be tall enough to overflow a short sheet")
        height.constant = clamped
        host.view.layoutIfNeeded()
        host.view.layoutIfNeeded()

        let close = sheet.view.firstDescendant { $0 is CircleCloseButton }
        let pay = sheet.view.firstDescendant { $0 is PayCTAButton }
        let scroll = sheet.view.firstDescendant { $0 is UIScrollView } as? UIScrollView
        XCTAssertNotNil(close)
        XCTAssertNotNil(pay)
        XCTAssertNotNil(scroll)
        guard let close, let pay, let scroll else { return }

        let closeTop = close.convert(close.bounds, to: sheet.view).minY
        let payBottom = pay.convert(pay.bounds, to: sheet.view).maxY
        XCTAssertLessThan(closeTop, 80)
        XCTAssertGreaterThan(payBottom, sheet.view.bounds.height - 160)
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height + 1)
        XCTAssertTrue(scroll.isScrollEnabled)

        scroll.contentOffset = CGPoint(x: 0, y: 40)
        host.view.layoutIfNeeded()

        let scrolledClose = close.convert(close.bounds, to: sheet.view).minY
        let scrolledPay = pay.convert(pay.bounds, to: sheet.view).maxY
        XCTAssertEqual(scrolledClose, closeTop, accuracy: 0.5)
        XCTAssertEqual(scrolledPay, payBottom, accuracy: 0.5)
    }
}

private extension UIView {
    func firstDescendant(where matches: (UIView) -> Bool) -> UIView? {
        if matches(self) { return self }
        for subview in subviews {
            if let found = subview.firstDescendant(where: matches) { return found }
        }
        return nil
    }
}
