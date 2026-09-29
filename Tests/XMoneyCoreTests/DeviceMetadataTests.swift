import UIKit
import XCTest
@testable import XMoneyCore

final class DeviceMetadataTests: XCTestCase {
    func testBrowserLanguageKeepsShortTags() {
        XCTAssertEqual(
            DeviceMetadata.browserLanguage(tag: "en-US", language: "en", country: "US"),
            "en-US"
        )
        XCTAssertEqual(DeviceMetadata.browserLanguage(Locale(identifier: "en_US")), "en-US")
    }

    func testBrowserLanguageFallsBackWhenTagExceedsEightCharacters() {
        XCTAssertEqual(
            DeviceMetadata.browserLanguage(tag: "zh-Hans-CN", language: "zh", country: "CN"),
            "zh-CN"
        )
        XCTAssertEqual(DeviceMetadata.browserLanguage(Locale(identifier: "zh_Hans_CN")), "zh-CN")
    }

    func testBrowserLanguageTruncatesOverlongLanguageCode() {
        XCTAssertEqual(
            DeviceMetadata.browserLanguage(tag: "toolongtag", language: "verylongcode", country: ""),
            "verylong"
        )
    }

    func testTimeZoneOffsetUsesJavaScriptSign() {
        XCTAssertEqual(DeviceMetadata.timeZoneOffsetMinutes(secondsFromGMT: 10_800), -180)
        XCTAssertEqual(DeviceMetadata.timeZoneOffsetMinutes(secondsFromGMT: -25_200), 420)
    }

    func testBrowserUserAgentLooksLikeIOS() {
        let iphone = DeviceMetadata.browserUserAgent(model: "iPhone", systemVersion: "18.6")
        XCTAssertEqual(
            iphone,
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile XMoneySDK/iOS"
        )

        let ipad = DeviceMetadata.browserUserAgent(model: "iPad", systemVersion: "17.4.1")
        XCTAssertTrue(ipad.contains("iPad"))
        XCTAssertTrue(ipad.contains("CPU OS 17_4_1"))
    }

    func testFieldsMatchSecureThreeDSBrowserData() {
        let fields = DeviceMetadata.fields()
        let screen = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        let offset = DeviceMetadata.timeZoneOffsetMinutes(secondsFromGMT: TimeZone.current.secondsFromGMT())

        XCTAssertEqual(Set(fields.keys), [
            "browserAcceptHeader",
            "browserLanguage",
            "browserColorDepth",
            "browserScreenHeight",
            "browserScreenWidth",
            "browserTimeZone",
            "browserJavaEnabled",
            "browserJavascriptEnabled",
            "browserUserAgent",
        ])
        XCTAssertEqual(fields["browserAcceptHeader"], "*/*")
        XCTAssertEqual(fields["browserLanguage"], DeviceMetadata.browserLanguage(Locale.current))
        XCTAssertLessThanOrEqual(fields["browserLanguage"]?.count ?? 9, 8)
        XCTAssertEqual(fields["browserColorDepth"], "24")
        XCTAssertEqual(fields["browserScreenHeight"], String(Int(screen.height * scale)))
        XCTAssertEqual(fields["browserScreenWidth"], String(Int(screen.width * scale)))
        XCTAssertEqual(fields["browserTimeZone"], String(offset))
        XCTAssertTrue(fields["browserTimeZone"]?.range(of: #"^[\+\-]?[0-9]{1,5}$"#, options: .regularExpression) != nil)
        XCTAssertEqual(fields["browserJavaEnabled"], "false")
        XCTAssertEqual(fields["browserJavascriptEnabled"], "true")
        XCTAssertEqual(fields["browserUserAgent"], DeviceMetadata.browserUserAgent())
        XCTAssertTrue(fields["browserUserAgent"]?.hasPrefix("Mozilla/5.0") ?? false)

        for key in ["userAgent", "OS", "screenWidth", "screenHeight", "browserTimeZoneOffset", "javaEnabled"] {
            XCTAssertNil(fields[key], key)
        }
    }

    func testHTTPHeadersMatchTheBrowserFields() {
        let headers = DeviceMetadata.httpHeaders()
        XCTAssertEqual(headers["Accept"], "*/*")
        XCTAssertEqual(headers["Accept-Language"], DeviceMetadata.browserLanguage(Locale.current))
        XCTAssertLessThanOrEqual(headers["Accept-Language"]?.count ?? 9, 8)
        XCTAssertEqual(headers["User-Agent"], DeviceMetadata.browserUserAgent())
        XCTAssertTrue(headers["User-Agent"]?.hasPrefix("Mozilla/5.0") ?? false)
    }
}
