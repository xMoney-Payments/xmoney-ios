import Foundation
import XCTest
@testable import XMoneyCore

final class PaymentErrorMerchantMessageTests: XCTestCase {
    func testNetworkAlwaysUsesGenericMessage() {
        let error = PaymentError.network("secret server dump")
        XCTAssertEqual(error.merchantMessage(), PaymentError.genericNetwork)
        XCTAssertEqual(EngineResult.failed(error).errorMessage, PaymentError.genericNetwork)
        XCTAssertEqual(error.message, "secret server dump")
    }

    func testUnknownServerCodeIsSanitized() {
        let error = PaymentError.unknown(code: "E_INTERNAL", message: "stack trace from edge")
        XCTAssertEqual(error.merchantMessage(), PaymentError.genericRequest)
        XCTAssertEqual(error.message, "stack trace from edge")
    }

    func testSdkAuthoredMessagesPassThrough() {
        let error = PaymentError.session("Missing session token")
        XCTAssertEqual(error.merchantMessage(), "Missing session token")
    }

    func testPaymentSanitizesNonAuthoredCopy() {
        let error = PaymentError.payment("gateway dump")
        XCTAssertEqual(error.merchantMessage(), PaymentError.genericPayment)
        XCTAssertEqual(EngineResult.failed(error).errorMessage, PaymentError.genericPayment)
    }

    func testLoadSanitizesNonAuthoredCopy() {
        let error = PaymentError.load("internal stack")
        XCTAssertEqual(error.merchantMessage(), PaymentError.genericLoad)
    }

    func testApplePaySanitizesNonAuthoredCopy() {
        let error = PaymentError.applePay("PassKit internals")
        XCTAssertEqual(error.merchantMessage(), PaymentError.genericApplePay)
    }

    func testApplePayAuthoredMessagesPassThrough() {
        let missingId = PaymentError.applePay("Missing Apple Pay merchant ID from wallet params.")
        XCTAssertEqual(missingId.merchantMessage(), "Missing Apple Pay merchant ID from wallet params.")

        let missingAmount = PaymentError.applePay(PaymentError.missingApplePayAmountOrCurrency)
        XCTAssertEqual(missingAmount.merchantMessage(), PaymentError.missingApplePayAmountOrCurrency)

        let unavailable = PaymentError.applePay(
            "Apple Pay is not available on this device. Add the Apple Pay capability."
        )
        XCTAssertEqual(unavailable.merchantMessage(), unavailable.message)
    }

    func testTransactionPrefixPassesThrough() {
        let error = PaymentError.payment("Transaction abc-123 failed")
        XCTAssertEqual(error.merchantMessage(), "Transaction abc-123 failed")
    }

    func testMerchantFacingReplacesMessage() {
        let error = PaymentError.network("secret server dump").merchantFacing()
        XCTAssertEqual(error.code, "NETWORK_ERROR")
        XCTAssertEqual(error.message, PaymentError.genericNetwork)
    }
}
