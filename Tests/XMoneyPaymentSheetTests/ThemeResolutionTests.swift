import XCTest
@testable import XMoneyPaymentSheet
import XMoneyCore

#if canImport(UIKit)
final class ThemeResolutionTests: XCTestCase {
    private func resolve(
        _ appearance: PaymentConfig.Appearance = .init(),
        isDark: Bool,
        increasedContrast: Bool = false
    ) -> CheckoutTheme {
        CheckoutTheme.resolve(
            config: PaymentConfig(publicKey: "pk_test", options: .init(appearance: appearance)),
            isDark: isDark,
            increasedContrast: increasedContrast
        )
    }

    func testEmptyAppearanceMatchesBuiltInThemes() {
        let light = resolve(isDark: false)
        let dark = resolve(isDark: true)
        XCTAssertEqual(light.background.hexString, "#f7f6ff")
        XCTAssertEqual(light.componentBackground.hexString, "#ffffff")
        XCTAssertEqual(light.primary.hexString, "#7c4dff")
        XCTAssertEqual(light.primaryText.hexString, "#16141a")
        XCTAssertEqual(light.textBrand.hexString, "#7a4bfb")
        XCTAssertEqual(light.errorText.hexString, "#dc2626")
        XCTAssertEqual(dark.background.hexString, "#18181b")
        XCTAssertEqual(dark.componentBackground.hexString, "#1f1f23")
        XCTAssertEqual(dark.primaryText.hexString, "#fafafa")
        XCTAssertEqual(dark.textBrand.hexString, "#926bff")
        XCTAssertEqual(dark.errorText.hexString, "#ef4444")
        XCTAssertEqual(CheckoutTheme.brandPrimary.hexString, "#7c4dff")
        XCTAssertEqual(light.iconBrand.hexString, "#7c4dff")
        XCTAssertEqual(dark.iconBrand.hexString, "#926bff")
        XCTAssertEqual(light.inverseText.hexString, "#f7f6ff")
        XCTAssertEqual(dark.inverseText.hexString, "#09090b")
        XCTAssertEqual(light.brandTileBackground.hexString, "#ffffff")
        XCTAssertEqual(dark.brandTileBackground.hexString, "#ffffff")
        XCTAssertNil(light.visaTint)
        XCTAssertNil(dark.visaTint)
        XCTAssertEqual(light.rowRadius, 16, accuracy: 0.001)
        XCTAssertEqual(dark.rowRadius, 16, accuracy: 0.001)
        var borderAlpha: CGFloat = 1
        light.containerBorder.getRed(nil, green: nil, blue: nil, alpha: &borderAlpha)
        XCTAssertEqual(borderAlpha, 0, accuracy: 0.001)
        dark.containerBorder.getRed(nil, green: nil, blue: nil, alpha: &borderAlpha)
        XCTAssertEqual(borderAlpha, 0, accuracy: 0.001)
    }

    func testSentBrandIsNotRewritten() {
        let yellow = resolve(.init(brandColor: .init(hex: "#FACC15")), isDark: false)
        XCTAssertEqual(yellow.primary.hexString, "#facc15")
        XCTAssertEqual(yellow.primaryButtonText.hexString, "#16141a")
        let blue = resolve(.init(brandColor: .init(hex: "#1D4ED8")), isDark: false)
        XCTAssertEqual(blue.primaryButtonText.hexString, "#ffffff")
        XCTAssertEqual(blue.background.hexString, "#f1f4fd")
        XCTAssertEqual(blue.iconBrand.hexString, "#1d4ed8")
    }

    func testAccentDoesNotChangeThePayButton() {
        let theme = resolve(.init(accentColor: .init(hex: "#0F766E")), isDark: false)
        XCTAssertEqual(theme.primary.hexString, "#7c4dff")
        XCTAssertEqual(theme.iconBrand.hexString, "#0f766e")
    }

    func testBackgroundIsTheSheetAndWarmCreamCard() {
        let theme = resolve(
            .init(
                brandColor: .init(hex: "#B4532A"),
                backgroundColor: .init(hex: "#FBF5EA"),
                neutralTint: .init(hex: "#8A7560")
            ),
            isDark: false
        )
        XCTAssertEqual(theme.background.hexString, "#fbf5ea")
        XCTAssertEqual(theme.primary.hexString, "#b4532a")
        XCTAssertEqual(theme.componentBackground.hexString, "#fefdfa")
    }

    func testXPortalSheetLiftsOffTheBackdrop() {
        let theme = resolve(
            .init(
                brandColor: .init(hex: "#FFFFFF"),
                backgroundColor: .init(hex: "#000000"),
                neutralTint: .init(hex: "#7B909A")
            ),
            isDark: true
        )
        XCTAssertEqual(theme.background.hexString, "#1e2325")
        XCTAssertEqual(theme.componentBackground.hexString, "#2a3134")
        XCTAssertEqual(theme.selectedBackground.hexString, "#394247")
    }

    func testPerModeBrand() {
        let brand = PaymentConfig.ThemeColor(light: "#1D4ED8", dark: "#436CDF")!
        XCTAssertEqual(resolve(.init(brandColor: brand), isDark: false).primary.hexString, "#1d4ed8")
        XCTAssertEqual(resolve(.init(brandColor: brand), isDark: true).primary.hexString, "#436cdf")
        XCTAssertEqual(resolve(.init(brandColor: brand), isDark: true).textBrand.hexString, "#436cdf")
    }

    func testOverridesAreExact() {
        let theme = resolve(
            .init(overrides: .init(
                onBrandColor: .init(hex: "#111111"),
                textColor: .init(hex: "#222222"),
                borderColor: .init(hex: "#ABCDEF"),
                componentColor: .init(hex: "#EEEEEE")
            )),
            isDark: false
        )
        XCTAssertEqual(theme.primaryButtonText.hexString, "#111111")
        XCTAssertEqual(theme.primaryText.hexString, "#222222")
        XCTAssertEqual(theme.componentBackground.hexString, "#eeeeee")
        XCTAssertEqual(theme.fieldBorder.hexString, "#abcdef")
    }

    func testLowContrastTextColorIsKept() {
        let theme = resolve(
            .init(overrides: .init(textColor: .init(hex: "#FACC15"))),
            isDark: false
        )
        XCTAssertEqual(theme.primaryText.hexString, "#facc15")
        XCTAssertEqual(theme.sheetText.hexString, "#facc15")
    }

    func testLowContrastOverridesStayExact() {
        let yellow = PaymentConfig.ThemeColor(hex: "#FACC15")
        let theme = resolve(
            .init(overrides: .init(
                onBrandColor: yellow,
                textColor: yellow,
                linkColor: yellow,
                borderColor: yellow,
                componentColor: yellow,
                selectedColor: yellow,
                secondaryButtonColor: yellow
            )),
            isDark: false
        )
        XCTAssertEqual(theme.primaryButtonText.hexString, "#facc15")
        XCTAssertEqual(theme.primaryText.hexString, "#facc15")
        XCTAssertEqual(theme.sheetText.hexString, "#facc15")
        XCTAssertEqual(theme.textBrand.hexString, "#facc15")
        XCTAssertEqual(theme.fieldBorder.hexString, "#facc15")
        XCTAssertEqual(theme.componentBackground.hexString, "#facc15")
        XCTAssertEqual(theme.selectedBackground.hexString, "#facc15")
        XCTAssertEqual(theme.secondaryButtonBackground.hexString, "#facc15")
    }

    func testBorderWidthDrivesTheIdleStrokeAndKeepsErrorAndFocusVisible() {
        XCTAssertEqual(resolve(isDark: false).borderWidth, 1, accuracy: 0.001)
        let none = resolve(.init(borders: .init(width: 0)), isDark: false)
        XCTAssertEqual(none.fieldStrokeWidth(hasError: false), 0, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(none.fieldStrokeWidth(hasError: true), 1.5)
        XCTAssertGreaterThanOrEqual(none.fieldStrokeWidth(hasError: false, focused: true), 1.5)
        XCTAssertEqual(none.containerBorderWidth, 0, accuracy: 0.001)
        let wide = resolve(
            .init(overrides: .init(borderColor: .init(hex: "#111111")), borders: .init(width: 2)),
            isDark: false
        )
        XCTAssertEqual(wide.borderWidth, 2, accuracy: 0.001)
        XCTAssertEqual(wide.containerBorderWidth, 2, accuracy: 0.001)
        let hidden = resolve(
            .init(overrides: .init(borderColor: .init(hex: "#111111")), borders: .init(width: 0)),
            isDark: false
        )
        XCTAssertEqual(hidden.containerBorderWidth, 0, accuracy: 0.001)
        XCTAssertEqual(resolve(.init(borders: .init(width: 9)), isDark: false).borderWidth, 4, accuracy: 0.001)
    }

    func testUnusualPalettesKeepGuaranteedContrast() {
        // withContrast stops a hair under its target, and the built-in dark section
        // token (#85858D on #1F1F23) is about 4.49:1. Sheet text, secondary, meta, and the
        // pay label clear 4.5. The lower floors lock that miss without changing it.
        let palettes: [(String, PaymentConfig.Appearance)] = [
            ("near-white brand", .init(brandColor: .init(hex: "#FAFAFA"))),
            ("near-black brand", .init(brandColor: .init(hex: "#16141A"))),
            ("yellow", .init(brandColor: .init(hex: "#FACC15"))),
            ("neon", .init(brandColor: .init(hex: "#00FF00"))),
            ("mid-gray", .init(brandColor: .init(hex: "#808080"))),
            ("white on black", .init(brandColor: .init(hex: "#FFFFFF"), backgroundColor: .init(hex: "#000000"))),
            ("cream", .init(backgroundColor: .init(hex: "#FBF5EA"))),
            ("dark tint on light", .init(backgroundColor: .init(hex: "#FBF5EA"), neutralTint: .init(hex: "#2A2118"))),
        ]
        for (name, appearance) in palettes {
            for isDark in [false, true] {
                for increased in [false, true] {
                    let theme = resolve(appearance, isDark: isDark, increasedContrast: increased)
                    let where_ = "\(name) dark=\(isDark) increased=\(increased)"
                    assertContrast(where_, "sheet text", theme.sheetText, theme.background, 4.5)
                    assertContrast(where_, "secondary", theme.secondaryText, theme.componentBackground, 4.5)
                    assertContrast(where_, "meta", theme.metaText, theme.componentBackground, 4.5)
                    assertContrast(where_, "section", theme.sectionLabelColor, theme.componentBackground, 4.45)
                    assertContrast(where_, "placeholder", theme.placeholderText, theme.componentBackground, 2.95)
                    assertContrast(where_, "or", theme.orLabel, theme.background, 4.45)
                    assertContrast(where_, "disabled pay", theme.primaryButtonDisabledText, theme.primaryButtonDisabledBackground, 4.45)
                    assertContrast(where_, "pay label", theme.primaryButtonText, theme.primaryButtonBackground, 4.5)
                }
            }
        }
    }

    func testWhiteBrandShadowIsSofterAndIncreasedContrastRemovesIt() {
        let white = resolve(.init(brandColor: .init(hex: "#FFFFFF")), isDark: true)
        var alpha: CGFloat = 0
        white.brandShadow.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertEqual(alpha, 0.14, accuracy: 0.01)
        let flat = resolve(.init(brandColor: .init(hex: "#FFFFFF")), isDark: true, increasedContrast: true)
        flat.brandShadow.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertEqual(alpha, 0, accuracy: 0.01)
    }

    func testCornersAtTenAndPillButtons() {
        let theme = resolve(.init(shape: .init(corners: .custom(10))), isDark: false)
        XCTAssertEqual(theme.formFieldRadius, 10, accuracy: 0.001)
        XCTAssertEqual(theme.rowRadius, 8, accuracy: 0.001)
        XCTAssertEqual(theme.checkboxRadius, 5, accuracy: 0.001)
        XCTAssertEqual(theme.paymentContainerRadius, 15, accuracy: 0.001)
        XCTAssertEqual(theme.sheetCornerRadius, 32, accuracy: 0.001)
        XCTAssertEqual(theme.primaryButtonBorderRadius, CheckoutTheme.defaultPrimaryButtonRadius, accuracy: 0.001)
        let square = resolve(.init(shape: .init(corners: .sharp, pillButtons: false)), isDark: false)
        XCTAssertEqual(square.primaryButtonBorderRadius, 0, accuracy: 0.001)
        XCTAssertEqual(square.buttonRadius(forHeight: 52), 0, accuracy: 0.001)
    }

    func testIdleRingsStayTranslucentAndChecksFollowTheLabel() {
        let dark = resolve(isDark: true)
        XCTAssertNotEqual(dark.checkboxRing.hexString, "#fafafa")
        XCTAssertNotEqual(dark.checkboxRing.hexString, dark.primary.hexString)
        XCTAssertEqual(dark.checkboxRing.hexString, dark.radioIdle.hexString)
        XCTAssertEqual(dark.unselectedRing.hexString, dark.radioIdle.hexString)
        XCTAssertEqual(dark.stateIndicatorBorder.hexString, "#fafafa")
        var alpha: CGFloat = 1
        dark.radioIdle.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertEqual(alpha, 0.63, accuracy: 0.02)
        dark.checkboxRing.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertEqual(alpha, 0.63, accuracy: 0.02)
        XCTAssertFalse(dark.filledBrandNeedsOutline)

        let light = resolve(isDark: false)
        light.radioIdle.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertEqual(alpha, 0.80, accuracy: 0.02)
        XCTAssertEqual(light.stateIndicatorBorder.hexString, "#16141a")

        let white = resolve(.init(brandColor: .init(hex: "#FFFFFF")), isDark: true)
        XCTAssertEqual(white.primaryButtonText.hexString, "#16141a")
        white.radioIdle.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertEqual(alpha, 0.63, accuracy: 0.02)

        let blue = resolve(.init(brandColor: .init(hex: "#1D4ED8")), isDark: false)
        XCTAssertEqual(blue.primaryButtonText.hexString, "#ffffff")

        let yellow = resolve(.init(brandColor: .init(hex: "#FACC15")), isDark: false)
        XCTAssertEqual(yellow.primaryButtonText.hexString, "#16141a")
        XCTAssertFalse(yellow.filledBrandNeedsOutline)
    }

    func testDisabledFillIsAnOpaqueComposite() {
        let theme = resolve(.init(brandColor: .init(hex: "#1D4ED8")), isDark: false)
        var alpha: CGFloat = 1
        theme.primaryButtonDisabledBackground.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertEqual(alpha, 1, accuracy: 0.001)
        XCTAssertNotEqual(theme.primaryButtonDisabledBackground.hexString, theme.primary.hexString)
    }

    func testParsingIgnoresUnknownKeysAndClampsCorners() {
        let appearance = PaymentConfig.Appearance.from([
            "brandColor": "#1D4ED8",
            "shape": ["corners": 40, "pillButtons": false, "mystery": true],
            "typography": ["fontFamily": "Georgia"],
            "fontFamily": "Georgia",
            "colorScheme": "dark",
        ])
        XCTAssertEqual(appearance.brandColor?.light.hex, "#1D4ED8")
        XCTAssertEqual(appearance.shape.corners, .custom(24))
        XCTAssertEqual(appearance.typography.fontFamily, "Georgia")
        XCTAssertFalse(appearance.shape.pillButtons)
        XCTAssertEqual(appearance.colorScheme, .dark)
    }

    func testSheetRadiusStaysAtTheDefault() {
        XCTAssertEqual(resolve(.init(shape: .init(corners: .sharp)), isDark: false).sheetCornerRadius, 32, accuracy: 0.001)
        XCTAssertEqual(resolve(.init(shape: .init(corners: .rounded)), isDark: true).sheetCornerRadius, 32, accuracy: 0.001)
    }

    func testBackgroundAloneDoesNotStrokeMethodCards() {
        let theme = resolve(.init(backgroundColor: .init(hex: "#000000")), isDark: true)
        var alpha: CGFloat = 1
        theme.containerBorder.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertEqual(alpha, 0, accuracy: 0.001)
        let stroked = resolve(.init(overrides: .init(borderColor: .init(hex: "#ABCDEF"))), isDark: false)
        stroked.containerBorder.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertGreaterThan(alpha, 0.5)
    }

    func testYellowLinkAndFocusLeaveTheRawBrand() {
        let theme = resolve(.init(brandColor: .init(hex: "#FACC15")), isDark: false)
        XCTAssertEqual(theme.primary.hexString, "#facc15")
        XCTAssertNotEqual(theme.focusRing.hexString, "#facc15")
        XCTAssertEqual(theme.textBrand.hexString, "#facc15")
        XCTAssertEqual(theme.iconBrand.hexString, "#facc15")
        XCTAssertEqual(theme.background.hexString, "#fffcf1")
        XCTAssertEqual(theme.selectedBackground.hexString, "#fffcf1")
        XCTAssertEqual(theme.accentIconBackground.hexString, "#fef7dc")
        let dark = resolve(.init(brandColor: .init(hex: "#FACC15")), isDark: true)
        XCTAssertEqual(dark.primary.hexString, "#facc15")
        XCTAssertEqual(dark.textBrand.hexString, "#fbd53d")
        XCTAssertEqual(dark.iconBrand.hexString, "#fbd53d")
        XCTAssertEqual(dark.background.hexString, "#18181b")
        let teal = resolve(.init(brandColor: .init(hex: "#0F766E")), isDark: true)
        XCTAssertEqual(teal.textBrand.hexString, "#388d87")
        XCTAssertEqual(teal.iconBrand.hexString, "#388d87")
    }

    func testDisabledLabelClearsTheFill() {
        let theme = resolve(isDark: false)
        XCTAssertGreaterThanOrEqual(
            contrast(theme.primaryButtonDisabledText, against: theme.primaryButtonDisabledBackground),
            4.5
        )
    }

    func testWhiteCardInDarkModeUsesDarkFieldText() {
        let theme = resolve(.init(overrides: .init(componentColor: .init(hex: "#FFFFFF"))), isDark: true)
        XCTAssertEqual(theme.componentBackground.hexString, "#ffffff")
        XCTAssertEqual(theme.primaryText.hexString, "#16141a")
        assertCardSideContrast(theme)
        XCTAssertGreaterThanOrEqual(contrast(theme.sheetText, against: theme.background), 4.5)
    }

    func testDarkCardInLightModeKeepsLightSheetText() {
        let theme = resolve(.init(overrides: .init(componentColor: .init(hex: "#16141A"))), isDark: false)
        assertCardSideContrast(theme)
        XCTAssertGreaterThanOrEqual(contrast(theme.sheetText, against: theme.background), 4.5)
        XCTAssertFalse(theme.isDarkSurface)
    }

    func testLightBackgroundUsesTheDarkApplePayStyle() {
        let theme = resolve(.init(backgroundColor: .init(hex: "#FFFFFF")), isDark: true)
        XCTAssertFalse(theme.isDarkSurface)
    }

    func testThemeResolutionVectors() {
        let url = Bundle.module.url(forResource: "test-vectors", withExtension: "json")!
        let root = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let cases = root["themeResolution"] as! [[String: Any]]
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            let appearance = PaymentConfig.Appearance.from(item["appearance"] as? [String: Any])
            let theme = resolve(appearance, isDark: item["isDark"] as! Bool)
            let expected = item["expected"] as! [String: String]
            for (key, value) in expected {
                switch key {
                case "primary":
                    XCTAssertEqual(theme.primary.hexString, value)
                case "background":
                    XCTAssertEqual(theme.background.hexString, value)
                default:
                    XCTFail("unhandled theme vector key \(key)")
                }
            }
            if let brand = (item["appearance"] as? [String: Any])?["brandColor"] as? String, brand.count == 9 {
                let parsed = PaymentConfig.SRGBColor(hex: brand)
                XCTAssertEqual(parsed?.alpha ?? 0, 128.0 / 255.0, accuracy: 0.001)
                XCTAssertEqual(parsed?.red ?? 0, 1, accuracy: 0.001)
            }
        }
        let defaults = root["defaultColors"] as! [String: [String: String]]
        XCTAssertEqual(defaults["light"]?["error"], "#dc2626")
        XCTAssertEqual(defaults["dark"]?["error"], "#ef4444")
        XCTAssertEqual(resolve(isDark: false).errorText.hexString, defaults["light"]?["error"])
        XCTAssertEqual(resolve(isDark: true).errorText.hexString, defaults["dark"]?["error"])
    }

    func testEmptyAppearanceContainerRadiusIs24() {
        XCTAssertEqual(resolve(isDark: false).paymentContainerRadius, 24, accuracy: 0.001)
        XCTAssertEqual(resolve(isDark: true).paymentContainerRadius, 24, accuracy: 0.001)
    }

    func testIncreasedContrastLiftsDefaultMetaText() {
        for isDark in [false, true] {
            let theme = resolve(isDark: isDark, increasedContrast: true)
            XCTAssertGreaterThanOrEqual(contrast(theme.secondaryText, against: theme.selectedBackground), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(theme.placeholderText, against: theme.componentBackground), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(theme.poweredByText, against: theme.background), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(theme.orLabel, against: theme.background), 4.5)
        }
    }

    private func assertContrast(
        _ palette: String,
        _ role: String,
        _ color: UIColor,
        _ surface: UIColor,
        _ minimum: CGFloat
    ) {
        let ratio = contrast(color, against: surface)
        XCTAssertGreaterThanOrEqual(ratio, minimum, "\(palette) \(role) \(ratio)")
    }

    private func assertCardSideContrast(_ theme: CheckoutTheme) {
        XCTAssertGreaterThanOrEqual(contrast(theme.primaryText, against: theme.selectedBackground), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(theme.metaText, against: theme.componentBackground), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(theme.inverseText, against: theme.primaryText), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(theme.textBrand, against: theme.componentBackground), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(theme.focusRing, against: theme.componentBackground), 3)
        XCTAssertGreaterThanOrEqual(contrast(theme.focusRing, against: theme.background), 3)
    }

    private func contrast(_ color: UIColor, against other: UIColor) -> CGFloat {
        func luminance(_ color: UIColor) -> CGFloat {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            func linear(_ channel: CGFloat) -> CGFloat {
                channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
        let lighter = max(luminance(color), luminance(other))
        let darker = min(luminance(color), luminance(other))
        return (lighter + 0.05) / (darker + 0.05)
    }
}

private extension UIColor {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02x%02x%02x", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}
#endif
