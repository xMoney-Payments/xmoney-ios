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

        XCTAssertTrue(element.isLoaderVisible)
        element.revealIfNeeded()
        element.revealIfNeeded()

        XCTAssertFalse(element.isLoaderVisible)
        XCTAssertEqual(readyCount, 1)
    }

    @MainActor
    func testFailureStateReplacesLoaderAndUsesMerchantSafeMessage() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }

        element.showFailure(PaymentError.load("raw server response"))
        element.revealIfNeeded()

        XCTAssertFalse(element.isLoaderVisible)
        XCTAssertTrue(element.isFailureVisible)
        XCTAssertEqual(element.failureMessage, PaymentError.genericLoad)
        XCTAssertEqual(readyCount, 1)
    }

    @MainActor
    func testReadyIsScopedToEachMountedElement() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        var readyCount = 0

        PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }.revealIfNeeded()
        PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }.revealIfNeeded()

        XCTAssertEqual(readyCount, 2)
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
    func testSupersededFailureDoesNotRevealNewerUpdate() async {
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

        let first = Task { @MainActor in
            try await element.updateOrder {
                throw EmbeddedOrderError.failed
            }
        }
        try? await Task.sleep(nanoseconds: 50_000_000)

        let started = expectation(description: "second update started")
        let gate = EmbeddedOrderGate()
        let second = Task { @MainActor in
            try await element.updateOrder {
                started.fulfill()
                await gate.wait()
                throw EmbeddedOrderError.failed
            }
        }
        await fulfillment(of: [started], timeout: 1)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UIViewController()
        window.rootViewController = root
        root.view.addSubview(element)
        window.makeKeyAndVisible()
        root.view.layoutIfNeeded()
        element.layoutIfNeeded()
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertTrue(element.isLoaderVisible)
        XCTAssertEqual(readyCount, 0)

        await gate.open()
        do {
            try await second.value
            XCTFail("Expected second update to throw")
        } catch {
            XCTAssertTrue(error is EmbeddedOrderError)
        }
        do {
            try await first.value
            XCTFail("Expected first update to throw")
        } catch {
            XCTAssertTrue(error is EmbeddedOrderError)
        }

        XCTAssertFalse(element.isLoaderVisible)
        XCTAssertEqual(readyCount, 1)
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
        XCTAssertEqual(element.failureMessage, "Invalid public key")
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
    func testSameIntentDoesNotCancelInFlightCreation() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let bound = Self.sampleIntent("bound")
        try embedded._controller.testingInstallBound(bound, state: Self.sampleState())
        let started = expectation(description: "create order started")
        let first = Task { @MainActor in
            try await embedded.updateOrder {
                started.fulfill()
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return bound
            }
        }
        await fulfillment(of: [started], timeout: 1)
        try await embedded.updateOrder(intent: bound)
        XCTAssertFalse(first.isCancelled)
        first.cancel()
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

    private static func sampleIntent(_ suffix: String) -> PaymentIntent {
        PaymentIntent(
            orderPayload: OrderPayload("payload-\(suffix)"),
            orderChecksum: OrderChecksum("checksum-\(suffix)")
        )
    }
}
