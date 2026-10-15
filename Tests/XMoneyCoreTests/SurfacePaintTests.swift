import PassKit
import XCTest
@testable import XMoneyCore

final class SurfacePaintTests: XCTestCase {
    /// The system `PKPaymentButton` initializer waits on card art on iOS 26, so a
    /// simulator with no Wallet cards never paints inside the wait. Shipping UI
    /// uses `ApplePayButtonFactory`, which disables that art and draws on the first frame.
    @MainActor
    func testFactoryButtonPaintsWithoutTimeout() async {
        let window = Self.makeWindow()
        let button = ApplePayButtonFactory.make(type: .buy, style: .black)
        button.frame = CGRect(x: 16, y: 100, width: 358, height: 56)
        window.rootViewController?.view.addSubview(button)

        let started = Date()
        let drawn = await SurfacePaint.waitUntilButtonDrawn(button, timeout: 2)

        XCTAssertTrue(drawn)
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.5)
    }

    @MainActor
    func testWaitWithoutAWindowReturnsFalseImmediately() async {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let started = Date()

        let drawn = await SurfacePaint.waitUntilLaidOut(view, timeout: 1)

        XCTAssertFalse(drawn)
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.2)
    }

    @MainActor
    func testWaitInAWindowReturnsTrue() async {
        let window = Self.makeWindow()
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        window.rootViewController?.view.addSubview(view)

        let drawn = await SurfacePaint.waitUntilLaidOut(view, timeout: 1)

        XCTAssertTrue(drawn)
    }

    @MainActor
    func testCancelledWaitReturnsFalse() async {
        let window = Self.makeWindow()
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        window.rootViewController?.view.addSubview(view)

        let wait = Task { @MainActor in await SurfacePaint.waitUntilLaidOut(view, timeout: 1) }
        wait.cancel()

        let drawn = await wait.value
        XCTAssertFalse(drawn)
    }

    @MainActor
    private static func makeWindow() -> UIWindow {
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        return window
    }
}
