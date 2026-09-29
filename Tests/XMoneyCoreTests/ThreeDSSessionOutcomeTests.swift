import XCTest
@testable import XMoneyCore

final class ThreeDSSessionOutcomeTests: XCTestCase {
    func testProgrammaticDismissIsClosedByPoll() {
        XCTAssertEqual(
            ThreeDSSessionOutcome.resolve(programmaticDismiss: true),
            .closedByPoll
        )
    }

    func testUserCloseIsUserCancel() {
        XCTAssertEqual(
            ThreeDSSessionOutcome.resolve(programmaticDismiss: false),
            .userCanceled(bankHandoff: false)
        )
    }

    func testProgrammaticDismissWinsOverBankHandoff() {
        XCTAssertEqual(
            ThreeDSSessionOutcome.resolve(programmaticDismiss: true, bankHandoff: true),
            .closedByPoll
        )
    }
}
