import Foundation
import XCTest
@testable import XMoneyCore

final class AppearanceConfigFromTests: XCTestCase {
    func testFromNilReturnsEmptyAppearance() {
        let appearance = PaymentConfig.Appearance.from(nil)
        XCTAssertNil(appearance.brandColor)
        XCTAssertNil(appearance.typography.fontFamily)
        XCTAssertEqual(appearance.shape.corners, .default)
        XCTAssertTrue(appearance.shape.pillButtons)
        XCTAssertEqual(appearance.borders.width, 1)
        XCTAssertEqual(appearance.colorScheme, .automatic)
    }

    func testFromParsesSeedColorsCornersAndOverrides() {
        let appearance = PaymentConfig.Appearance.from([
            "colorScheme": "light",
            "brandColor": ["light": "#1D4ED8", "dark": "#436CDF"],
            "accentColor": "#0F766E",
            "backgroundColor": "#FBF5EA",
            "neutralTint": "#8A7560",
            "typography": ["fontFamily": "Georgia"],
            "borders": ["width": 2],
            "shape": ["corners": "rounded", "pillButtons": false],
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
        XCTAssertEqual(appearance.shape.corners, .rounded)
        XCTAssertFalse(appearance.shape.pillButtons)
        XCTAssertEqual(appearance.typography.fontFamily, "Georgia")
        XCTAssertEqual(appearance.borders.width, 2)
        XCTAssertEqual(appearance.overrides.onBrandColor?.light.hex, "#16141A")
        XCTAssertEqual(appearance.overrides.componentColor?.light.hex, "#FEFDFA")
        XCTAssertEqual(appearance.overrides.secondaryButtonColor?.light.hex, "#E7D3C4")
    }

    func testInvalidHexIsDropped() {
        let appearance = PaymentConfig.Appearance.from(["brandColor": "not-a-color"])
        XCTAssertNil(appearance.brandColor)
    }

    func testBorderWidthParsesAndClamps() {
        XCTAssertEqual(PaymentConfig.Appearance().borders.width, 1)
        XCTAssertEqual(PaymentConfig.Appearance.from(["borders": ["width": 2.5]]).borders.width, 2.5)
        XCTAssertEqual(PaymentConfig.Appearance.from(["borders": ["width": 9]]).borders.width, 4)
        XCTAssertEqual(PaymentConfig.Appearance.from(["borders": ["width": -1]]).borders.width, 0)
        XCTAssertEqual(PaymentConfig.Appearance.from(["borders": ["width": true]]).borders.width, 1)
        XCTAssertEqual(PaymentConfig.Appearance.from(["borders": ["width": "wide"]]).borders.width, 1)
        let flat = PaymentConfig.Appearance.from([
            "fontFamily": "Georgia",
            "borderWidth": 3,
            "corners": "sharp",
            "pillButtons": false,
        ])
        XCTAssertNil(flat.typography.fontFamily)
        XCTAssertEqual(flat.borders.width, 1)
        XCTAssertEqual(flat.shape.corners, .default)
        XCTAssertTrue(flat.shape.pillButtons)
    }

    func testDictionaryKeysMatchTheVector() {
        let url = Bundle.module.url(forResource: "test-vectors", withExtension: "json")!
        let root = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        func keys(_ name: String) -> Set<String> { Set(root[name] as! [String]) }
        XCTAssertEqual(PaymentConfig.Appearance.dictionaryKeys, keys("appearanceKeys"))
        XCTAssertEqual(PaymentConfig.Typography.dictionaryKeys, keys("typographyKeys"))
        XCTAssertEqual(PaymentConfig.Borders.dictionaryKeys, keys("borderKeys"))
        XCTAssertEqual(PaymentConfig.Shape.dictionaryKeys, keys("shapeKeys"))
        XCTAssertEqual(PaymentConfig.AppearanceOverrides.dictionaryKeys, keys("overrideKeys"))
    }
}
