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
    package let transactionId: String?
    package let is3d: Bool
    package let isRedirect: Bool
    package let redirectUrl: String?
    package let redirectFormMethod: String
    package let redirectParams: [String: String]

    package init(
        transaction: ConfirmTransaction?,
        threeDSFlowUrl: String?,
        result: String?,
        orderRequestBackUrl: String?,
        transactionId: String? = nil,
        is3d: Bool = false,
        isRedirect: Bool = false,
        redirectUrl: String? = nil,
        redirectFormMethod: String = "GET",
        redirectParams: [String: String] = [:]
    ) {
        self.transaction = transaction
        self.threeDSFlowUrl = threeDSFlowUrl
        self.result = result
        self.orderRequestBackUrl = orderRequestBackUrl
        self.transactionId = transactionId
        self.is3d = is3d
        self.isRedirect = isRedirect
        self.redirectUrl = redirectUrl
        self.redirectFormMethod = redirectFormMethod
        self.redirectParams = redirectParams
    }

    package init(apiMap map: [String: Any]) {
        let transactionMap = map["transaction"] as? [String: Any]
        let orderRequest = map["orderRequest"] as? [String: Any]
        let processing = orderRequest?["processing"] as? [String: Any]
        let redirectMap = map["redirect"] as? [String: Any]
        transaction = transactionMap.map { ConfirmTransaction(apiMap: $0) }
        threeDSFlowUrl = map["threeDSFlowUrl"] as? String
        result = map["result"] as? String
        orderRequestBackUrl = processing?["backUrl"] as? String
        transactionId = APIMap.stringOrNumber(map["transactionId"])
        is3d = APIMap.parseBoolean(map["is3d"])
        isRedirect = APIMap.parseBoolean(map["isRedirect"])
        redirectUrl = APIMap.nonBlank(redirectMap?["url"])
            ?? APIMap.nonBlank(map["redirect"])
            ?? APIMap.nonBlank(map["redirectUrl"])
        let method = APIMap.nonBlank(redirectMap?["formMethod"])?.uppercased()
        redirectFormMethod = method ?? "GET"
        var params: [String: String] = [:]
        (redirectMap?["params"] as? [String: Any])?.forEach { key, value in
            if let string = APIMap.stringOrNumber(value) { params[key] = string }
        }
        redirectParams = params
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
