import Foundation
import XCTest
@testable import XMoneyCore

final class AppearanceConfigFromTests: XCTestCase {
    func testFromNilReturnsEmptyConfig() {
        let appearance = PaymentConfig.AppearanceConfig.from(nil)
        XCTAssertNil(appearance.fontFamily)
        XCTAssertNil(appearance.fontScale)
        XCTAssertNil(appearance.colors)
        XCTAssertNil(appearance.borderRadius)
        XCTAssertNil(appearance.primaryButton)
    }

    func testFromIgnoresFlatFontAndShapeKeys() {
        let appearance = PaymentConfig.AppearanceConfig.from([
            "fontFamily": "Inter",
            "fontScale": 1.5,
            "borderRadius": 10,
            "borderWidth": 2,
        ])
        XCTAssertNil(appearance.fontFamily)
        XCTAssertNil(appearance.fontScale)
        XCTAssertNil(appearance.borderRadius)
        XCTAssertNil(appearance.borderWidth)
    }

    func testFromNestedFontShapesAndPrimaryButton() {
        let dict: [String: Any] = [
            "font": [
                "family": "Inter",
                "scale": 1.25,
            ],
            "shapes": [
                "borderRadius": 12,
                "borderWidth": 2,
            ],
            "colors": [
                "primary": "#0E7C66",
            ],
            "primaryButton": [
                "font": [
                    "family": "Roobert",
                ],
                "shapes": [
                    "borderRadius": 8,
                    "borderWidth": 1,
                ],
                "colors": [
                    "background": "#111111",
                    "text": "#FFFFFF",
                    "border": "#222222",
                ],
            ],
        ]

        let appearance = PaymentConfig.AppearanceConfig.from(dict)
        XCTAssertEqual(appearance.fontFamily, "Inter")
        XCTAssertEqual(appearance.fontScale, 1.25)
        XCTAssertEqual(appearance.borderRadius, 12)
        XCTAssertEqual(appearance.borderWidth, 2)
        XCTAssertEqual(appearance.colors?.primary, "#0E7C66")
        XCTAssertEqual(appearance.primaryButton?.fontFamily, "Roobert")
        XCTAssertEqual(appearance.primaryButton?.borderRadius, 8)
        XCTAssertEqual(appearance.primaryButton?.borderWidth, 1)
        XCTAssertEqual(appearance.primaryButton?.colors?.background, "#111111")
        XCTAssertEqual(appearance.primaryButton?.colors?.text, "#FFFFFF")
        XCTAssertEqual(appearance.primaryButton?.colors?.border, "#222222")
    }
}
