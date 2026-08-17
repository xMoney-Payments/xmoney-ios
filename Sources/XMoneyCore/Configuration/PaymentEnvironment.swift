import Foundation

struct PaymentEnvironment {
    enum Kind {
        case test
        case live
    }

    let kind: Kind

    init?(publicKey: String) {
        let key = publicKey.lowercased()
        if key.contains("live") {
            self.kind = .live
        } else if key.contains("test") {
            self.kind = .test
        } else {
            return nil
        }
    }

    var secureBaseURL: String {
        kind == .live
            ? SdkConstants.secureBaseURLProd
            : SdkConstants.secureBaseURLStage
    }

    var apiNextBaseURL: String {
        kind == .live
            ? SdkConstants.apiNextBaseURLProd
            : SdkConstants.apiNextBaseURLStage
    }
}
