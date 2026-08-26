import UIKit
import XCTest
@testable import XMoneyCore

@MainActor
final class PresentationAnchorTests: XCTestCase {
    func testResolveWalksFromChildToAControllerInTheWindow() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let parent = UIViewController()
        window.rootViewController = parent
        window.isHidden = false
        parent.loadViewIfNeeded()

        let child = UIViewController()
        parent.addChild(child)
        parent.view.addSubview(child.view)
        child.didMove(toParent: parent)
        child.loadViewIfNeeded()
        window.layoutIfNeeded()

        XCTAssertNotNil(parent.view.window)
        let resolved = PresentationAnchor.resolve(from: child)
        XCTAssertTrue(PresentationAnchor.isPresentable(resolved))
        XCTAssertTrue(resolved === parent || resolved === child)

        window.isHidden = true
    }

    func testDetachedControllerIsNotPresentable() {
        let origin = UIViewController()
        origin.loadViewIfNeeded()
        XCTAssertFalse(PresentationAnchor.isPresentable(origin))
    }
}
