import Foundation
import XCTest
@testable import XMoneyCore

final class OrderConsumptionTests: XCTestCase {
    func testConsumeMatrix() {
        XCTAssertTrue(OrderConsumption.shouldConsume(status: .complete, didAuthorize: false))
        XCTAssertTrue(OrderConsumption.shouldConsume(status: .complete, didAuthorize: true))
        XCTAssertTrue(OrderConsumption.shouldConsume(status: .failed, didAuthorize: false))
        XCTAssertTrue(OrderConsumption.shouldConsume(status: .failed, didAuthorize: true))
        XCTAssertFalse(OrderConsumption.shouldConsume(status: .canceled, didAuthorize: false))
        XCTAssertTrue(OrderConsumption.shouldConsume(status: .canceled, didAuthorize: true))
    }

    func testMerchantResultComplete() {
        let tx = Transaction(id: "tx-1", status: "complete")
        let result = EngineResult(
            status: .complete,
            transaction: tx,
            errorCode: nil,
            errorMessage: nil
        )
        switch OrderConsumption.merchantResult(result) {
        case .complete(let mapped):
            XCTAssertEqual(mapped.id, "tx-1")
        case .failed, .canceled:
            XCTFail("expected complete")
        }
    }

    func testMerchantResultMissingTransaction() {
        let result = EngineResult(
            status: .complete,
            transaction: nil,
            errorCode: nil,
            errorMessage: nil
        )
        switch OrderConsumption.merchantResult(result) {
        case .failed(let error):
            XCTAssertEqual(error.code, "PAYMENT_ERROR")
            XCTAssertEqual(error.message, "Missing transaction")
        case .complete, .canceled:
            XCTFail("expected failed")
        }
    }

    func testMerchantResultFailedIsSanitized() {
        let result = EngineResult(
            status: .failed,
            transaction: nil,
            errorCode: "PAYMENT_ERROR",
            errorMessage: "gateway dump"
        )
        switch OrderConsumption.merchantResult(result) {
        case .failed(let error):
            XCTAssertEqual(error.message, PaymentError.genericPayment)
        case .complete, .canceled:
            XCTFail("expected failed")
        }
    }

    func testMerchantResultCanceled() {
        let result = EngineResult(
            status: .canceled,
            transaction: nil,
            errorCode: nil,
            errorMessage: nil
        )
        switch OrderConsumption.merchantResult(result) {
        case .canceled:
            break
        case .complete, .failed:
            XCTFail("expected canceled")
        }
    }

    func testMerchantResultFailedCanceledCodeMapsToCanceled() {
        let result = EngineResult(
            status: .failed,
            transaction: nil,
            errorCode: "CANCELED",
            errorMessage: "Payment canceled"
        )
        switch OrderConsumption.merchantResult(result) {
        case .canceled:
            break
        case .complete, .failed:
            XCTFail("expected canceled")
        }
    }
}
