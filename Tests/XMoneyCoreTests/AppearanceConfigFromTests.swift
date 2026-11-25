import Foundation
import XCTest
@testable import XMoneyCore

final class AppearanceConfigFromTests: XCTestCase {
    func testFromNilReturnsEmptyAppearance() {
        let appearance = PaymentConfig.Appearance.from(nil)
        XCTAssertNil(appearance.brandColor)
        XCTAssertNil(appearance.fontFamily)
        XCTAssertEqual(appearance.corners, .default)
        XCTAssertTrue(appearance.pillButtons)
        XCTAssertEqual(appearance.colorScheme, .automatic)
    }

    func testFromParsesSeedColorsCornersAndOverrides() {
        let appearance = PaymentConfig.Appearance.from([
            "colorScheme": "light",
            "brandColor": ["light": "#1D4ED8", "dark": "#436CDF"],
            "accentColor": "#0F766E",
            "backgroundColor": "#FBF5EA",
            "neutralTint": "#8A7560",
            "corners": "rounded",
            "pillButtons": false,
            "fontFamily": "Georgia",
            "overrides": [
                "onBrandColor": "#16141A",
                "textColor": "#111111",
                "linkColor": "#0F766E",
                "borderColor": "#E7D7C4",
                "componentColor": "#FEFDFA",
                "selectedColor": "#F4E6D4",
                "secondaryButtonColor": "#E7D3C4",
            ],
        ])
        XCTAssertEqual(appearance.colorScheme, .light)
        XCTAssertEqual(appearance.brandColor?.light.hex, "#1D4ED8")
        XCTAssertEqual(appearance.brandColor?.dark.hex, "#436CDF")
        XCTAssertEqual(appearance.accentColor?.light.hex, "#0F766E")
        XCTAssertEqual(appearance.backgroundColor?.light.hex, "#FBF5EA")
        XCTAssertEqual(appearance.neutralTint?.light.hex, "#8A7560")
        XCTAssertEqual(appearance.corners, .rounded)
        XCTAssertFalse(appearance.pillButtons)
        XCTAssertEqual(appearance.fontFamily, "Georgia")
        XCTAssertEqual(appearance.overrides.onBrandColor?.light.hex, "#16141A")
        XCTAssertEqual(appearance.overrides.componentColor?.light.hex, "#FEFDFA")
        XCTAssertEqual(appearance.overrides.secondaryButtonColor?.light.hex, "#E7D3C4")
    }

    func testInvalidHexIsDropped() {
        let appearance = PaymentConfig.Appearance.from(["brandColor": "not-a-color"])
        XCTAssertNil(appearance.brandColor)
    }
}
