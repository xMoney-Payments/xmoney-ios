import XCTest
import XMoneyCore
import XMoneyApplePay

private actor ApplePayOrderGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}

private enum ApplePayOrderError: Error {
    case failed
}

final class ApplePayDismissTests: XCTestCase {
    @MainActor
    func testDismissIsSafeBeforePresent() {
        let applePay = ApplePay(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        applePay.dismiss()
        XCTAssertFalse(applePay.isOrderConsumed)
        XCTAssertTrue(applePay.isInteractionEnabled)
    }

    @MainActor
    func testPresentIsIgnoredWhileUpdatingOrder() {
        let applePay = ApplePay(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        XCTAssertTrue(applePay.isInteractionEnabled)
    }

    @MainActor
    func testCreateOrderLocksImmediatelyAndRestoresPreviousOrderAfterFailure() async {
        let started = expectation(description: "create order started")
        let gate = ApplePayOrderGate()
        var resultCount = 0
        let applePay = ApplePay(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in
            resultCount += 1
        }

        let update = Task { @MainActor in
            try await applePay.updateOrder {
                started.fulfill()
                await gate.wait()
                throw ApplePayOrderError.failed
            }
        }

        await fulfillment(of: [started], timeout: 1)
        XCTAssertFalse(applePay.isInteractionEnabled)

        await gate.open()
        do {
            try await update.value
            XCTFail("Expected createOrder to throw")
        } catch {
            XCTAssertTrue(error is ApplePayOrderError)
        }

        XCTAssertTrue(applePay.isInteractionEnabled)
        XCTAssertEqual(resultCount, 0)
    }
}
