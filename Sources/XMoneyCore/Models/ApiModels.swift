import Foundation

package struct SessionTokenResponse {
    package let token: String?

    package init(token: String?) {
        self.token = token
    }

    package init(apiMap map: [String: Any]) {
        token = map["token"] as? String
    }
}

package struct SiteConfig {
    package let whitelabelPaymentForm: Bool
    package let checkNameWithoutSaveCard: Bool
    package let nameCheckValidationEnabled: Bool

    package init(
        whitelabelPaymentForm: Bool = false,
        checkNameWithoutSaveCard: Bool = false,
        nameCheckValidationEnabled: Bool = false
    ) {
        self.whitelabelPaymentForm = whitelabelPaymentForm
        self.checkNameWithoutSaveCard = checkNameWithoutSaveCard
        self.nameCheckValidationEnabled = nameCheckValidationEnabled
    }

    package init(apiMap map: [String: Any]) {
        whitelabelPaymentForm = map["whitelabelPaymentForm"] as? Bool == true
        checkNameWithoutSaveCard = map["checkNameWithoutSaveCard"] as? Bool == true
        nameCheckValidationEnabled = map["nameCheckValidationEnabled"] as? Bool == true
    }
}

package struct ConfirmTransaction {
    package let transactionId: String?
    package let status: String?
    package let responseStatus: String?
    package let redirectUrl: String?

    package init(
        transactionId: String?,
        status: String?,
        responseStatus: String?,
        redirectUrl: String?
    ) {
        self.transactionId = transactionId
        self.status = status
        self.responseStatus = responseStatus
        self.redirectUrl = redirectUrl
    }

    package init(apiMap map: [String: Any]) {
        transactionId = APIMap.stringOrNumber(map["transactionId"])
        status = map["status"] as? String
        responseStatus = map["responseStatus"] as? String
        redirectUrl = map["redirectUrl"] as? String
    }
}

package struct ConfirmPaymentData {
    package let transaction: ConfirmTransaction?
    package let threeDSFlowUrl: String?
    package let result: String?
    package let orderRequestBackUrl: String?

    package init(
        transaction: ConfirmTransaction?,
        threeDSFlowUrl: String?,
        result: String?,
        orderRequestBackUrl: String?
    ) {
        self.transaction = transaction
        self.threeDSFlowUrl = threeDSFlowUrl
        self.result = result
        self.orderRequestBackUrl = orderRequestBackUrl
    }

    package init(apiMap map: [String: Any]) {
        let transactionMap = map["transaction"] as? [String: Any]
        let orderRequest = map["orderRequest"] as? [String: Any]
        let processing = orderRequest?["processing"] as? [String: Any]
        transaction = transactionMap.map { ConfirmTransaction(apiMap: $0) }
        threeDSFlowUrl = map["threeDSFlowUrl"] as? String
        result = map["result"] as? String
        orderRequestBackUrl = processing?["backUrl"] as? String
    }
}

package struct ConfirmPaymentResponse {
    package let code: Int?
    package let status: String?
    package let data: ConfirmPaymentData?

    package init(code: Int?, status: String?, data: ConfirmPaymentData?) {
        self.code = code
        self.status = status
        self.data = data
    }

    package init(apiMap map: [String: Any]) {
        code = APIMap.intValue(map["code"])
        status = map["status"] as? String
        data = (map["data"] as? [String: Any]).map { ConfirmPaymentData(apiMap: $0) }
    }
}
