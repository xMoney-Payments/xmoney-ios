import XCTest
@testable import XMoneyCore
@testable import XMoneyApplePay

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
    func testApplePayButtonDoesNotNotifyAfterLeavingWindow() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        let button = ApplePayButton()
        button.frame = CGRect(x: 16, y: 100, width: 358, height: 56)
        var drawCount = 0
        button.onFirstDraw = { drawCount += 1 }

        window.rootViewController?.view.addSubview(button)
        button.removeFromSuperview()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(drawCount, 0)
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

    @MainActor
    func testSupersededCreateOrderFailureThrowsCancellation() async {
        let started = expectation(description: "first create order started")
        let applePay = ApplePay(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }

        let first = Task { @MainActor in
            try await applePay.updateOrder {
                started.fulfill()
                try await Task.sleep(nanoseconds: 10_000_000_000)
                return PaymentIntent(
                    orderPayload: OrderPayload("e30="),
                    orderChecksum: OrderChecksum("first")
                )
            }
        }
        await fulfillment(of: [started], timeout: 1)

        do {
            try await applePay.updateOrder {
                throw ApplePayOrderError.failed
            }
            XCTFail("Expected second createOrder to throw")
        } catch {
            XCTAssertTrue(error is ApplePayOrderError)
        }

        do {
            try await first.value
            XCTFail("Expected superseded update to be canceled")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    @MainActor
    func testDifferentIntentDuringPaymentThrowsBeforeRebinding() async {
        let applePay = ApplePay(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let current = PaymentIntent(orderPayload: OrderPayload("e30="), orderChecksum: OrderChecksum("current"))
        applePay.testingInstallPayable(current, processing: true)

        do {
            try await applePay.updateOrder(
                intent: PaymentIntent(orderPayload: OrderPayload("e30="), orderChecksum: OrderChecksum("next"))
            )
            XCTFail("Expected payment in progress")
        } catch let error as PaymentError {
            XCTAssertEqual(error.message, "Payment in progress")
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }

    @MainActor
    func testSameIntentDuringPaymentIsNoOp() async throws {
        let applePay = ApplePay(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let current = PaymentIntent(orderPayload: OrderPayload("e30="), orderChecksum: OrderChecksum("current"))
        applePay.testingInstallPayable(current, processing: true)
        try await applePay.updateOrder(intent: current)
        XCTAssertFalse(applePay.isInteractionEnabled)
    }

    @MainActor
    func testCreateOrderReturnsTheBoundIntentAndRunsOnTheMainActor() async throws {
        let applePay = ApplePay(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        applePay.testingLoad = { _ in Self.sampleState() }
        let next = Self.intent("next")
        var ranOnMain = false

        let bound = try await applePay.updateOrder {
            ranOnMain = Thread.isMainThread
            return next
        }

        XCTAssertEqual(bound, next)
        XCTAssertEqual(applePay.testingPayableIntent, next)
        XCTAssertTrue(ranOnMain)
        XCTAssertTrue(applePay.isInteractionEnabled)
    }

    @MainActor
    func testLaterBindFailureLocksTheStaleOrderUntilABindSucceeds() async throws {
        let applePay = ApplePay(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let current = Self.intent("current")
        applePay.testingInstallPayable(current)
        applePay.testingLoad = { _ in throw ApplePayOrderError.failed }

        do {
            try await applePay.updateOrder(intent: Self.intent("next"))
            XCTFail("Expected bind to throw")
        } catch {
            XCTAssertTrue(error is ApplePayOrderError)
        }
        XCTAssertEqual(applePay.testingPayableIntent, current)
        XCTAssertFalse(applePay.isInteractionEnabled)

        applePay.testingLoad = { _ in Self.sampleState() }
        try await applePay.updateOrder(intent: Self.intent("next"))
        XCTAssertTrue(applePay.isInteractionEnabled)
    }

    @MainActor
    func testMerchantUpdateWithTheBoundIntentSupersedesInFlightCreation() async throws {
        let applePay = ApplePay(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let current = Self.intent("current")
        applePay.testingInstallPayable(current)
        let started = expectation(description: "create order started")
        let first = Task { @MainActor in
            try await applePay.updateOrder {
                started.fulfill()
                try await Task.sleep(nanoseconds: 10_000_000_000)
                return Self.intent("late")
            }
        }
        await fulfillment(of: [started], timeout: 1)

        try await applePay.updateOrder(intent: current)

        do {
            _ = try await first.value
            XCTFail("Expected superseded update to be canceled")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(applePay.testingPayableIntent, current)
        XCTAssertTrue(applePay.isInteractionEnabled)
    }

    @MainActor
    func testCancellingTheCallerCancelsCreateOrder() async {
        let applePay = ApplePay(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let started = expectation(description: "create order started")
        let cancelled = expectation(description: "create order cancelled")
        let update = Task { @MainActor in
            try await applePay.updateOrder {
                started.fulfill()
                do {
                    try await Task.sleep(nanoseconds: 10_000_000_000)
                } catch {
                    cancelled.fulfill()
                    throw error
                }
                return Self.intent("never")
            }
        }
        await fulfillment(of: [started], timeout: 1)
        update.cancel()
        await fulfillment(of: [cancelled], timeout: 1)

        do {
            _ = try await update.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    private static func intent(_ suffix: String) -> PaymentIntent {
        PaymentIntent(orderPayload: OrderPayload("e30="), orderChecksum: OrderChecksum(suffix))
    }

    private static func sampleState() -> SheetState {
        SheetState(
            sessionToken: "tok",
            orderInfo: OrderPayloadInfo(
                cardTransactionMode: nil,
                isVerifyCard: false,
                amount: 19.99,
                currency: "EUR",
                externalOrderId: "order-1",
                isRecurring: false
            ),
            savedCards: [],
            applePayAvailable: false
        )
    }
}
