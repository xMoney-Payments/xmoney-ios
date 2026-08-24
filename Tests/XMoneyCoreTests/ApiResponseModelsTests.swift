import Foundation
import XCTest
@testable import XMoneyCore

final class ApiResponseModelsTests: XCTestCase {
    func testSessionTokenResponseParsesToken() {
        let response = SessionTokenResponse(apiMap: ["token": "abc-123"])
        XCTAssertEqual(response.token, "abc-123")
    }

    func testSiteConfigParsesFlags() {
        let config = SiteConfig(apiMap: [
            "whitelabelPaymentForm": false,
            "checkNameWithoutSaveCard": true,
            "nameCheckValidationEnabled": true,
        ])
        XCTAssertFalse(config.whitelabelPaymentForm)
        XCTAssertTrue(config.checkNameWithoutSaveCard)
        XCTAssertTrue(config.nameCheckValidationEnabled)
    }

    func testSavedCardsResponseParsesApiShape() {
        let map: [String: Any] = [
            "data": [
                [
                    "id": 141973,
                    "customerId": 62833,
                    "type": "mastercard",
                    "cardNumber": "555555******5599",
                    "expiryMonth": "12",
                    "expiryYear": "2034",
                    "nameOnCard": "Minas Kitsos",
                    "cardHolderCountry": "RO",
                    "bankName": "ING",
                ],
                [
                    "id": 143072,
                    "customerId": 62833,
                    "type": "visa",
                    "cardNumber": "411111******1111",
                    "expiryMonth": "12",
                    "expiryYear": "2028",
                    "nameOnCard": "TestCata",
                    "cardHolderCountry": NSNull(),
                    "bankName": "",
                ],
            ],
        ]
        let cards = SavedCardsResponse(apiMap: map).data
        XCTAssertEqual(cards.count, 2)

        let first = cards[0]
        XCTAssertEqual(first.id, "141973")
        XCTAssertEqual(first.customerId, "62833")
        XCTAssertEqual(first.cardType, "mastercard")
        XCTAssertEqual(first.cardBrand, "mastercard")
        XCTAssertEqual(first.cardNumber, "555555******5599")
        XCTAssertEqual(first.cardExpiryDate, "12/34")
        XCTAssertEqual(first.nameOnCard, "Minas Kitsos")
        XCTAssertEqual(first.cardHolderCountry, "RO")
        XCTAssertEqual(first.bankName, "ING")

        let second = cards[1]
        XCTAssertEqual(second.id, "143072")
        XCTAssertEqual(second.cardBrand, "visa")
        XCTAssertEqual(second.cardExpiryDate, "12/28")
        XCTAssertNil(second.cardHolderCountry)
        XCTAssertNil(second.bankName)
    }

    func testWalletParamsParsesAllowedCardNetworks() {
        let params = WalletParams(apiMap: [
            "allowedCardNetworks": ["MASTERCARD", "VISA"],
            "gateway": "xmoneypay",
            "gatewayMerchantId": "googlePay_10722",
            "merchantName": "TestxMoney",
            "merchantCountry": "RO",
            "merchantId": "googlePay_10722",
            "merchantOrigin": "",
        ])
        XCTAssertEqual(params.gateway, "xmoneypay")
        XCTAssertEqual(params.gatewayMerchantId, "googlePay_10722")
        XCTAssertEqual(params.merchantId, "googlePay_10722")
        XCTAssertEqual(params.merchantName, "TestxMoney")
        XCTAssertEqual(params.merchantCountry, "RO")
        XCTAssertNil(params.merchantOrigin)
        XCTAssertEqual(params.supportedNetworks, ["MASTERCARD", "VISA"])
    }

    func testTransactionParsesFullApiShape() {
        let map: [String: Any] = [
            "id": 726549,
            "transactionStatus": "complete-ok",
            "amount": "100.0000",
            "currencyKey": "EUR",
            "amountInEuro": "100.0000",
            "customerData": [
                "id": 62833,
                "siteId": 10722,
                "identifier": "customer-12333",
                "firstName": "John",
                "lastName": "Doe",
                "country": "RO",
                "state": "",
                "city": "Bucharest",
                "zipCode": "",
                "address": "",
                "phone": "",
                "email": "john.doe@test.com",
                "isWhitelisted": 0,
                "isWhitelistedUntil": NSNull(),
                "creationDate": "2025-12-14T16:40:00+00:00",
                "creationTimestamp": 1_765_730_400,
            ],
            "externalOrderId": "order-1786545845128",
            "description": "Embeddable Configuration - Payment Card",
        ]
        let tx = Transaction(apiMap: map)
        XCTAssertEqual(tx.id, "726549")
        XCTAssertEqual(tx.status, "complete-ok")
        XCTAssertEqual(tx.amount, "100.0000")
        XCTAssertEqual(tx.currencyKey, "EUR")
        XCTAssertEqual(tx.amountInEuro, "100.0000")
        XCTAssertEqual(tx.externalOrderId, "order-1786545845128")
        XCTAssertEqual(tx.description, "Embeddable Configuration - Payment Card")
        XCTAssertTrue(tx.isComplete)
        XCTAssertTrue(tx.isSuccessfulComplete)

        let customer = tx.customerData
        XCTAssertEqual(customer?.id, "62833")
        XCTAssertEqual(customer?.siteId, "10722")
        XCTAssertEqual(customer?.identifier, "customer-12333")
        XCTAssertEqual(customer?.firstName, "John")
        XCTAssertEqual(customer?.lastName, "Doe")
        XCTAssertEqual(customer?.country, "RO")
        XCTAssertNil(customer?.state)
        XCTAssertEqual(customer?.city, "Bucharest")
        XCTAssertEqual(customer?.email, "john.doe@test.com")
        XCTAssertEqual(customer?.isWhitelisted, false)
        XCTAssertNil(customer?.isWhitelistedUntil)
        XCTAssertEqual(customer?.creationDate, "2025-12-14T16:40:00+00:00")
        XCTAssertEqual(customer?.creationTimestamp, 1_765_730_400)
    }

    func testOrderInputParsesDecodedPayload() {
        let map: [String: Any] = [
            "publicKey": "pk_test_123",
            "cardTransactionMode": "authAndCapture",
            "invoiceEmail": "merchant@test.com",
            "saveCard": true,
            "cardId": 141973,
            "backUrl": "https://merchant.example/return",
            "customData": "{\"foo\":1}",
            "customer": [
                "identifier": "customer-12333",
                "firstName": "John",
                "lastName": "Doe",
                "country": "RO",
                "city": "Bucharest",
                "phone": "",
                "email": "john.doe@test.com",
                "tags": ["vip", "test"],
            ],
            "order": [
                "orderId": "order-1786545845128",
                "type": "purchase",
                "amount": 100,
                "currency": "EUR",
                "description": "Embeddable Configuration - Payment Card",
                "intervalType": "month",
                "intervalValue": "1",
                "retryPayment": "true",
                "trialAmount": 0,
                "firstBillDate": "2026-09-01",
            ],
        ]
        let input = OrderInput(apiMap: map)
        XCTAssertEqual(input.publicKey, "pk_test_123")
        XCTAssertEqual(input.cardTransactionMode, "authAndCapture")
        XCTAssertEqual(input.invoiceEmail, "merchant@test.com")
        XCTAssertTrue(input.saveCard)
        XCTAssertEqual(input.cardId, "141973")
        XCTAssertEqual(input.backUrl, "https://merchant.example/return")
        XCTAssertEqual(input.customData, "{\"foo\":1}")

        let customer = input.customer
        XCTAssertEqual(customer?.identifier, "customer-12333")
        XCTAssertEqual(customer?.firstName, "John")
        XCTAssertEqual(customer?.lastName, "Doe")
        XCTAssertEqual(customer?.country, "RO")
        XCTAssertEqual(customer?.city, "Bucharest")
        XCTAssertNil(customer?.phone)
        XCTAssertEqual(customer?.email, "john.doe@test.com")
        XCTAssertEqual(customer?.tags, ["vip", "test"])

        let order = input.order
        XCTAssertEqual(order?.orderId, "order-1786545845128")
        XCTAssertEqual(order?.type, "purchase")
        XCTAssertEqual(order?.amount, 100.0)
        XCTAssertEqual(order?.currency, "EUR")
        XCTAssertEqual(order?.description, "Embeddable Configuration - Payment Card")
        XCTAssertEqual(order?.intervalType, "month")
        XCTAssertEqual(order?.intervalValue, "1")
        XCTAssertEqual(order?.retryPayment, "true")
        XCTAssertEqual(order?.trialAmount, 0.0)
        XCTAssertEqual(order?.firstBillDate, "2026-09-01")

        let info = input.toInfo()
        XCTAssertEqual(info.cardTransactionMode, "authAndCapture")
        XCTAssertFalse(info.isVerifyCard)
        XCTAssertEqual(info.amount, 100.0)
        XCTAssertEqual(info.currency, "EUR")
        XCTAssertEqual(info.externalOrderId, "order-1786545845128")
        XCTAssertFalse(info.isRecurring)
    }

    func testConfirmPaymentResponseParsesNestedBackUrl() {
        let response = ConfirmPaymentResponse(apiMap: [
            "code": 200,
            "status": "ok",
            "data": [
                "transaction": [
                    "transactionId": 99,
                    "status": "pending-redirect",
                    "responseStatus": "3d-pending",
                    "redirectUrl": "https://acs.example/challenge",
                ],
                "threeDSFlowUrl": "https://3ds.example/flow",
                "result": "encoded",
                "orderRequest": [
                    "processing": ["backUrl": "https://merchant.example/return"],
                ],
            ],
        ])
        XCTAssertEqual(response.code, 200)
        XCTAssertEqual(response.data?.transaction?.transactionId, "99")
        XCTAssertEqual(response.data?.threeDSFlowUrl, "https://3ds.example/flow")
        XCTAssertEqual(response.data?.orderRequestBackUrl, "https://merchant.example/return")
    }

    func testParseAcceptsHttpsThreeDSURL() throws {
        let parsed = try makePaymentService().parse(threeDSResponse(url: "https://acs.example/challenge"))
        guard case let .needs3DS(url) = parsed.submission else {
            return XCTFail("expected needs3DS")
        }
        XCTAssertEqual(url.absoluteString, "https://acs.example/challenge")
    }

    func testParseRejectsNonHttpsThreeDSURL() {
        XCTAssertThrowsError(try makePaymentService().parse(threeDSResponse(url: "http://acs.example/challenge"))) { error in
            let paymentError = error as? PaymentError
            XCTAssertEqual(paymentError?.code, "THREE_DS_ERROR")
            XCTAssertEqual(paymentError?.message, "Missing 3DS URL")
        }
    }

    private func makePaymentService() -> PaymentService {
        PaymentService(http: HTTPClient(), env: PaymentEnvironment(publicKey: "pk_test_stub")!)
    }

    private func threeDSResponse(url: String) -> ConfirmPaymentResponse {
        ConfirmPaymentResponse(apiMap: [
            "code": 200,
            "status": "ok",
            "data": [
                "transaction": [
                    "transactionId": 99,
                    "status": "pending-redirect",
                    "responseStatus": "3d-pending",
                    "redirectUrl": url,
                ],
            ],
        ])
    }
}
