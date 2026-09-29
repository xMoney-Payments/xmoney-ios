import XCTest
@testable import XMoneyCore

final class ThreeDSRedirectPolicyTests: XCTestCase {
    func testHTTPSStaysInBrowser() {
        XCTAssertEqual(ThreeDSRedirectPolicy.decide(url("https://acs.bank/challenge")), .stayInBrowser)
    }

    func testHTTPIsRejected() {
        XCTAssertEqual(ThreeDSRedirectPolicy.decide(url("http://acs.bank/challenge")), .reject)
    }

    func testSystemSchemesAreRejected() {
        let schemes = [
            "javascript:alert(1)",
            "data:text/html,hi",
            "file:///tmp/x",
            "blob:https://acs.bank/id",
            "about:blank",
            "tel:555",
            "sms:555",
            "mailto:a@b.c",
            "facetime:user@bank",
            "facetime-audio:user@bank",
            "maps://place",
            "itms-apps://apps.apple.com",
            "shortcuts://run",
        ]
        for raw in schemes {
            XCTAssertEqual(ThreeDSRedirectPolicy.decide(url(raw)), .reject, raw)
        }
    }

    func testBankSchemeOpensExternally() {
        XCTAssertEqual(ThreeDSRedirectPolicy.decide(url("bankapp://authenticate")), .openExternally)
    }

    func testMissingSchemeIsRejected() {
        XCTAssertEqual(ThreeDSRedirectPolicy.decide(url("no-scheme")), .reject)
    }

    private func url(_ raw: String) -> URL {
        URL(string: raw)!
    }
}

final class ThreeDSChallengeFollowUpTests: XCTestCase {
    func testClosedByPollWaits() {
        XCTAssertEqual(threeDSChallengeFollowUp(.closedByPoll), .waitForPoll)
    }

    func testUserCloseUsesShortGrace() {
        XCTAssertEqual(
            threeDSChallengeFollowUp(.userCanceled(bankHandoff: false)),
            .reconcileCancel(graceNanoseconds: threeDSCancelReconcileGraceNanoseconds)
        )
        XCTAssertEqual(threeDSCancelReconcileGraceNanoseconds, 4_000_000_000)
    }

    func testBankHandoffCancelUsesThirtySecondGrace() {
        XCTAssertEqual(
            threeDSChallengeFollowUp(.userCanceled(bankHandoff: true)),
            .reconcileCancel(graceNanoseconds: threeDSBankHandoffCancelGraceNanoseconds)
        )
        XCTAssertEqual(threeDSBankHandoffCancelGraceNanoseconds, 30_000_000_000)
    }

    func testUnavailableIsPresentationError() {
        XCTAssertEqual(
            threeDSChallengeFollowUp(.unavailable),
            .throwThreeDS("Unable to present the authentication challenge")
        )
    }

    func testRejectedRedirectChecksCompletionBeforeFailing() {
        XCTAssertEqual(
            threeDSChallengeFollowUp(.rejectedRedirect),
            .throwThreeDSUnlessComplete("Insecure authentication redirect")
        )
    }
}
