import Foundation
import XCTest
@testable import XMoneyCore

final class ContractTests: XCTestCase {
    private struct ValidationVector: Decodable {
        let field: String
        let input: VectorInput
        let expectedKey: String?

        enum VectorInput: Decodable {
            case string(String)
            case expiry(month: String, year: String)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let string = try? container.decode(String.self) {
                    self = .string(string)
                    return
                }
                let object = try decoder.container(keyedBy: CodingKeys.self)
                self = .expiry(
                    month: try object.decode(String.self, forKey: .month),
                    year: try object.decode(String.self, forKey: .year)
                )
            }

            private enum CodingKeys: String, CodingKey {
                case month, year
            }
        }
    }

    private struct ButtonTypeVector: Decodable {
        let type: String
        let key: String
    }

    private struct OrderPayloadVector: Decodable {
        let payload: String
        let expected: OrderPayloadExpected
    }

    private struct OrderPayloadExpected: Decodable {
        let amount: Double
        let currency: String
        let externalOrderId: String
        let isRecurring: Bool
        let isVerifyCard: Bool
        let cardTransactionMode: String
    }

    private struct ErrorCodeVector: Decodable {
        let code: String
        let message: String
    }

    private struct LocaleVector: Decodable {
        let locale: String
        let key: String
        let contains: String
    }

    private struct TestVectors: Decodable {
        let validation: [ValidationVector]
        let buttonTypes: [ButtonTypeVector]
        let orderPayload: [OrderPayloadVector]
        let errorCodes: [ErrorCodeVector]
        let locales: [LocaleVector]
    }

    private lazy var vectors: TestVectors = {
        let url = Bundle.module.url(forResource: "test-vectors", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(TestVectors.self, from: data)
    }()

    func testValidationVectors() {
        for vector in vectors.validation {
            let error = validate(vector: vector)
            if let expectedKey = vector.expectedKey {
                XCTAssertEqual(error?.messageKey, expectedKey, "field \(vector.field)")
            } else {
                XCTAssertNil(error, "field \(vector.field) should be valid")
            }
        }
    }

    func testButtonTypeKeysExistInStrings() {
        for button in vectors.buttonTypes {
            let title = Strings.text(button.key, locale: "en-US", args: ["amount": "€1.00"])
            XCTAssertFalse(title.isEmpty)
            XCTAssertNotEqual(title, button.key)
        }
    }

    func testOrderPayloadVectors() {
        for vector in vectors.orderPayload {
            let info = OrderPayloadDecoder.info(from: vector.payload)
            XCTAssertEqual(info.amount ?? 0, vector.expected.amount, accuracy: 0.001)
            XCTAssertEqual(info.currency, vector.expected.currency)
            XCTAssertEqual(info.externalOrderId, vector.expected.externalOrderId)
            XCTAssertEqual(info.isRecurring, vector.expected.isRecurring)
            XCTAssertEqual(info.isVerifyCard, vector.expected.isVerifyCard)
            XCTAssertEqual(info.cardTransactionMode, vector.expected.cardTransactionMode)
        }
    }

    func testErrorCodeTaxonomy() {
        for vector in vectors.errorCodes {
            let error = PaymentError.from(code: vector.code, message: vector.message)
            XCTAssertEqual(error.code, vector.code)
            XCTAssertEqual(error.message, vector.message)
        }
    }

    func testLocaleVectors() {
        for vector in vectors.locales {
            let text = Strings.text(vector.key, locale: vector.locale)
            XCTAssertTrue(text.contains(vector.contains), "locale \(vector.locale)")
        }
    }

    private func validate(vector: ValidationVector) -> CardFieldValidators.FieldError? {
        switch vector.field {
        case "cardNumber":
            guard case let .string(value) = vector.input else {
                XCTFail("cardNumber expects string input")
                return nil
            }
            return CardFieldValidators.validateCardNumber(value)
        case "expiry":
            guard case let .expiry(month, year) = vector.input else {
                XCTFail("expiry expects object input")
                return nil
            }
            return CardFieldValidators.validateExpiry(month: month, year: year)
        case "cvv":
            guard case let .string(value) = vector.input else {
                XCTFail("cvv expects string input")
                return nil
            }
            return CardFieldValidators.validateCVV(value)
        case "holderName":
            guard case let .string(value) = vector.input else {
                XCTFail("holderName expects string input")
                return nil
            }
            return CardFieldValidators.validateHolderName(value)
        default:
            XCTFail("Unknown field \(vector.field)")
            return nil
        }
    }
}
