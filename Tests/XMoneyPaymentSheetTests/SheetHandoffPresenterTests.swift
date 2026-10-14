import XCTest
import XMoneyCore
@testable import XMoneyApplePay

final class SheetHandoffPresenterTests: XCTestCase {
    func testForwardsChallengeToTheSurfacePresenter() async {
        let inner = RecordingPresenter()
        let presenter = SheetHandoffPresenter(inner: inner, handler: nil)
        let url = URL(string: "https://acs.example/challenge")!

        let end = await presenter.presentThreeDS(url: url)

        XCTAssertEqual(end, .closedByPoll)
        XCTAssertEqual(inner.presentedURLs, [url])
    }

    @MainActor
    func testSkipsTheChallengeWhenThePollAlreadyFinished() async {
        let inner = RecordingPresenter()
        let presenter = SheetHandoffPresenter(inner: inner, handler: nil)
        let task = Task { @MainActor in
            await presenter.presentThreeDS(url: URL(string: "https://acs.example/challenge")!)
        }
        task.cancel()

        let end = await task.value
        XCTAssertEqual(end, .closedByPoll)
        XCTAssertTrue(inner.presentedURLs.isEmpty)
    }

    func testForwardsDismiss() {
        let inner = RecordingPresenter()
        let presenter = SheetHandoffPresenter(inner: inner, handler: nil)

        presenter.dismissThreeDS()

        XCTAssertEqual(inner.dismissCount, 1)
    }
}

private final class RecordingPresenter: ThreeDSPresenter {
    private(set) var presentedURLs: [URL] = []
    private(set) var dismissCount = 0

    func presentThreeDS(url: URL) async -> ThreeDSChallengeEnd {
        presentedURLs.append(url)
        return .closedByPoll
    }

    func dismissThreeDS() {
        dismissCount += 1
    }
}
