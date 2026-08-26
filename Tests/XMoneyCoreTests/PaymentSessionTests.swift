import Foundation
import XCTest
@testable import XMoneyCore

private final class SlowWallet: DigitalWalletAuthorizing {
    var didAuthorizePayment = false
    func start() async -> EngineResult {
        try? await Task.sleep(nanoseconds: 300_000_000)
        return EngineResult(status: .canceled, transaction: nil, errorCode: nil, errorMessage: nil)
    }
}

private final class ImmediateWallet: DigitalWalletAuthorizing {
    var didAuthorizePayment: Bool
    var status: EngineResult.Status

    init(didAuthorize: Bool, status: EngineResult.Status) {
        self.didAuthorizePayment = didAuthorize
        self.status = status
    }

    func start() async -> EngineResult {
        EngineResult(status: status, transaction: nil, errorCode: nil, errorMessage: nil)
    }
}

@MainActor
final class PaymentSessionTests: XCTestCase {
    override func setUp() {
        super.setUp()
        DigitalWalletFactory.canMakePayments = { false }
        DigitalWalletFactory.makeApplePay = nil
    }

    override func tearDown() {
        DigitalWalletFactory.canMakePayments = { false }
        DigitalWalletFactory.makeApplePay = nil
        super.tearDown()
    }

    func testSameOrderBindDoesNotDropSessionToken() async throws {
        let sessionTokenCalls = TokenCallCounter()
        let session = try makeSession(applePayEnabled: false) { request in
            StubHTTP.jsonResponse(for: request, sessionTokenCalls: sessionTokenCalls)
        }
        let first = try await session.bind(intent: session.intent)
        XCTAssertEqual(first.sessionToken, "sess-1")
        XCTAssertEqual(sessionTokenCalls.value, 1)

        let second = try await session.bind(intent: session.intent)
        XCTAssertEqual(second.sessionToken, "sess-1")
        XCTAssertEqual(sessionTokenCalls.value, 1)
    }

    func testApplePayAvailableOnlyAfterSuccessfulParams() async throws {
        DigitalWalletFactory.canMakePayments = { true }
        let session = try makeSession(applePayEnabled: true) { request in
            StubHTTP.okJSON(for: request, wallet: ["merchantId": ""])
        }
        let state = try await session.bind(intent: session.intent)
        XCTAssertFalse(state.applePayAvailable)
    }

    func testApplePayAvailableWhenParamsIncludeMerchantId() async throws {
        DigitalWalletFactory.canMakePayments = { true }
        let session = try makeSession(applePayEnabled: true) { request in
            StubHTTP.okJSON(for: request, wallet: ["merchantId": "merchant.com.xmoney"])
        }
        let state = try await session.bind(intent: session.intent)
        XCTAssertTrue(state.applePayAvailable)
    }

    func testPreAuthorizeCancelDoesNotConsume() async throws {
        let session = try makeSession(applePayEnabled: false) { request in
            StubHTTP.jsonResponse(for: request, sessionTokenCalls: TokenCallCounter())
        }
        _ = try await session.bind(intent: session.intent)
        let result = await session.startWallet(ImmediateWallet(didAuthorize: false, status: .canceled))
        XCTAssertEqual(result.status, .canceled)
        XCTAssertFalse(session.isOrderConsumed)
        XCTAssertTrue(session.isInteractionEnabled)
    }

    func testPostSubmitCancelConsumes() async throws {
        let session = try makeSession(applePayEnabled: false) { request in
            StubHTTP.jsonResponse(for: request, sessionTokenCalls: TokenCallCounter())
        }
        _ = try await session.bind(intent: session.intent)
        _ = await session.startWallet(ImmediateWallet(didAuthorize: true, status: .canceled))
        XCTAssertTrue(session.isOrderConsumed)
        XCTAssertFalse(session.isInteractionEnabled)
    }

    func testCompleteConsumes() async throws {
        let session = try makeSession(applePayEnabled: false) { request in
            StubHTTP.jsonResponse(for: request, sessionTokenCalls: TokenCallCounter())
        }
        _ = try await session.bind(intent: session.intent)
        _ = await session.startWallet(ImmediateWallet(didAuthorize: true, status: .complete))
        XCTAssertTrue(session.isOrderConsumed)
    }

    func testLoadFailureDoesNotConsume() async throws {
        let session = try makeSession(applePayEnabled: false) { _ in
            throw URLError(.notConnectedToInternet)
        }
        do {
            _ = try await session.bind(intent: session.intent)
            XCTFail("expected bind to throw")
        } catch {
            XCTAssertFalse(session.isOrderConsumed)
        }
    }

    func testSubmitWhileProcessingIsNoOp() async throws {
        let session = try makeSession(applePayEnabled: false) { request in
            StubHTTP.jsonResponse(for: request, sessionTokenCalls: TokenCallCounter())
        }
        _ = try await session.bind(intent: session.intent)

        async let first = session.startWallet(SlowWallet())
        try await Task.sleep(nanoseconds: 50_000_000)
        let second = await session.startWallet(ImmediateWallet(didAuthorize: true, status: .complete))
        XCTAssertEqual(second.status, .canceled)
        XCTAssertFalse(session.isOrderConsumed)
        _ = await first
        XCTAssertFalse(session.isOrderConsumed)
    }

    func testFailedBindDoesNotCommitPreviousState() async throws {
        let sessionTokenCalls = TokenCallCounter()
        let session = try makeSession(applePayEnabled: false) { request in
            let path = request.url?.path ?? ""
            if path.contains("session-token") {
                let count = sessionTokenCalls.increment()
                if count == 1 {
                    return (200, StubHTTP.json(["token": "sess-1"]))
                }
                return (500, StubHTTP.json(["error": "fail"]))
            }
            if path.contains("config") {
                return (200, StubHTTP.json([:]))
            }
            if path.contains("cards") {
                return (200, StubHTTP.json(["data": []]))
            }
            return (200, StubHTTP.json([:]))
        }
        let first = try await session.bind(intent: session.intent)
        XCTAssertEqual(first.sessionToken, "sess-1")

        let intentB = PaymentIntent(
            orderPayload: OrderPayload("eyJ4IjoxfQ=="),
            orderChecksum: OrderChecksum("cs-b")
        )
        do {
            _ = try await session.bind(intent: intentB)
            XCTFail("expected bind of order B to fail")
        } catch {
            XCTAssertEqual(session.state?.sessionToken, "sess-1")
        }

        let callsBeforeRetry = sessionTokenCalls.value
        do {
            _ = try await session.bind(intent: intentB)
            XCTFail("expected retry of order B to hit the network")
        } catch {
            XCTAssertGreaterThan(sessionTokenCalls.value, callsBeforeRetry)
            XCTAssertEqual(session.state?.sessionToken, "sess-1")
        }
    }

    func testCanDismissIsFalseWhileProcessing() async throws {
        let session = try makeSession(applePayEnabled: false) { request in
            StubHTTP.jsonResponse(for: request, sessionTokenCalls: TokenCallCounter())
        }
        _ = try await session.bind(intent: session.intent)
        XCTAssertTrue(session.canDismiss)

        async let first = session.startWallet(SlowWallet())
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertFalse(session.canDismiss)
        _ = await first
        XCTAssertTrue(session.canDismiss)
    }

    func testCancelledBindDoesNotCommit() async throws {
        let session = try makeSession(applePayEnabled: false) { request in
            let path = request.url?.path ?? ""
            if path.contains("session-token") {
                try await Task.sleep(nanoseconds: 400_000_000)
                return (200, StubHTTP.json(["token": "sess-1"]))
            }
            return (200, StubHTTP.json([:]))
        }
        let task = Task {
            try await session.bind(intent: session.intent)
        }
        try await Task.sleep(nanoseconds: 40_000_000)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("cancelled bind should throw")
        } catch is CancellationError {
            // expected
        } catch {
            // URLSession may surface a transport error instead of CancellationError
        }
        XCTAssertNil(session.state)
    }

    func testApplePayParamsWaitWithoutTimeout() async throws {
        DigitalWalletFactory.canMakePayments = { true }
        let session = try makeSession(applePayEnabled: true) { request in
            let path = request.url?.path ?? ""
            if path.contains("session-token") {
                return (200, StubHTTP.json(["token": "sess-1"]))
            }
            if path.contains("config") {
                return (200, StubHTTP.json([:]))
            }
            if path.contains("digital-wallet") {
                try await Task.sleep(nanoseconds: 200_000_000)
                return (200, StubHTTP.json(["merchantId": "merchant.com.xmoney"]))
            }
            return (200, StubHTTP.json([:]))
        }
        let state = try await session.bind(intent: session.intent)
        XCTAssertTrue(state.applePayAvailable)
    }

    func testDeleteSavedCardNon2xxThrows() async throws {
        let session = try makeSession(applePayEnabled: false) { request in
            let path = request.url?.path ?? ""
            if path.contains("session-token") {
                return (200, StubHTTP.json(["token": "sess-1"]))
            }
            if request.httpMethod == "DELETE" {
                return (404, StubHTTP.json(["message": "not found"]))
            }
            return (200, StubHTTP.json([:]))
        }
        _ = try await session.bind(intent: session.intent)
        do {
            _ = try await session.deleteSavedCard(cardId: "card-1")
            XCTFail("expected network error")
        } catch let error as PaymentError {
            XCTAssertEqual(error.code, "NETWORK_ERROR")
        }
        XCTAssertEqual(session.state?.savedCards ?? [], [])
    }

    func testDeleteSavedCardRefreshesRemaining() async throws {
        let session = try makeSession(applePayEnabled: false, savedCardsEnabled: true) { request in
            let path = request.url?.path ?? ""
            if path.contains("session-token") {
                return (200, StubHTTP.json(["token": "sess-1"]))
            }
            if request.httpMethod == "DELETE" {
                return (200, StubHTTP.json([:]))
            }
            if path.contains("cards") {
                return (200, StubHTTP.json([
                    "data": [[
                        "id": "card-2",
                        "cardNumber": "•••• 5599",
                        "cardType": "mastercard",
                        "cardExpiryDate": "12/34",
                    ]],
                ]))
            }
            return (200, StubHTTP.json([:]))
        }
        _ = try await session.bind(intent: session.intent)
        let updated = try await session.deleteSavedCard(cardId: "card-1")
        XCTAssertEqual(updated.savedCards.map(\.id), ["card-2"])
        XCTAssertEqual(session.state?.savedCards.map(\.id), ["card-2"])
    }

    private func makeSession(
        applePayEnabled: Bool,
        savedCardsEnabled: Bool = false,
        handler: @escaping @Sendable (URLRequest) async throws -> (Int, Data)
    ) throws -> PaymentSession {
        let http = HTTPClient(execute: { @Sendable request in
            let (status, data) = try await handler(request)
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://invalid.local")!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (data, response)
        })
        var paymentConfig = PaymentConfig(publicKey: "pk_test_stub")
        paymentConfig.paymentMethods.applePay.enabled = applePayEnabled
        paymentConfig.card.savedCards.enabled = savedCardsEnabled
        let intent = PaymentIntent(
            orderPayload: OrderPayload("e30="),
            orderChecksum: OrderChecksum("cs")
        )
        return try PaymentSession(configuration: paymentConfig, intent: intent, http: http)
    }
}

private enum StubHTTP {
    static func okJSON(for request: URLRequest, wallet: [String: String]) -> (Int, Data) {
        let path = request.url?.path ?? ""
        if path.contains("session-token") {
            return (200, json(["token": "sess-1"]))
        }
        if path.contains("config") {
            return (200, json([:]))
        }
        if path.contains("digital-wallet") {
            return (200, json(wallet))
        }
        return (200, json([:]))
    }

    static func jsonResponse(
        for request: URLRequest,
        sessionTokenCalls: TokenCallCounter
    ) -> (Int, Data) {
        let path = request.url?.path ?? ""
        if path.contains("session-token") {
            let count = sessionTokenCalls.increment()
            return (200, json(["token": "sess-\(count)"]))
        }
        if path.contains("config") {
            return (200, json([:]))
        }
        if path.contains("cards") {
            return (200, json(["data": []]))
        }
        return (200, json([:]))
    }

    static func json(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
    }
}

private final class TokenCallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    @discardableResult
    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        _value += 1
        return _value
    }
}
