import Foundation
import XCTest
@testable import XMoneyCore

final class TransactionPollTests: XCTestCase {
    func testRetriesAfterConnectionLostDuringBankHandoff() async throws {
        let calls = CallCounter()
        let service = makeService { _ in
            if calls.increment() == 1 { throw URLError(.networkConnectionLost) }
            return (200, ["status": "complete-ok"])
        }
        let tx = try await service.poll(transactionId: "tx-1", sessionToken: "s", interval: 0.01, timeout: 5)
        XCTAssertEqual(tx.status, "complete-ok")
        XCTAssertEqual(calls.value, 2)
    }

    func testRetriesServerErrorsAndRateLimits() async throws {
        let calls = CallCounter()
        let service = makeService { _ in
            switch calls.increment() {
            case 1: return (503, [:])
            case 2: return (429, [:])
            default: return (200, ["status": "complete-ok"])
            }
        }
        let tx = try await service.poll(transactionId: "tx-1", sessionToken: "s", interval: 0.01, timeout: 5)
        XCTAssertEqual(tx.status, "complete-ok")
        XCTAssertEqual(calls.value, 3)
    }

    func testClientErrorIsNotRetriedButIsCheckedOnceMore() async {
        let calls = CallCounter()
        let service = makeService { _ in
            calls.increment()
            return (404, ["message": "Not found"])
        }
        do {
            _ = try await service.poll(transactionId: "tx-1", sessionToken: "s", interval: 0.01, timeout: 5)
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? PaymentError, .network("Not found"))
        }
        XCTAssertEqual(calls.value, 2)
    }

    func testClientErrorReturnsTransactionCompletedOnFinalCheck() async throws {
        let calls = CallCounter()
        let service = makeService { _ in
            if calls.increment() == 1 { return (401, [:]) }
            return (200, ["status": "complete-ok"])
        }
        let tx = try await service.poll(transactionId: "tx-1", sessionToken: "s", interval: 0.01, timeout: 5)
        XCTAssertEqual(tx.status, "complete-ok")
    }

    func testTimeoutReturnsTransactionCompletedOnFinalCheck() async throws {
        let service = makeService { _ in (200, ["status": "complete-ok"]) }
        let tx = try await service.poll(transactionId: "tx-1", sessionToken: "s", interval: 0.01, timeout: 0)
        XCTAssertEqual(tx.status, "complete-ok")
    }

    func testTimeoutStillThrowsWhenTransactionIsPending() async {
        let service = makeService { _ in (200, ["status": "3d-pending"]) }
        do {
            _ = try await service.poll(transactionId: "tx-1", sessionToken: "s", interval: 0.01, timeout: 0.05)
            XCTFail("expected a timeout")
        } catch {
            XCTAssertEqual((error as? PaymentError)?.code, "POLL_TIMEOUT")
        }
    }

    func testClientErrorIsSurfacedWhenFinalCheckLosesConnection() async {
        let calls = CallCounter()
        let service = makeService { _ in
            if calls.increment() == 1 { return (404, ["message": "Not found"]) }
            throw URLError(.networkConnectionLost)
        }
        do {
            _ = try await service.poll(transactionId: "tx-1", sessionToken: "s", interval: 0.01, timeout: 5)
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? PaymentError, .network("Not found"))
        }
        XCTAssertEqual(calls.value, 2)
    }

    func testTimeoutIsSurfacedWhenFinalCheckLosesConnection() async {
        let service = makeService { _ in throw URLError(.networkConnectionLost) }
        do {
            _ = try await service.poll(transactionId: "tx-1", sessionToken: "s", interval: 0.01, timeout: 0)
            XCTFail("expected a timeout")
        } catch {
            XCTAssertEqual((error as? PaymentError)?.code, "POLL_TIMEOUT")
        }
    }

    func testGetTransactionStillThrowsPaymentError() async {
        let service = makeService { _ in (500, ["message": "boom"]) }
        do {
            _ = try await service.getTransaction(id: "tx-1", sessionToken: "s")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? PaymentError, .network("boom"))
        }
    }

    func testRetriesConnectionAbortAfterReturningFromBackground() async throws {
        let calls = CallCounter()
        let service = makeService { _ in
            if calls.increment() == 1 { throw NSError(domain: NSPOSIXErrorDomain, code: 53) }
            return (200, ["status": "complete-ok"])
        }
        let tx = try await service.poll(transactionId: "tx-1", sessionToken: "s", interval: 0.01, timeout: 5)
        XCTAssertEqual(tx.status, "complete-ok")
        XCTAssertEqual(calls.value, 2)
    }

    func testTransientClassification() {
        XCTAssertTrue(TransactionService.isTransient(URLError(.networkConnectionLost)))
        XCTAssertTrue(TransactionService.isTransient(URLError(.notConnectedToInternet)))
        XCTAssertTrue(TransactionService.isTransient(URLError(.secureConnectionFailed)))
        XCTAssertTrue(TransactionService.isTransient(NSError(domain: NSPOSIXErrorDomain, code: 53)))
        XCTAssertTrue(TransactionService.isTransient(PaymentError.network("x")))
        XCTAssertFalse(TransactionService.isTransient(URLError(.badURL)))
        XCTAssertTrue(TransactionService.isTransient(HTTPStatusFailure(statusCode: 502, error: .network("x"))))
        XCTAssertTrue(TransactionService.isTransient(HTTPStatusFailure(statusCode: 408, error: .network("x"))))
        XCTAssertTrue(TransactionService.isTransient(HTTPStatusFailure(statusCode: 429, error: .network("x"))))
        XCTAssertFalse(TransactionService.isTransient(HTTPStatusFailure(statusCode: 401, error: .network("x"))))
        XCTAssertFalse(TransactionService.isTransient(HTTPStatusFailure(statusCode: 403, error: .network("x"))))
        XCTAssertFalse(TransactionService.isTransient(HTTPStatusFailure(statusCode: 404, error: .network("x"))))
    }

    private func makeService(
        handler: @escaping @Sendable (URLRequest) throws -> (Int, [String: Any])
    ) -> TransactionService {
        let http = HTTPClient(execute: { @Sendable request in
            let (status, body) = try handler(request)
            let data = try JSONSerialization.data(withJSONObject: body)
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://invalid.local")!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (data, response)
        })
        return TransactionService(http: http, env: PaymentEnvironment(publicKey: "pk_test_stub")!)
    }
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    @discardableResult
    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }
}
