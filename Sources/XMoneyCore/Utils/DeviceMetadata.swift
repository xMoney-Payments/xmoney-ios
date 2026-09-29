import Foundation
import UIKit

enum DeviceMetadata {
    /// Form fields read by the secure API when it builds 3DS browser data.
    /// `browserTimeZone` is the minute offset. An IANA name fails that check and 3DS is not started.
    static func fields() -> [String: String] {
        let screen = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        let zone = TimeZone.current
        return [
            "browserAcceptHeader": "*/*",
            "browserLanguage": browserLanguage(Locale.current),
            "browserColorDepth": "24",
            "browserScreenHeight": String(Int(screen.height * scale)),
            "browserScreenWidth": String(Int(screen.width * scale)),
            "browserTimeZone": String(timeZoneOffsetMinutes(secondsFromGMT: zone.secondsFromGMT())),
            "browserJavaEnabled": "false",
            "browserJavascriptEnabled": "true",
            "browserUserAgent": browserUserAgent(),
        ]
    }

    /// Copied by the secure API into `browserAcceptHeader`, `browserLanguage`, and `browserUserAgent`.
    static func httpHeaders() -> [String: String] {
        [
            "Accept": "*/*",
            "Accept-Language": browserLanguage(Locale.current),
            "User-Agent": browserUserAgent(),
        ]
    }

    /// BPC reads the OS from this header. It has to contain iPhone, iPad, or iPod and a `CPU OS` version.
    static func browserUserAgent() -> String {
        let device = UIDevice.current
        return browserUserAgent(model: device.model, systemVersion: device.systemVersion)
    }

    static func browserUserAgent(model: String, systemVersion: String) -> String {
        let version = systemVersion.replacingOccurrences(of: ".", with: "_")
        let osToken = model.contains("iPad") ? "OS" : "iPhone OS"
        return "Mozilla/5.0 (\(model); CPU \(osToken) \(version) like Mac OS X) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile XMoneySDK/iOS"
    }

    /// The secure API accepts at most 8 characters. Prefer the full tag, then language-country, then language.
    static func browserLanguage(tag: String, language: String, country: String) -> String {
        if tag.count <= 8 { return tag }
        let languageCountry = country.isEmpty ? language : "\(language)-\(country)"
        if languageCountry.count <= 8 { return languageCountry }
        return String(language.prefix(8))
    }

    static func browserLanguage(_ locale: Locale) -> String {
        browserLanguage(
            tag: bcp47Tag(locale),
            language: languageCode(of: locale),
            country: regionCode(of: locale)
        )
    }

    /// JavaScript `getTimezoneOffset` sign: minutes west of UTC. Bucharest summer is `-180`.
    static func timeZoneOffsetMinutes(secondsFromGMT: Int) -> Int {
        -secondsFromGMT / 60
    }

    private static func bcp47Tag(_ locale: Locale) -> String {
        var identifier = locale.identifier
        if let at = identifier.firstIndex(of: "@") {
            identifier = String(identifier[..<at])
        }
        return identifier.replacingOccurrences(of: "_", with: "-")
    }

    private static func languageCode(of locale: Locale) -> String {
        if #available(iOS 16, *) {
            return locale.language.languageCode?.identifier ?? ""
        }
        return locale.languageCode ?? ""
    }

    private static func regionCode(of locale: Locale) -> String {
        if #available(iOS 16, *) {
            return locale.region?.identifier ?? ""
        }
        return locale.regionCode ?? ""
    }
}
