import Foundation

package struct OrderInputCustomer {
    package let identifier: String?
    package let firstName: String?
    package let lastName: String?
    package let country: String?
    package let city: String?
    package let phone: String?
    package let email: String?
    package let tags: [String]

    package init(
        identifier: String?,
        firstName: String? = nil,
        lastName: String? = nil,
        country: String? = nil,
        city: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        tags: [String] = []
    ) {
        self.identifier = identifier
        self.firstName = firstName
        self.lastName = lastName
        self.country = country
        self.city = city
        self.phone = phone
        self.email = email
        self.tags = tags
    }

    package init(apiMap map: [String: Any]) {
        identifier = APIMap.nonBlank(map["identifier"])
        firstName = APIMap.nonBlank(map["firstName"])
        lastName = APIMap.nonBlank(map["lastName"])
        country = APIMap.nonBlank(map["country"])
        city = APIMap.nonBlank(map["city"])
        phone = APIMap.nonBlank(map["phone"])
        email = APIMap.nonBlank(map["email"])
        tags = APIMap.stringList(map["tags"])
    }
}

package struct OrderInputOrder {
    package let orderId: String?
    package let type: String?
    package let amount: Double?
    package let currency: String?
    package let description: String?
    package let intervalType: String?
    package let intervalValue: String?
    package let retryPayment: String?
    package let trialAmount: Double?
    package let firstBillDate: String?

    package init(
        orderId: String?,
        type: String?,
        amount: Double?,
        currency: String?,
        description: String? = nil,
        intervalType: String? = nil,
        intervalValue: String? = nil,
        retryPayment: String? = nil,
        trialAmount: Double? = nil,
        firstBillDate: String? = nil
    ) {
        self.orderId = orderId
        self.type = type
        self.amount = amount
        self.currency = currency
        self.description = description
        self.intervalType = intervalType
        self.intervalValue = intervalValue
        self.retryPayment = retryPayment
        self.trialAmount = trialAmount
        self.firstBillDate = firstBillDate
    }

    package init(apiMap map: [String: Any]) {
        orderId = map["orderId"] as? String
        type = map["type"] as? String
        amount = APIMap.doubleValue(map["amount"])
        currency = map["currency"] as? String
        description = map["description"] as? String
        intervalType = map["intervalType"] as? String
        intervalValue = (map["intervalValue"] as? String) ?? APIMap.stringOrNumber(map["intervalValue"])
        retryPayment = map["retryPayment"] as? String
        trialAmount = APIMap.doubleValue(map["trialAmount"])
        firstBillDate = map["firstBillDate"] as? String
    }
}

package struct OrderInput {
    package let publicKey: String?
    package let cardTransactionMode: String?
    package let invoiceEmail: String?
    package let saveCard: Bool
    package let cardId: String?
    package let backUrl: String?
    package let customData: String?
    package let customer: OrderInputCustomer?
    package let order: OrderInputOrder?

    package init(
        publicKey: String? = nil,
        cardTransactionMode: String? = nil,
        invoiceEmail: String? = nil,
        saveCard: Bool = false,
        cardId: String? = nil,
        backUrl: String? = nil,
        customData: String? = nil,
        customer: OrderInputCustomer? = nil,
        order: OrderInputOrder? = nil
    ) {
        self.publicKey = publicKey
        self.cardTransactionMode = cardTransactionMode
        self.invoiceEmail = invoiceEmail
        self.saveCard = saveCard
        self.cardId = cardId
        self.backUrl = backUrl
        self.customData = customData
        self.customer = customer
        self.order = order
    }

    package func toInfo() -> OrderPayloadInfo {
        OrderPayloadInfo(
            cardTransactionMode: cardTransactionMode,
            isVerifyCard: cardTransactionMode == "verifyCard",
            amount: order?.amount,
            currency: order?.currency,
            externalOrderId: order?.orderId,
            isRecurring: order?.type == "recurring"
        )
    }

    package init(apiMap map: [String: Any]) {
        publicKey = map["publicKey"] as? String
        cardTransactionMode = map["cardTransactionMode"] as? String
        invoiceEmail = map["invoiceEmail"] as? String
        saveCard = APIMap.parseBoolean(map["saveCard"])
        cardId = APIMap.stringOrNumber(map["cardId"])
        backUrl = map["backUrl"] as? String
        customData = map["customData"] as? String
        customer = (map["customer"] as? [String: Any]).map { OrderInputCustomer(apiMap: $0) }
        order = (map["order"] as? [String: Any]).map { OrderInputOrder(apiMap: $0) }
    }
}

package struct OrderPayloadInfo {
    package let cardTransactionMode: String?
    package let isVerifyCard: Bool
    package let amount: Double?
    package let currency: String?
    package let externalOrderId: String?
    package let isRecurring: Bool
}

package struct SavedCard: Equatable {
    package let id: String
    package let cardNumber: String?
    package let cardType: String?
    package let cardExpiryDate: String?
    package let isDefault: Bool
    package let bankName: String?
    package let cardBrand: String?
    package let nameOnCard: String?
    package let customerId: String?
    package let cardHolderCountry: String?

    package init(
        id: String,
        cardNumber: String?,
        cardType: String?,
        cardExpiryDate: String?,
        isDefault: Bool = false,
        bankName: String? = nil,
        cardBrand: String? = nil,
        nameOnCard: String? = nil,
        customerId: String? = nil,
        cardHolderCountry: String? = nil
    ) {
        self.id = id
        self.cardNumber = cardNumber
        self.cardType = cardType
        self.cardExpiryDate = cardExpiryDate
        self.isDefault = isDefault
        self.bankName = bankName
        self.cardBrand = cardBrand
        self.nameOnCard = nameOnCard
        self.customerId = customerId
        self.cardHolderCountry = cardHolderCountry
    }

    package static func fromApiMap(_ item: [String: Any]) -> SavedCard? {
        guard let id = APIMap.stringOrNumber(item["id"]) else { return nil }
        let binInfo = item["binInfo"] as? [String: Any]
        let cardType = APIMap.nonBlank(item["cardType"]) ?? APIMap.nonBlank(item["type"])

        let bankName = APIMap.nonBlank(item["bankName"])
            ?? APIMap.nonBlank(binInfo?["bank"])
            ?? cardType.flatMap { SavedCardFormatting.isKnownCardBrand($0) ? nil : $0 }

        let cardBrand = APIMap.nonBlank(item["cardBrand"])
            ?? APIMap.nonBlank(binInfo?["brand"])
            ?? cardType.flatMap { SavedCardFormatting.isKnownCardBrand($0) ? $0 : nil }

        return SavedCard(
            id: id,
            cardNumber: item["cardNumber"] as? String,
            cardType: cardType,
            cardExpiryDate: parseExpiryDate(item),
            isDefault: APIMap.parseBoolean(item["isDefault"]) || APIMap.parseBoolean(item["default"]),
            bankName: bankName,
            cardBrand: cardBrand,
            nameOnCard: APIMap.nonBlank(item["nameOnCard"]),
            customerId: APIMap.stringOrNumber(item["customerId"]),
            cardHolderCountry: APIMap.nonBlank(item["cardHolderCountry"])
        )
    }

    private static func parseExpiryDate(_ item: [String: Any]) -> String? {
        if let existing = APIMap.nonBlank(item["cardExpiryDate"]) { return existing }
        let month = APIMap.nonBlank(item["expiryMonth"]) ?? APIMap.stringOrNumber(item["expiryMonth"])
        let year = APIMap.nonBlank(item["expiryYear"]) ?? APIMap.stringOrNumber(item["expiryYear"])
        guard let month, !month.isEmpty, let year, !year.isEmpty else { return nil }
        let shortYear = year.count == 4 ? String(year.suffix(2)) : year
        return "\(month)/\(shortYear)"
    }
}

package struct SavedCardsResponse {
    package let data: [SavedCard]

    package init(data: [SavedCard]) {
        self.data = data
    }

    package init(apiMap map: [String: Any]) {
        let raw = map["data"] as? [Any] ?? []
        data = raw.compactMap { item in
            guard let entry = item as? [String: Any] else { return nil }
            return SavedCard.fromApiMap(entry)
        }
    }
}

package struct CardInput {
    package var number: String
    package var expiryMonth: String
    package var expiryYear: String
    package var cvv: String
    package var holderName: String?
    package var saveCard: Bool

    package init(
        number: String = "",
        expiryMonth: String = "",
        expiryYear: String = "",
        cvv: String = "",
        holderName: String? = nil,
        saveCard: Bool = false
    ) {
        self.number = number
        self.expiryMonth = expiryMonth
        self.expiryYear = expiryYear
        self.cvv = cvv
        self.holderName = holderName
        self.saveCard = saveCard
    }
}

extension CardInput: CustomStringConvertible {
    package var description: String {
        let holder = holderName.map { _ in "***" } ?? "nil"
        return "CardInput(number=****, expiryMonth=\(expiryMonth), expiryYear=\(expiryYear), cvv=***, holderName=\(holder), saveCard=\(saveCard))"
    }
}

package struct WalletParams {
    package let gateway: String?
    package let gatewayMerchantId: String?
    package let merchantId: String?
    package let merchantName: String?
    package let merchantCountry: String?
    package let supportedNetworks: [String]
    package let merchantOrigin: String?

    package init(
        gateway: String?,
        gatewayMerchantId: String?,
        merchantId: String?,
        merchantName: String?,
        merchantCountry: String?,
        supportedNetworks: [String],
        merchantOrigin: String? = nil
    ) {
        self.gateway = gateway
        self.gatewayMerchantId = gatewayMerchantId
        self.merchantId = merchantId
        self.merchantName = merchantName
        self.merchantCountry = merchantCountry
        self.supportedNetworks = supportedNetworks
        self.merchantOrigin = merchantOrigin
    }

    package init(apiMap map: [String: Any]) {
        let data = (map["data"] as? [String: Any]) ?? map
        gateway = data["gateway"] as? String
        gatewayMerchantId = APIMap.stringOrNumber(data["gatewayMerchantId"])
        merchantId = APIMap.stringOrNumber(data["merchantId"])
            ?? APIMap.stringOrNumber(data["merchantIdentifier"])
        merchantName = data["merchantName"] as? String
        merchantCountry = data["merchantCountry"] as? String
        let origin = data["merchantOrigin"] as? String
        merchantOrigin = origin.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        let allowed = APIMap.stringList(data["allowedCardNetworks"])
        supportedNetworks = allowed.isEmpty ? APIMap.stringList(data["supportedNetworks"]) : allowed
    }
}
