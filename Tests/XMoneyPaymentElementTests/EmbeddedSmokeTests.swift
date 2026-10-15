import SwiftUI
import XCTest
@testable import XMoneyPaymentElement
@testable import XMoneyCore

private actor EmbeddedOrderGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}

private enum EmbeddedOrderError: Error {
    case failed
}

final class EmbeddedSmokeTests: XCTestCase {
    func testCheckoutThemeResolvesPrimary() {
        let config = PaymentConfig(publicKey: "pk_test_x")
        let theme = CheckoutTheme.resolve(config: config, isDark: false)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        theme.primary.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Int(r * 255), 0x7C)
        XCTAssertEqual(Int(g * 255), 0x4D)
        XCTAssertEqual(Int(b * 255), 0xFF)
    }

    func testBrandPrimaryIsXMoneyPurple() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        CheckoutTheme.brandPrimary.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Int(r * 255), 0x7C)
        XCTAssertEqual(Int(g * 255), 0x4D)
        XCTAssertEqual(Int(b * 255), 0xFF)
    }

    func testEmbeddedEventCasesExist() {
        let ready = EmbeddedEvent.ready
        let processing = EmbeddedEvent.processing(true)
        if case .ready = ready {} else { XCTFail() }
        if case .processing(let value) = processing {
            XCTAssertTrue(value)
        } else {
            XCTFail()
        }
    }

    @MainActor
    func testUpdateAppearanceAndLocaleBeforePrepare() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        embedded.updateAppearance(.init())
        embedded.updateLocale("el-GR")
        embedded.updateStyle(.alwaysDark)
        embedded.updateWalletAppearance(.init(color: .white, radius: 12, type: .pay))
        XCTAssertEqual(embedded._controller.paymentConfig?.options.locale, "el-GR")
        XCTAssertEqual(embedded._controller.paymentConfig?.options.style, .alwaysDark)
        XCTAssertEqual(embedded._controller.paymentConfig?.paymentMethods.applePay.appearance.color, .white)
        XCTAssertFalse(embedded.isInteractionEnabled)
        embedded.confirm()
    }

    @MainActor
    func testConfirmIsNoOpWhileUpdatingOrderFlag() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        XCTAssertFalse(embedded.isInteractionEnabled)
        embedded.confirm()
    }

    @MainActor
    func testCreateOrderLocksImmediatelyAndRestoresStateAfterFailure() async {
        let started = expectation(description: "create order started")
        let gate = EmbeddedOrderGate()
        var resultCount = 0
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in
            resultCount += 1
        }

        let update = Task { @MainActor in
            try await embedded.updateOrder {
                started.fulfill()
                await gate.wait()
                throw EmbeddedOrderError.failed
            }
        }

        await fulfillment(of: [started], timeout: 1)
        XCTAssertTrue(embedded._controller.isUpdatingOrder)
        XCTAssertFalse(embedded.isInteractionEnabled)

        await gate.open()
        do {
            try await update.value
            XCTFail("Expected createOrder to throw")
        } catch {
            XCTAssertTrue(error is EmbeddedOrderError)
        }

        XCTAssertFalse(embedded._controller.isUpdatingOrder)
        XCTAssertEqual(resultCount, 0)
    }

    @MainActor
    func testCreateOrderWithoutEventHandlerKeepsExistingHandler() async {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        var processingEvents: [Bool] = []

        do {
            try await embedded.updateOrder(
                onEvent: { event in
                    if case let .processing(value) = event {
                        processingEvents.append(value)
                    }
                },
                createOrder: { throw EmbeddedOrderError.failed }
            )
            XCTFail("Expected createOrder to throw")
        } catch {
            XCTAssertTrue(error is EmbeddedOrderError)
        }

        do {
            try await embedded.updateOrder {
                throw EmbeddedOrderError.failed
            }
            XCTFail("Expected createOrder to throw")
        } catch {
            XCTAssertTrue(error is EmbeddedOrderError)
        }

        embedded._controller.emit(.processing(true))
        XCTAssertEqual(processingEvents, [true])
    }

    @MainActor
    func testSupersededCreateOrderFailureThrowsCancellation() async {
        let started = expectation(description: "first create order started")
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }

        let first = Task { @MainActor in
            try await embedded.updateOrder {
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
            try await embedded.updateOrder {
                throw EmbeddedOrderError.failed
            }
            XCTFail("Expected second createOrder to throw")
        } catch {
            XCTAssertTrue(error is EmbeddedOrderError)
        }

        do {
            try await first.value
            XCTFail("Expected superseded update to be canceled")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    @MainActor
    func testRevealWhileLoaderVisibleHidesCoverAndEmitsReadyOnce() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        element._installFormForTesting(config: PaymentConfig(publicKey: "pk_test_x"), state: Self.sampleState())

        XCTAssertTrue(element.isLoaderVisible)
        element.revealIfNeeded()
        element.revealIfNeeded()

        XCTAssertFalse(element.isLoaderVisible)
        XCTAssertEqual(readyCount, 1)
    }

    @MainActor
    func testRevealWithoutAFormDoesNotEmitReady() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }

        element.revealIfNeeded()

        XCTAssertTrue(element.isLoaderVisible)
        XCTAssertEqual(readyCount, 0)
    }

    @MainActor
    func testFailureStateReplacesLoaderWithLocalizedMessageAndNoReady() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }

        element.showFailure(PaymentError.load("raw server response"))
        element.revealIfNeeded()

        XCTAssertFalse(element.isLoaderVisible)
        XCTAssertTrue(element.isFailureVisible)
        XCTAssertEqual(element.failureMessage, Strings.text("element.loadFailed", locale: "en"))
        XCTAssertEqual(readyCount, 0)
    }

    @MainActor
    func testReadyIsScopedToEachMountedElement() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        var readyCount = 0

        for _ in 0..<2 {
            let element = PaymentElement(payment: embedded) { event in
                if case .ready = event { readyCount += 1 }
            }
            element._installFormForTesting(config: PaymentConfig(publicKey: "pk_test_x"), state: Self.sampleState())
            element.revealIfNeeded()
        }

        XCTAssertEqual(readyCount, 2)
    }

    @MainActor
    func testPrepareRendersDrawsAndEmitsReadyOncePerSurface() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        embedded._controller.testingLoad = { _ in Self.sampleState() }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        let window = Self.host(element)

        try await element.prepare(intent: Self.sampleIntent("a"))

        XCTAssertTrue(element.isFormVisible)
        XCTAssertEqual(readyCount, 1)
        XCTAssertFalse(element.isPayLockedForTesting)

        try await element.updateOrder(intent: Self.sampleIntent("b"))
        XCTAssertEqual(embedded.boundIntent, Self.sampleIntent("b"))
        XCTAssertEqual(readyCount, 1)
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testPrepareOutsideAWindowRevealsOnceMounted() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        embedded._controller.testingLoad = { _ in Self.sampleState() }
        let ready = expectation(description: "ready")
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event {
                readyCount += 1
                ready.fulfill()
            }
        }

        try await element.prepare(intent: Self.sampleIntent("a"))
        XCTAssertEqual(readyCount, 0)

        let window = Self.host(element)
        await fulfillment(of: [ready], timeout: 3)
        XCTAssertTrue(element.isFormVisible)
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testInitialFailureHasNoReadyThenARetryEmitsReady() async throws {
        var results: [PaymentResult] = []
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { results.append($0) }
        var loads = 0
        embedded._controller.testingLoad = { _ in
            loads += 1
            if loads <= 2 { throw PaymentError.load("raw server response") }
            return Self.sampleState()
        }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        let window = Self.host(element)

        for _ in 0..<2 {
            do {
                try await element.prepare(intent: Self.sampleIntent("a"))
                XCTFail("Expected prepare to throw")
            } catch {
                XCTAssertTrue(error is PaymentError)
            }
        }
        XCTAssertTrue(element.isFailureVisible)
        XCTAssertEqual(readyCount, 0)
        XCTAssertEqual(results.count, 1, "`.failed` is reported once per failure streak")

        try await element.prepare(intent: Self.sampleIntent("a"))
        XCTAssertFalse(element.isFailureVisible)
        XCTAssertTrue(element.isFormVisible)
        XCTAssertEqual(readyCount, 1)
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testSupersededFirstPrepareShowsNoFailureAndTheNewerBindRenders() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let gate = EmbeddedOrderGate()
        let firstStarted = expectation(description: "first load started")
        embedded._controller.testingLoad = { intent in
            if intent == Self.sampleIntent("a") {
                firstStarted.fulfill()
                await gate.wait()
                throw PaymentError.load("raw server response")
            }
            return Self.sampleState()
        }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        let window = Self.host(element)

        let first = Task { @MainActor in try await element.prepare(intent: Self.sampleIntent("a")) }
        await fulfillment(of: [firstStarted], timeout: 1)
        try await element.prepare(intent: Self.sampleIntent("b"))
        await gate.open()

        do {
            try await first.value
            XCTFail("Expected the first prepare to be superseded")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertFalse(element.isFailureVisible)
        XCTAssertTrue(element.isFormVisible)
        XCTAssertEqual(readyCount, 1)
        XCTAssertEqual(embedded.boundIntent, Self.sampleIntent("b"))
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testCreateOrderWithoutAFormLocksPayAndRendersOnReturn() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        embedded._controller.testingLoad = { _ in Self.sampleState() }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        let window = Self.host(element)
        let started = expectation(description: "create order started")
        let gate = EmbeddedOrderGate()

        let update = Task { @MainActor in
            try await element.updateOrder {
                started.fulfill()
                await gate.wait()
                return Self.sampleIntent("a")
            }
        }
        await fulfillment(of: [started], timeout: 1)
        XCTAssertTrue(embedded._controller.isUpdatingOrder)
        XCTAssertFalse(embedded.isInteractionEnabled)
        XCTAssertTrue(element.isLoaderVisible)

        await gate.open()
        let bound = try await update.value
        XCTAssertEqual(bound, Self.sampleIntent("a"))
        XCTAssertTrue(element.isFormVisible)
        XCTAssertTrue(embedded.isInteractionEnabled)
        XCTAssertEqual(readyCount, 1)
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testLaterBindFailureLocksPayOnTheStaleOrderAndEmitsUpdateFailed() async throws {
        var results = 0
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in results += 1 }
        embedded._controller.testingLoad = { _ in Self.sampleState() }
        let updateFailed = expectation(description: "updateFailed")
        let element = PaymentElement(payment: embedded) { event in
            if case .updateFailed = event { updateFailed.fulfill() }
        }
        let window = Self.host(element)
        try await element.prepare(intent: Self.sampleIntent("a"))

        embedded._controller.testingLoad = { _ in throw PaymentError.load("raw server response") }
        do {
            try await element.updateOrder(intent: Self.sampleIntent("b"))
            XCTFail("Expected bind to throw")
        } catch {
            XCTAssertTrue(error is PaymentError)
        }
        await fulfillment(of: [updateFailed], timeout: 1)

        XCTAssertEqual(embedded.boundIntent, Self.sampleIntent("a"))
        XCTAssertFalse(embedded.isInteractionEnabled)
        XCTAssertTrue(element.isPayLockedForTesting)
        XCTAssertTrue(element.isFormVisible)
        XCTAssertEqual(results, 0)

        embedded._controller.testingLoad = { _ in Self.sampleState() }
        try await element.updateOrder(intent: Self.sampleIntent("b"))
        XCTAssertTrue(embedded.isInteractionEnabled)
        XCTAssertFalse(element.isPayLockedForTesting)
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testCreateOrderFailureKeepsThePreviousOrderPayable() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        try embedded._controller.testingInstallBound(Self.sampleIntent("a"), state: Self.sampleState())

        do {
            try await embedded.updateOrder { throw EmbeddedOrderError.failed }
            XCTFail("Expected createOrder to throw")
        } catch {
            XCTAssertTrue(error is EmbeddedOrderError)
        }

        XCTAssertEqual(embedded.boundIntent, Self.sampleIntent("a"))
        XCTAssertTrue(embedded.isInteractionEnabled)
    }

    @MainActor
    func testCreateOrderRunsOnTheMainActorAndReturnsTheBoundIntent() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        try embedded._controller.testingInstallBound(Self.sampleIntent("a"), state: Self.sampleState())
        embedded._controller.testingLoad = { _ in Self.sampleState() }
        var ranOnMain = false

        let bound = try await embedded.updateOrder {
            ranOnMain = Thread.isMainThread
            return Self.sampleIntent("b")
        }

        XCTAssertTrue(ranOnMain)
        XCTAssertEqual(bound, Self.sampleIntent("b"))
        XCTAssertEqual(embedded.boundIntent, Self.sampleIntent("b"))
    }

    @MainActor
    func testCancellingTheCallerCancelsCreateOrder() async {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let started = expectation(description: "create order started")
        let cancelled = expectation(description: "create order cancelled")
        let update = Task { @MainActor in
            try await embedded.updateOrder {
                started.fulfill()
                do {
                    try await Task.sleep(nanoseconds: 10_000_000_000)
                } catch {
                    cancelled.fulfill()
                    throw error
                }
                return Self.sampleIntent("never")
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
        XCTAssertFalse(embedded._controller.isUpdatingOrder)
    }

    @MainActor
    func testOlderBindFinishingLastDoesNotOverwriteTheNewerOrder() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        try embedded._controller.testingInstallBound(Self.sampleIntent("a"), state: Self.sampleState())
        let gate = EmbeddedOrderGate()
        let olderStarted = expectation(description: "older load started")
        embedded._controller.testingLoad = { intent in
            if intent == Self.sampleIntent("b") {
                olderStarted.fulfill()
                await gate.wait()
            }
            return Self.sampleState()
        }

        let older = Task { @MainActor in try await embedded.updateOrder(intent: Self.sampleIntent("b")) }
        await fulfillment(of: [olderStarted], timeout: 1)
        try await embedded.updateOrder(intent: Self.sampleIntent("c"))
        await gate.open()

        do {
            try await older.value
            XCTFail("Expected the older bind to be superseded")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(embedded.boundIntent, Self.sampleIntent("c"))
        XCTAssertTrue(embedded.isInteractionEnabled)
    }

    @MainActor
    func testFailedBindOfASupersededOrderDoesNotLockTheNewerOrder() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        try embedded._controller.testingInstallBound(Self.sampleIntent("a"), state: Self.sampleState())
        let gate = EmbeddedOrderGate()
        let olderStarted = expectation(description: "older load started")
        embedded._controller.testingLoad = { intent in
            if intent == Self.sampleIntent("b") {
                olderStarted.fulfill()
                await gate.wait()
                throw EmbeddedOrderError.failed
            }
            return Self.sampleState()
        }

        let older = Task { @MainActor in try await embedded.updateOrder(intent: Self.sampleIntent("b")) }
        await fulfillment(of: [olderStarted], timeout: 1)
        try await embedded.updateOrder(intent: Self.sampleIntent("c"))
        await gate.open()

        do {
            try await older.value
            XCTFail("Expected the older bind to be superseded")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertFalse(embedded._controller.isStaleOrder)
        XCTAssertTrue(embedded.isInteractionEnabled)
    }

    @MainActor
    func testFailedUpdateDuringFirstDrawRevealsCoverAndEmitsReadyOnce() async {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        element._installFormForTesting(
            config: PaymentConfig(publicKey: "pk_test_x"),
            state: Self.sampleState()
        )
        element.frame = CGRect(x: 0, y: 0, width: 390, height: 600)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UIViewController()
        window.rootViewController = root
        root.view.addSubview(element)
        window.makeKeyAndVisible()
        root.view.layoutIfNeeded()
        element.layoutIfNeeded()

        do {
            try await element.updateOrder {
                throw EmbeddedOrderError.failed
            }
            XCTFail("Expected updateOrder to throw")
        } catch {
            XCTAssertTrue(error is EmbeddedOrderError)
        }

        XCTAssertFalse(element.isLoaderVisible)
        XCTAssertEqual(readyCount, 1)
    }

    @MainActor
    func testSupersededFailureDoesNotUnlockTheNewerUpdate() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        embedded._controller.testingLoad = { _ in Self.sampleState() }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        let window = Self.host(element)
        try await element.prepare(intent: Self.sampleIntent("a"))

        let firstStarted = expectation(description: "first update started")
        let firstGate = EmbeddedOrderGate()
        let first = Task { @MainActor in
            try await element.updateOrder {
                firstStarted.fulfill()
                await firstGate.wait()
                throw EmbeddedOrderError.failed
            }
        }
        await fulfillment(of: [firstStarted], timeout: 1)

        let secondStarted = expectation(description: "second update started")
        let secondGate = EmbeddedOrderGate()
        let second = Task { @MainActor in
            try await element.updateOrder {
                secondStarted.fulfill()
                await secondGate.wait()
                return Self.sampleIntent("c")
            }
        }
        await fulfillment(of: [secondStarted], timeout: 1)

        await firstGate.open()
        do {
            _ = try await first.value
            XCTFail("Expected the first update to be superseded")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertTrue(element.isPayLockedForTesting)

        await secondGate.open()
        let bound = try await second.value
        XCTAssertEqual(bound, Self.sampleIntent("c"))
        XCTAssertFalse(element.isPayLockedForTesting)
        XCTAssertTrue(element.isFormVisible)
        XCTAssertEqual(readyCount, 1)
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testPrepareFailureShowsFailureLabelThroughTheCatchPath() async {
        var results = 0
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_invalid")) { _ in
            results += 1
        }
        let element = PaymentElement(payment: embedded)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UIViewController()
        window.rootViewController = root
        element.frame = CGRect(x: 0, y: 0, width: 390, height: 200)
        root.view.addSubview(element)
        window.makeKeyAndVisible()

        do {
            try await element.prepare(intent: Self.sampleIntent("missing"))
            XCTFail("Expected prepare to throw")
        } catch {
            XCTAssertTrue(error is PaymentError)
        }

        XCTAssertTrue(element.isFailureVisible)
        XCTAssertFalse(element.isLoaderVisible)
        XCTAssertEqual(element.failureMessage, Strings.text("element.loadFailed", locale: "en"))
        XCTAssertEqual(results, 1)
    }

    @MainActor
    func testPaymentInProgressKeepsTheLoader() async {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let bound = Self.sampleIntent("bound")
        try? embedded._controller.testingInstallBound(bound, state: Self.sampleState(), processing: true)
        let element = PaymentElement(payment: embedded)

        do {
            try await element.prepare(intent: Self.sampleIntent("other"))
            XCTFail("Expected payment in progress")
        } catch {
            XCTAssertTrue(error is PaymentError)
        }

        XCTAssertTrue(element.isLoaderVisible)
        XCTAssertFalse(element.isFailureVisible)
    }

    @MainActor
    func testSameIntentDuringPaymentIsNoOp() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let bound = Self.sampleIntent("bound")
        try embedded._controller.testingInstallBound(bound, state: Self.sampleState(), processing: true)
        try await embedded.updateOrder(intent: bound)
    }

    @MainActor
    func testDifferentIntentDuringPaymentThrowsPaymentInProgress() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        try embedded._controller.testingInstallBound(Self.sampleIntent("bound"), state: Self.sampleState(), processing: true)

        do {
            try await embedded.updateOrder(intent: Self.sampleIntent("other"))
            XCTFail("Expected payment in progress")
        } catch let error as PaymentError {
            XCTAssertEqual(error, .paymentInProgress)
        }
        do {
            _ = try await embedded.updateOrder { Self.sampleIntent("other") }
            XCTFail("Expected payment in progress")
        } catch let error as PaymentError {
            XCTAssertEqual(error, .paymentInProgress)
        }
        XCTAssertEqual(embedded.boundIntent, Self.sampleIntent("bound"))
    }

    @MainActor
    func testMerchantCallWithTheBoundIntentSupersedesInFlightCreation() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let bound = Self.sampleIntent("bound")
        try embedded._controller.testingInstallBound(bound, state: Self.sampleState())
        let started = expectation(description: "create order started")
        let first = Task { @MainActor in
            try await embedded.updateOrder {
                started.fulfill()
                try await Task.sleep(nanoseconds: 10_000_000_000)
                return Self.sampleIntent("late")
            }
        }
        await fulfillment(of: [started], timeout: 1)

        try await embedded.updateOrder(intent: bound)

        do {
            _ = try await first.value
            XCTFail("Expected the in-flight creation to be superseded")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(embedded.boundIntent, bound)
        XCTAssertTrue(embedded.isInteractionEnabled)
    }

    @MainActor
    func testSurfaceRebindOfTheBoundIntentDoesNotCancelInFlightCreation() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let bound = Self.sampleIntent("bound")
        try embedded._controller.testingInstallBound(bound, state: Self.sampleState())
        embedded._controller.testingLoad = { _ in Self.sampleState() }
        let started = expectation(description: "create order started")
        let gate = EmbeddedOrderGate()
        let update = Task { @MainActor in
            try await embedded.updateOrder {
                started.fulfill()
                await gate.wait()
                return Self.sampleIntent("next")
            }
        }
        await fulfillment(of: [started], timeout: 1)

        try await embedded._controller.prepare(intent: bound, origin: .surface)
        XCTAssertTrue(embedded._controller.isUpdatingOrder)

        await gate.open()
        let next = try await update.value
        XCTAssertEqual(next, Self.sampleIntent("next"))
        XCTAssertEqual(embedded.boundIntent, next)
    }

    @MainActor
    func testProcessingEventsAreNotDroppedByASupersededUpdate() async {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let delivered = expectation(description: "processing delivered")
        delivered.expectedFulfillmentCount = 2
        let element = PaymentElement(payment: embedded) { event in
            if case .processing = event { delivered.fulfill() }
        }
        let started = expectation(description: "create order started")
        let update = Task { @MainActor in
            try await element.updateOrder {
                started.fulfill()
                try await Task.sleep(nanoseconds: 10_000_000_000)
                return Self.sampleIntent("never")
            }
        }
        await fulfillment(of: [started], timeout: 1)
        update.cancel()
        _ = try? await update.value

        embedded._controller.emit(.processing(true))
        embedded._controller.emit(.processing(false))
        await fulfillment(of: [delivered], timeout: 1)
    }

    @MainActor
    func testSwiftUIDoesNotRetryAFailedBindOnReRender() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let element = PaymentElement(payment: embedded)
        let coordinator = PaymentElementView.Coordinator()
        coordinator.element = element
        let intent = Self.sampleIntent("a")
        let key = PaymentElementView.key(for: intent)
        coordinator.lastOrderKey = key

        coordinator.handle(PaymentError.load("raw"), intent: intent, key: key)

        XCTAssertNil(coordinator.pendingIntent)
        XCTAssertEqual(coordinator.lastOrderKey, key)
    }

    @MainActor
    func testSwiftUIHostRetriesThePendingOrderAfterTheChargeEnds() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let bound = Self.sampleIntent("bound")
        let next = Self.sampleIntent("next")
        try embedded._controller.testingInstallBound(bound, state: Self.sampleState(), processing: true)
        embedded._controller.testingLoad = { _ in Self.sampleState() }

        let host = UIHostingController(rootView: PaymentElementView(payment: embedded, intent: next))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        try await Self.waitUntil { Self.findElement(in: host.view) != nil }
        await Task.yield()
        XCTAssertEqual(embedded.boundIntent, bound)

        try embedded._controller.testingInstallBound(bound, state: Self.sampleState(), processing: false)
        try await Self.waitUntil {
            embedded._controller.emit(.processing(false))
            return embedded.boundIntent == next
        }
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testLaterBindFailureDoesNotDeliverResult() async throws {
        var results = 0
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in
            results += 1
        }
        try embedded._controller.testingInstallBound(Self.sampleIntent("bound"), state: Self.sampleState())
        embedded._controller.testingFailNextBind(PaymentError.load("raw server response"))

        do {
            try await embedded.updateOrder(intent: Self.sampleIntent("next"))
            XCTFail("Expected bind to throw")
        } catch {
            XCTAssertTrue(error is PaymentError)
        }
        XCTAssertEqual(results, 0)
    }

    @MainActor
    func testSwiftUIRetriesThePendingIntent() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let element = PaymentElement(payment: embedded)
        let coordinator = PaymentElementView.Coordinator()
        coordinator.element = element
        let pending = Self.sampleIntent("pending")
        coordinator.pendingIntent = pending

        coordinator.retryPendingOrder()

        XCTAssertNil(coordinator.pendingIntent)
        XCTAssertEqual(
            coordinator.lastOrderKey,
            "\(pending.orderPayload):\(pending.orderChecksum)"
        )
        coordinator.prepareTask?.cancel()
    }

    func testEmbeddedContentInsetsAreZero() {
        let insets = PaymentFormView.ContentInsets.embedded
        XCTAssertEqual(insets.horizontal, 0)
        XCTAssertEqual(insets.top, 0)
        XCTAssertEqual(insets.bottom, 0)
        XCTAssertNotEqual(insets, .sheet)
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

    @MainActor
    private static func host(_ element: PaymentElement) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UIViewController()
        window.rootViewController = root
        element.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        root.view.addSubview(element)
        window.makeKeyAndVisible()
        root.view.layoutIfNeeded()
        return window
    }

    @MainActor
    private static func waitUntil(
        timeout: TimeInterval = 3,
        _ condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("Condition not met within \(timeout) seconds")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @MainActor
    private static func findElement(in view: UIView) -> PaymentElement? {
        if let element = view as? PaymentElement { return element }
        for subview in view.subviews {
            if let element = findElement(in: subview) { return element }
        }
        return nil
    }

    private static func sampleIntent(_ suffix: String) -> PaymentIntent {
        PaymentIntent(
            orderPayload: OrderPayload("payload-\(suffix)"),
            orderChecksum: OrderChecksum("checksum-\(suffix)")
        )
    }
}
