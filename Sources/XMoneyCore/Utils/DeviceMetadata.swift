import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum DeviceMetadata {
    static func fields() -> [String: String] {
        #if canImport(UIKit)
        let screen = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        let tzOffsetMinutes = -TimeZone.current.secondsFromGMT() / 60
        return [
            "browserLanguage": Locale.preferredLanguages.first ?? "en-US",
            "browserUserAgent": userAgent(),
            "browserColorDepth": "24",
            "browserScreenHeight": String(Int(screen.height * scale)),
            "browserScreenWidth": String(Int(screen.width * scale)),
            "browserTimeZone": String(tzOffsetMinutes),
            "browserJavaEnabled": "false",
            "browserJavascriptEnabled": "true",
        ]
        #else
        return [
            "browserLanguage": "en-US",
            "browserUserAgent": "XMoneySDK/test",
            "browserColorDepth": "24",
            "browserScreenHeight": "844",
            "browserScreenWidth": "390",
            "browserTimeZone": "0",
            "browserJavaEnabled": "false",
            "browserJavascriptEnabled": "true",
        ]
        #endif
    }

    #if canImport(UIKit)
    private static func userAgent() -> String {
        let device = UIDevice.current
        let osVersion = device.systemVersion.replacingOccurrences(of: ".", with: "_")
        return "Mozilla/5.0 (\(device.model); CPU iPhone OS \(osVersion) like Mac OS X) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 XMoneySDK/iOS"
    }
    #endif
}
