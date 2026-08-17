import Foundation
import XCTest
@testable import XMoneyCore

final class ThreeDSReconcileTests: XCTestCase {
    func testRequireTransactionIdReturnsId() throws {
        XCTAssertEqual(try requireTransactionIdForThreeDS("tx-1"), "tx-1")
    }

    func testRequireTransactionIdThrowsWhenMissing() {
        XCTAssertThrowsError(try requireTransactionIdForThreeDS(nil)) { error in
            let payment = error as? PaymentError
            XCTAssertEqual(payment?.code, "THREE_DS_ERROR")
            XCTAssertEqual(payment?.message, "Missing transaction id")
        }
    }

    func testResultFromTransactionMapsCompleteSuccess() {
        let tx = Transaction(id: "1", status: "complete-ok")
        let result = resultFromTransaction(tx)
        XCTAssertEqual(result.status, .complete)
        XCTAssertEqual(result.errorCode, nil)
    }

    func testResultFromTransactionMapsCompleteFail() {
        let tx = Transaction(id: nil, status: "complete-failed")
        let result = resultFromTransaction(tx)
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.errorCode, "PAYMENT_ERROR")
    }

    func testSoftCancelImmediateCompleteReturnsCompleteWithoutWaiting() async {
        let poll = Task<EngineResult, Error> {
            try await Task.sleep(nanoseconds: 10_000_000_000)
            return EngineResult(
                status: .complete,
                transaction: Transaction(id: nil, status: nil),
                errorCode: nil,
                errorMessage: nil
            )
        }
        let result = await reconcileCanceledThreeDS(
            fetchTransaction: {
                Transaction(id: "t1", status: "complete")
            },
            pollTask: poll,
            graceNanoseconds: 5_000_000_000
        )
        XCTAssertEqual(result.status, .complete)
        XCTAssertTrue(poll.isCancelled)
    }

    func testSoftCancelPendingThenGraceTimeoutReturnsCanceled() async {
        let poll = Task<EngineResult, Error> {
            try await Task.sleep(nanoseconds: 10_000_000_000)
            return EngineResult(
                status: .complete,
                transaction: Transaction(id: nil, status: nil),
                errorCode: nil,
                errorMessage: nil
            )
        }
        let started = Date()
        let result = await reconcileCanceledThreeDS(
            fetchTransaction: { Transaction(id: nil, status: "pending") },
            pollTask: poll,
            graceNanoseconds: 80_000_000
        )
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertEqual(result.status, .canceled)
        XCTAssertLessThan(elapsed, 2.0)
        XCTAssertTrue(poll.isCancelled)
    }

    func testSoftCancelPendingThenPollWinsWithinGrace() async {
        let complete = EngineResult(
            status: .complete,
            transaction: Transaction(id: nil, status: "complete"),
            errorCode: nil,
            errorMessage: nil
        )
        let poll = Task<EngineResult, Error> {
            try await Task.sleep(nanoseconds: 40_000_000)
            return complete
        }
        let result = await reconcileCanceledThreeDS(
            fetchTransaction: { Transaction(id: nil, status: "3d-pending") },
            pollTask: poll,
            graceNanoseconds: 2_000_000_000
        )
        XCTAssertEqual(result.status, .complete)
    }

    func testSoftCancelImmediateFetchFailsFallsThroughToGrace() async {
        let poll = Task<EngineResult, Error> {
            try await Task.sleep(nanoseconds: 30_000_000)
            return EngineResult(
                status: .failed,
                transaction: Transaction(id: nil, status: "complete-failed"),
                errorCode: "PAYMENT_ERROR",
                errorMessage: "Transaction complete-failed"
            )
        }
        let result = await reconcileCanceledThreeDS(
            fetchTransaction: { throw PaymentError.network("network") },
            pollTask: poll,
            graceNanoseconds: 2_000_000_000
        )
        XCTAssertEqual(result.status, .failed)
    }
}

final class CardHolderVerificationTests: XCTestCase {
    func testBuildValidationPayloadPadsExpiry() {
        let card = CardInput(number: "4111111111111111", expiryMonth: "3", expiryYear: "27", cvv: "123")
        let name = CardHolderName(firstName: "Ada", lastName: "Lovelace")
        let payload = AccountService.buildValidationPayload(
            card: card,
            name: name,
            currency: "EUR",
            transactionLocalDateTime: "2026-01-01T00:00:00.000Z"
        )
        let accountDetails = payload["accountDetails"] as? [String: Any]
        let account = accountDetails?["account"] as? [String: Any]
        XCTAssertEqual(account?["expiry"] as? String, "2027-03")
        XCTAssertEqual(payload["currency"] as? String, "EUR")
    }

    func testConfigPreservesVerificationCallback() {
        let verification = CardHolderVerification(
            name: CardHolderName(firstName: "Ada", middleName: "A", lastName: "Lovelace"),
            onCardHolderVerification: { $0.status == .matched }
        )
        XCTAssertEqual(verification.name.firstName, "Ada")
        XCTAssertEqual(verification.name.lastName, "Lovelace")
        XCTAssertTrue(
            verification.onCardHolderVerification(
                CardHolderVerificationResult(status: .matched)
            )
        )
    }

    func testParseVerificationResultMapsStatuses() {
        let result = CardHolderVerificationResult.fromApiMap([
            "status": "PartialMatched",
            "firstNameStatus": "Matched",
            "lastNameStatus": "NotMatched",
        ])
        XCTAssertEqual(result.status, .partialMatched)
        XCTAssertEqual(result.firstNameStatus, .matched)
        XCTAssertNil(result.middleNameStatus)
        XCTAssertEqual(result.lastNameStatus, .notMatched)
    }

    func testParseVerificationResultIsCaseSensitive() {
        let result = CardHolderVerificationResult.fromApiMap(["status": "MATCHED"])
        XCTAssertEqual(result.status, .notVerified)
    }

    func testParseVerificationResultDefaultsWhenMissing() {
        let result = CardHolderVerificationResult.fromApiMap(nil)
        XCTAssertEqual(result.status, .notVerified)
    }

    func testAccountValidationResponseParsesApiShape() {
        let map: [String: Any] = [
            "networkResponseCode": "00",
            "networkResponseCodeDescription": "Performed",
            "nameValidationResults": [
                "status": "Matched",
                "firstNameStatus": "Matched",
                "lastNameStatus": "Matched",
            ],
        ]
        let response = AccountValidationResponse(apiMap: map)
        XCTAssertEqual(response.networkResponseCode, "00")
        XCTAssertEqual(response.networkResponseCodeDescription, "Performed")
        XCTAssertEqual(response.nameValidationResults.status, .matched)
        XCTAssertEqual(response.nameValidationResults.firstNameStatus, .matched)
        XCTAssertEqual(response.nameValidationResults.lastNameStatus, .matched)
        XCTAssertNil(response.nameValidationResults.middleNameStatus)
    }

    func testErrorMappingApplePayAndCardHolder() {
        XCTAssertEqual(PaymentError.from(code: "APPLE_PAY", message: "x").code, "APPLE_PAY")
        XCTAssertEqual(
            PaymentError.from(code: "CARD_HOLDER_VERIFICATION", message: "x").code,
            "CARD_HOLDER_VERIFICATION"
        )
        if case .applePay = PaymentError.from(code: "APPLE_PAY", message: "x") {
        } else {
            XCTFail("expected applePay")
        }
    }
}
