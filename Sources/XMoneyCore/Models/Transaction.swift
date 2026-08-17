import Foundation

public struct TransactionCustomer: Equatable, Sendable {
    public let id: String?
    public let siteId: String?
    public let identifier: String?
    public let firstName: String?
    public let lastName: String?
    public let country: String?
    public let state: String?
    public let city: String?
    public let zipCode: String?
    public let address: String?
    public let phone: String?
    public let email: String?
    public let isWhitelisted: Bool
    public let isWhitelistedUntil: String?
    public let creationDate: String?
    public let creationTimestamp: Int64?

    public init(
        id: String?,
        siteId: String?,
        identifier: String?,
        firstName: String?,
        lastName: String?,
        country: String?,
        state: String?,
        city: String?,
        zipCode: String?,
        address: String?,
        phone: String?,
        email: String?,
        isWhitelisted: Bool = false,
        isWhitelistedUntil: String? = nil,
        creationDate: String? = nil,
        creationTimestamp: Int64? = nil
    ) {
        self.id = id
        self.siteId = siteId
        self.identifier = identifier
        self.firstName = firstName
        self.lastName = lastName
        self.country = country
        self.state = state
        self.city = city
        self.zipCode = zipCode
        self.address = address
        self.phone = phone
        self.email = email
        self.isWhitelisted = isWhitelisted
        self.isWhitelistedUntil = isWhitelistedUntil
        self.creationDate = creationDate
        self.creationTimestamp = creationTimestamp
    }

    package init(apiMap map: [String: Any]) {
        id = APIMap.stringOrNumber(map["id"])
        siteId = APIMap.stringOrNumber(map["siteId"])
        identifier = APIMap.nonBlank(map["identifier"])
        firstName = APIMap.nonBlank(map["firstName"])
        lastName = APIMap.nonBlank(map["lastName"])
        country = APIMap.nonBlank(map["country"])
        state = APIMap.nonBlank(map["state"])
        city = APIMap.nonBlank(map["city"])
        zipCode = APIMap.nonBlank(map["zipCode"])
        address = APIMap.nonBlank(map["address"])
        phone = APIMap.nonBlank(map["phone"])
        email = APIMap.nonBlank(map["email"])
        isWhitelisted = APIMap.parseBoolean(map["isWhitelisted"])
        isWhitelistedUntil = map["isWhitelistedUntil"] as? String
        creationDate = map["creationDate"] as? String
        creationTimestamp = APIMap.int64Value(map["creationTimestamp"])
    }
}

/// Non-sensitive transaction details returned after a successful payment.
public struct Transaction: Equatable, Sendable {
    public let id: String?
    public let status: String?
    public let amount: String?
    public let currencyKey: String?
    public let amountInEuro: String?
    public let externalOrderId: String?
    public let description: String?
    public let customerData: TransactionCustomer?

    public var isComplete: Bool {
        status?.contains("complete") == true
    }

    public var isSuccessfulComplete: Bool {
        isComplete && status?.lowercased().contains("fail") != true
    }

    public init(
        id: String?,
        status: String?,
        amount: String? = nil,
        currencyKey: String? = nil,
        amountInEuro: String? = nil,
        externalOrderId: String? = nil,
        description: String? = nil,
        customerData: TransactionCustomer? = nil
    ) {
        self.id = id
        self.status = status
        self.amount = amount
        self.currencyKey = currencyKey
        self.amountInEuro = amountInEuro
        self.externalOrderId = externalOrderId
        self.description = description
        self.customerData = customerData
    }

    package init(apiMap map: [String: Any]) {
        id = APIMap.stringOrNumber(map["transactionId"]) ?? APIMap.stringOrNumber(map["id"])
        status = (map["transactionStatus"] as? String) ?? (map["status"] as? String)
        amount = (map["amount"] as? String) ?? APIMap.stringOrNumber(map["amount"])
        currencyKey = map["currencyKey"] as? String
        amountInEuro = (map["amountInEuro"] as? String) ?? APIMap.stringOrNumber(map["amountInEuro"])
        externalOrderId = map["externalOrderId"] as? String
        description = map["description"] as? String
        customerData = (map["customerData"] as? [String: Any]).map { TransactionCustomer(apiMap: $0) }
    }
}
