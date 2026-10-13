import UIKit
import XCTest
@testable import XMoneyCore

@MainActor
final class ThreeDSSafariControllerTests: XCTestCase {
    /// Dismissing from the presenter removes the challenge and anything above it, such as the bank-app alert.
    func testCloseDismissesFromThePresenter() {
        let presenter = DismissSpy()
        let challenge = PresentedStub(presenter: presenter)

        ThreeDSSafariController.close(challenge, animated: false)

        XCTAssertEqual(presenter.dismissCount, 1)
        XCTAssertEqual(challenge.dismissCount, 0)
    }

    func testCloseFallsBackToTheChallengeWhenNotPresented() {
        let challenge = PresentedStub(presenter: nil)

        ThreeDSSafariController.close(challenge, animated: false)

        XCTAssertEqual(challenge.dismissCount, 1)
    }

    func testBankHandoffScreenUsesTheGivenLocale() {
        let screen = ThreeDSBankHandoffViewController(locale: "ro-RO")
        screen.loadViewIfNeeded()

        let texts = screen.view.allLabels.compactMap(\.text)
        XCTAssertTrue(texts.contains(Strings.text("threeds.bankHandoff.title", locale: "ro")))
        XCTAssertFalse(texts.contains(Strings.text("threeds.bankHandoff.title", locale: "en")))
    }
}

private class DismissSpy: UIViewController {
    private(set) var dismissCount = 0

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissCount += 1
    }
}

private final class PresentedStub: DismissSpy {
    private let presenter: UIViewController?

    init(presenter: UIViewController?) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var presentingViewController: UIViewController? { presenter }
}

private extension UIView {
    var allLabels: [UILabel] {
        subviews.flatMap { subview -> [UILabel] in
            ((subview as? UILabel).map { [$0] } ?? []) + subview.allLabels
        }
    }
}
