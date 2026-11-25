import UIKit
import XCTest
@testable import XMoneyCore
@testable import XMoneyPaymentElement
@testable import XMoneyPaymentSheet

@MainActor
final class SheetContentHeightTests: XCTestCase {
    func testShortSheetHugsContentBelowTheMax() {
        let sheet = makeSheet(cardCount: 3, applePay: true)
        let screenHeight: CGFloat = 874
        let host = host(sheet, height: screenHeight)
        host.view.layoutIfNeeded()
        host.view.layoutIfNeeded()

        let preferred = sheet.preferredSheetHeight
        XCTAssertLessThan(preferred, screenHeight * 0.95)
        host.heightConstraint.constant = preferred
        host.view.layoutIfNeeded()
        host.view.layoutIfNeeded()

        let fieldScroll = sheet.view.firstDescendant { view in
            view is UIScrollView && !(view is PreferSelfScrollView)
        } as? UIScrollView
        XCTAssertNotNil(fieldScroll)
        XCTAssertFalse(fieldScroll?.isScrollEnabled ?? true)
        XCTAssertLessThanOrEqual(
            (fieldScroll?.contentSize.height ?? 0) - (fieldScroll?.bounds.height ?? 0),
            1
        )

        let powered = sheet.view.firstDescendant { $0 is PoweredByFooterView }
        XCTAssertNotNil(powered)
        if let powered {
            let poweredBottom = powered.convert(powered.bounds, to: sheet.view).maxY
            XCTAssertEqual(sheet.view.bounds.maxY - poweredBottom, 16, accuracy: 2)
        }
    }

    func testSavedCardViewportPeeksWhenMoreThanThreeCards() {
        let three = makeSheet(cardCount: 3, applePay: false)
        let threeHost = host(three, height: 874)
        threeHost.view.layoutIfNeeded()
        threeHost.heightConstraint.constant = three.preferredSheetHeight
        threeHost.view.layoutIfNeeded()
        let threeScroll = three.view.firstDescendant { $0 is PreferSelfScrollView } as? UIScrollView
        XCTAssertNotNil(threeScroll)
        XCTAssertEqual(threeScroll?.bounds.height ?? -1, 64 * 3, accuracy: 0.5)
        XCTAssertFalse(threeScroll?.isScrollEnabled ?? true)

        let four = makeSheet(cardCount: 4, applePay: false)
        let fourHost = host(four, height: 874)
        fourHost.view.layoutIfNeeded()
        fourHost.heightConstraint.constant = four.preferredSheetHeight
        fourHost.view.layoutIfNeeded()
        let fourScroll = four.view.firstDescendant { $0 is PreferSelfScrollView } as? UIScrollView
        XCTAssertNotNil(fourScroll)
        XCTAssertEqual(fourScroll?.bounds.height ?? -1, 64 * 3.35, accuracy: 0.5)
        XCTAssertTrue(fourScroll?.isScrollEnabled ?? false)
    }

    private func makeSheet(cardCount: Int, applePay: Bool) -> PaymentSheetViewController {
        let cards = (0..<cardCount).map { index in
            SavedCard(
                id: "card-\(index)",
                cardNumber: "411111111111111\(index)",
                cardType: "visa",
                cardExpiryDate: "12/26",
                bankName: "Bank \(index)"
            )
        }
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
            savedCards: cards,
            applePayAvailable: applePay,
            applePayReady: applePay
        )
        return PaymentSheetViewController(config: PaymentConfig(publicKey: "pk_test_x"), state: state)
    }

    private func host(_ sheet: PaymentSheetViewController, height: CGFloat) -> SheetHost {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: height))
        let host = SheetHost()
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.addChild(sheet)
        sheet.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(sheet.view)
        let heightConstraint = sheet.view.heightAnchor.constraint(equalToConstant: height)
        NSLayoutConstraint.activate([
            sheet.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            sheet.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            sheet.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor),
            heightConstraint,
        ])
        sheet.didMove(toParent: host)
        host.window = window
        host.heightConstraint = heightConstraint
        return host
    }
}

private final class SheetHost: UIViewController {
    var heightConstraint: NSLayoutConstraint!
    var window: UIWindow?
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
