import UIKit
import XCTest
@testable import XMoneyPaymentElement
@testable import XMoneyPaymentSheet
@testable import XMoneyCore

@MainActor
final class PersonalDetailsSheetHeightTests: XCTestCase {
    func testCondensedDetailsPageFitsWithoutScrolling() {
        let visibility = CustomerDetailsVisibility.resolve(
            fields: ["firstName", "email", "phone", "country", "state", "city", "zipCode", "address"]
        )
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
            applePayAvailable: false,
            customerDetailsVisibility: visibility
        )
        let config = PaymentConfig(
            publicKey: "pk_test_x",
            customerDetails: .init(card: true)
        )
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

        let details = PersonalDetailsFlow.make(
            config: config,
            visibility: visibility,
            progress: sheet.personalDetailsProgress,
            onFinished: {}
        )
        details.showsFooterHairline = true
        details.prepareForPresentation(
            width: sheet.view.bounds.width,
            safeAreaBottom: sheet.view.safeAreaInsets.bottom
        )
        sheet.showPersonalDetails(details)
        height.constant = sheet.preferredSheetHeight
        host.view.layoutIfNeeded()
        // The page learns the home-indicator inset during layout and asks the sheet to grow.
        height.constant = sheet.preferredSheetHeight
        host.view.layoutIfNeeded()

        let scroll = details.view.firstDescendantScrollView()
        let overflow = (scroll?.contentSize.height ?? 0) - (scroll?.bounds.height ?? 0)
        XCTAssertNotNil(scroll)
        XCTAssertLessThanOrEqual(
            overflow,
            1,
            "sheet=\(sheet.preferredSheetHeight) overflow=\(overflow) safe=\(details.view.safeAreaInsets)"
        )
        XCTAssertEqual(scroll?.isScrollEnabled, false)
    }
}

private extension UIView {
    func firstDescendantScrollView() -> UIScrollView? {
        if let scroll = self as? UIScrollView { return scroll }
        for subview in subviews {
            if let found = subview.firstDescendantScrollView() { return found }
        }
        return nil
    }
}
