import XCTest
import XMoneyCore
import XMoneyApplePay

final class ApplePayAvailabilityTests: XCTestCase {
    @MainActor
    func testFlagsStartFalse() {
        let applePay = ApplePay(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        XCTAssertFalse(applePay.isAvailable)
        XCTAssertFalse(applePay.isReady)
    }

    @MainActor
    func testAvailabilityBindFailureReturnsBothFalse() async throws {
        let applePay = ApplePay(configuration: PaymentConfig(publicKey: "pk_no_env")) { _ in }
        let intent = PaymentIntent(
            orderPayload: OrderPayload("e30="),
            orderChecksum: OrderChecksum("cs")
        )
        let flags = try await applePay.availability(intent: intent)
        XCTAssertFalse(flags.isAvailable)
        XCTAssertFalse(flags.isReady)
        XCTAssertFalse(applePay.isAvailable)
        XCTAssertFalse(applePay.isReady)
    }

    func testAvailabilityFlagsAreIndependent() {
        let availableOnly = ApplePayAvailability(isAvailable: true, isReady: false)
        XCTAssertTrue(availableOnly.isAvailable)
        XCTAssertFalse(availableOnly.isReady)
    }
}
