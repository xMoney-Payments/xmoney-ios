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

    func testCloseAfterBackgroundCountsAsBankHandoff() {
        XCTAssertEqual(
            ThreeDSSessionOutcome.resolve(programmaticDismiss: false, backgrounded: true),
            .userCanceled(bankHandoff: true)
        )
        XCTAssertEqual(
            threeDSChallengeFollowUp(ThreeDSSessionOutcome.resolve(programmaticDismiss: false, backgrounded: true)),
            .reconcileCancel(graceNanoseconds: threeDSBankHandoffCancelGraceNanoseconds)
        )
    }

    func testProgrammaticDismissWinsOverBackground() {
        XCTAssertEqual(
            ThreeDSSessionOutcome.resolve(programmaticDismiss: true, backgrounded: true),
            .closedByPoll
        )
    }
}
