import XCTest
@testable import XMoneyPaymentElement
import XMoneyCore

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
    func testRevealWhileLoaderVisibleHidesCoverAndEmitsReadyOnce() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        guard let loaderHost = element.subviews.first else {
            return XCTFail("Expected loader host")
        }

        XCTAssertFalse(loaderHost.isHidden)
        element.revealIfNeeded()
        element.revealIfNeeded()

        XCTAssertTrue(loaderHost.isHidden)
        XCTAssertEqual(readyCount, 1)
    }

    func testEmbeddedContentInsetsAreZero() {
        let insets = PaymentFormView.ContentInsets.embedded
        XCTAssertEqual(insets.horizontal, 0)
        XCTAssertEqual(insets.top, 0)
        XCTAssertEqual(insets.bottom, 0)
        XCTAssertNotEqual(insets, .sheet)
    }
}
