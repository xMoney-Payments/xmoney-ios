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

    func testThemeResolutionVectors() {
        let url = Bundle.module.url(forResource: "test-vectors", withExtension: "json")!
        let root = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let cases = root["themeResolution"] as! [[String: Any]]
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            let sent = item["appearance"] as! [String: Any]
            let appearance = PaymentConfig.Appearance.from(sent)
            let expected = item["expected"] as! [String: String]
            let isDark = item["isDark"] as! Bool
            if let brand = sent["brandColor"] as? String {
                let resolved = appearance.brandColor?.resolved(isDark: isDark)
                XCTAssertEqual(Self.hex(resolved), expected["primary"])
                if brand.count == 9 {
                    XCTAssertEqual(resolved?.alpha ?? 0, 128.0 / 255.0, accuracy: 0.001)
                }
            } else {
                XCTAssertNil(appearance.brandColor)
            }
            if sent["backgroundColor"] != nil {
                XCTAssertEqual(Self.hex(appearance.backgroundColor?.resolved(isDark: isDark)), expected["background"])
            } else {
                XCTAssertNil(appearance.backgroundColor)
            }
        }
    }

    private static func hex(_ color: PaymentConfig.SRGBColor?) -> String {
        guard let color else { return "" }
        return String(
            format: "#%02x%02x%02x",
            Int((color.red * 255).rounded()),
            Int((color.green * 255).rounded()),
            Int((color.blue * 255).rounded())
        )
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
