import PassKit
import XCTest
@testable import XMoneyCore

final class SurfacePaintTests: XCTestCase {
    @MainActor
    func testApplePayButtonPaintWaitReturnsWithoutTimeout() async {
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()

        let button = PKPaymentButton(
            paymentButtonType: .buy,
            paymentButtonStyle: .black
        )
        button.frame = CGRect(x: 16, y: 100, width: 358, height: 56)
        window.rootViewController?.view.addSubview(button)

        let started = Date()
        await SurfacePaint.waitUntilButtonDrawn(button)

        XCTAssertLessThan(Date().timeIntervalSince(started), 0.5)
    }

    @MainActor
    func testLayoutWaitRequiresAWindowAndUsesWallClockTimeout() async {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let started = Date()

        await SurfacePaint.waitUntilLaidOut(view, timeout: 0.05)

        let elapsed = Date().timeIntervalSince(started)
        XCTAssertGreaterThanOrEqual(elapsed, 0.04)
        XCTAssertLessThan(elapsed, 0.5)
    }
}
