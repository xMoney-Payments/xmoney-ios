import Foundation

public enum CardHolderMatchStatus: String, Equatable, Sendable {
    case matched = "Matched"
    case notMatched = "NotMatched"
    case notVerified = "NotVerified"
    case partialMatched = "PartialMatched"
    case notSupported = "NotSupported"

    public static func from(_ raw: String?) -> CardHolderMatchStatus {
        guard let raw else { return .notVerified }
        return CardHolderMatchStatus(rawValue: raw) ?? .notVerified
    }
}

public struct CardHolderVerificationResult: Equatable, Sendable {
    public let status: CardHolderMatchStatus
    public let firstNameStatus: CardHolderMatchStatus?
    public let middleNameStatus: CardHolderMatchStatus?
    public let lastNameStatus: CardHolderMatchStatus?

    public init(
        status: CardHolderMatchStatus,
        firstNameStatus: CardHolderMatchStatus? = nil,
        middleNameStatus: CardHolderMatchStatus? = nil,
        lastNameStatus: CardHolderMatchStatus? = nil
    ) {
        self.status = status
        self.firstNameStatus = firstNameStatus
        self.middleNameStatus = middleNameStatus
        self.lastNameStatus = lastNameStatus
    }

    public static func fromApiMap(_ dict: [String: Any]?) -> CardHolderVerificationResult {
        guard let dict else {
            return CardHolderVerificationResult(status: .notVerified)
        }
        func status(_ key: String) -> CardHolderMatchStatus? {
            (dict[key] as? String).map { CardHolderMatchStatus.from($0) }
        }
        return CardHolderVerificationResult(
            status: CardHolderMatchStatus.from(dict["status"] as? String),
            firstNameStatus: status("firstNameStatus"),
            middleNameStatus: status("middleNameStatus"),
            lastNameStatus: status("lastNameStatus")
        )
    }
}

package struct AccountValidationResponse {
    package let networkResponseCode: String?
    package let networkResponseCodeDescription: String?
    package let nameValidationResults: CardHolderVerificationResult

    package init(
        networkResponseCode: String?,
        networkResponseCodeDescription: String?,
        nameValidationResults: CardHolderVerificationResult
    ) {
        self.networkResponseCode = networkResponseCode
        self.networkResponseCodeDescription = networkResponseCodeDescription
        self.nameValidationResults = nameValidationResults
    }

    package init(apiMap map: [String: Any]) {
        networkResponseCode = (map["networkResponseCode"] as? String)
            ?? APIMap.stringOrNumber(map["networkResponseCode"])
        networkResponseCodeDescription = map["networkResponseCodeDescription"] as? String
        nameValidationResults = CardHolderVerificationResult.fromApiMap(
            map["nameValidationResults"] as? [String: Any]
        )
    }
}

public struct CardHolderName: Equatable, Sendable {
    public var firstName: String
    public var middleName: String
    public var lastName: String

    public init(firstName: String, middleName: String = "", lastName: String) {
        self.firstName = firstName
        self.middleName = middleName
        self.lastName = lastName
    }

    func toMap() -> [String: Any] {
        [
            "firstName": firstName,
            "middleName": middleName,
            "lastName": lastName,
        ]
    }
}

public struct CardHolderVerification: @unchecked Sendable {
    public var name: CardHolderName
    public var onCardHolderVerification: (CardHolderVerificationResult) -> Bool

    public init(
        name: CardHolderName,
        onCardHolderVerification: @escaping (CardHolderVerificationResult) -> Bool = { _ in false }
    ) {
        self.name = name
        self.onCardHolderVerification = onCardHolderVerification
    }
}
