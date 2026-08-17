import XCTest
@testable import XMoneyCore

final class ThreeDSResumeTests: XCTestCase {
    func testSecondResumeIsIgnored() async {
        let resume = ThreeDSResume()
        let value = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            resume.arm(continuation)
            XCTAssertTrue(resume.resume(true))
            XCTAssertFalse(resume.resume(false))
        }
        XCTAssertTrue(value)
    }
}
