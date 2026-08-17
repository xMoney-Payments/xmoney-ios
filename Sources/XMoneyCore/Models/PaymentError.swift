import Foundation

public enum PaymentError: Error, Equatable, LocalizedError {
    case network(String)
    case session(String)
    case payment(String)
    case threeDS(String)
    case pollTimeout(String)
    case invalidKey(String)
    case applePay(String)
    case cardHolderVerification(String)
    case load(String)
    case canceled
    case unknown(code: String, message: String)

    public var code: String {
        switch self {
        case .network: return "NETWORK_ERROR"
        case .session: return "SESSION_ERROR"
        case .payment: return "PAYMENT_ERROR"
        case .threeDS: return "THREE_DS_ERROR"
        case .pollTimeout: return "POLL_TIMEOUT"
        case .invalidKey: return "INVALID_PUBLIC_KEY"
        case .applePay: return "APPLE_PAY"
        case .cardHolderVerification: return "CARD_HOLDER_VERIFICATION"
        case .load: return "LOAD_ERROR"
        case .canceled: return "CANCELED"
        case let .unknown(code, _): return code
        }
    }

    public var message: String {
        switch self {
        case let .network(message),
             let .session(message),
             let .payment(message),
             let .threeDS(message),
             let .pollTimeout(message),
             let .invalidKey(message),
             let .applePay(message),
             let .cardHolderVerification(message),
             let .load(message):
            return message
        case .canceled:
            return "Payment canceled"
        case let .unknown(_, message):
            return message
        }
    }

    public var errorDescription: String? { message }

    public static let nameCheckNotEnabled =
        "Card holder name verification is not enabled for this site. Remove card holder verification or contact support."
    public static let verificationRejected =
        "Card owner verification rejected by cardOwnerVerificationCallback"

    public static let genericNetwork = "Network request failed"
    public static let genericRequest = "Request failed"
    public static let genericPayment = "Payment failed"
    public static let genericLoad = "Failed to load"
    public static let genericApplePay = "Apple Pay failed"
    public static let missingApplePayAmountOrCurrency = "Missing amount or currency for Apple Pay."

    public func merchantMessage() -> String {
        switch self {
        case .network:
            return Self.genericNetwork
        case .unknown:
            return Self.genericRequest
        case .payment:
            return Self.isSdkAuthored(message) ? message : Self.genericPayment
        case .load:
            return Self.isSdkAuthored(message) ? message : Self.genericLoad
        case .applePay:
            return Self.isSdkAuthored(message) ? message : Self.genericApplePay
        default:
            return message
        }
    }

    public func merchantFacing() -> PaymentError {
        PaymentError.from(code: code, message: merchantMessage())
    }

    private static let sdkAuthoredMessages: Set<String> = [
        nameCheckNotEnabled,
        verificationRejected,
        "Missing session token",
        "Missing 3DS URL",
        "Polling timed out",
        "Invalid public key",
        "Payment canceled",
        "Missing currency for card holder verification",
        "Missing transaction id",
        genericNetwork,
        genericRequest,
        genericPayment,
        genericLoad,
        genericApplePay,
        "Missing transaction",
        "Missing Apple Pay merchant ID from wallet params.",
        missingApplePayAmountOrCurrency,
        "Invalid Apple Pay merchant session response.",
        "Apple Pay is not available on this device.",
    ]

    private static func isSdkAuthored(_ message: String) -> Bool {
        if sdkAuthoredMessages.contains(message) { return true }
        if message.hasPrefix("Transaction ") { return true }
        if message.hasPrefix("Apple Pay is not available") { return true }
        return false
    }

    public static func from(code: String, message: String) -> PaymentError {
        switch code {
        case "NETWORK_ERROR": return .network(message)
        case "SESSION_ERROR": return .session(message)
        case "PAYMENT_ERROR": return .payment(message)
        case "THREE_DS_ERROR": return .threeDS(message)
        case "POLL_TIMEOUT": return .pollTimeout(message)
        case "INVALID_PUBLIC_KEY": return .invalidKey(message)
        case "APPLE_PAY": return .applePay(message)
        case "CARD_HOLDER_VERIFICATION": return .cardHolderVerification(message)
        case "LOAD_ERROR": return .load(message)
        case "CANCELED": return .canceled
        default: return .unknown(code: code, message: message)
        }
    }
}
