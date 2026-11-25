import XCTest
@testable import XMoneyPaymentSheet
import XMoneyCore

#if canImport(UIKit)
final class ThemeResolutionTests: XCTestCase {
    private struct ThemeCase: Decodable {
        let isDark: Bool
        let appearance: [String: AppearanceValue]
        let expected: [String: String]
    }

    private enum AppearanceValue: Decodable {
        case string(String)
        case object([String: String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = .string(string)
                return
            }
            self = .object(try container.decode([String: String].self))
        }
    }

    private struct Vectors: Decodable {
        let themeResolution: [ThemeCase]
    }

    private lazy var vectors: Vectors = {
        let url = Bundle.module.url(forResource: "test-vectors", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(Vectors.self, from: data)
    }()

    private func resolve(appearance: [String: Any] = [:], isDark: Bool) -> CheckoutTheme {
        let config = PaymentConfig(
            publicKey: "pk_test",
            options: .init(appearance: PaymentConfig.AppearanceConfig.from(appearance))
        )
        return CheckoutTheme.resolve(config: config, isDark: isDark)
    }

    func testThemeResolutionVectors() throws {
        for vector in vectors.themeResolution {
            let appearance = vector.appearance.mapValues { value -> Any in
                switch value {
                case let .string(string):
                    return string
                case let .object(object):
                    return object
                }
            }
            let theme = resolve(appearance: appearance, isDark: vector.isDark)
            for (key, hex) in vector.expected {
                let actual: UIColor
                switch key {
                case "primary": actual = theme.primary
                case "background": actual = theme.background
                case "error": actual = theme.error
                default: XCTFail("Unsupported key \(key)"); continue
                }
                XCTAssertEqual(actual.hexString, hex.lowercased(), "key \(key)")
            }
        }
    }

    func testNestedFontAndShapesReachTheme() {
        let theme = resolve(
            appearance: [
                "font": ["family": "Inter", "scale": 1.25],
                "shapes": ["borderRadius": 12, "borderWidth": 2],
                "primaryButton": [
                    "font": ["family": "Roobert"],
                    "shapes": ["borderRadius": 8, "borderWidth": 1],
                ],
            ],
            isDark: false
        )
        XCTAssertEqual(theme.fontFamily, "Inter")
        XCTAssertEqual(theme.primaryButtonFontFamily, "Roobert")
        XCTAssertEqual(theme.fontScale, 1.25, accuracy: 0.001)
        XCTAssertEqual(theme.borderRadius, 12, accuracy: 0.001)
        XCTAssertEqual(theme.borderWidth, 2, accuracy: 0.001)
        XCTAssertEqual(theme.formFieldRadius, 12, accuracy: 0.001)
        XCTAssertEqual(theme.paymentContainerRadius, CheckoutTheme.defaultPaymentContainerRadius, accuracy: 0.001)
        XCTAssertEqual(theme.primaryButtonBorderRadius, 8, accuracy: 0.001)
        XCTAssertEqual(theme.primaryButtonBorderWidth, 1, accuracy: 0.001)
    }

    func testOmittedBorderRadiusKeepsBrandedFieldAndContainerDefaults() {
        let theme = resolve(isDark: false)
        XCTAssertEqual(theme.formFieldRadius, CheckoutTheme.defaultFormFieldRadius, accuracy: 0.001)
        XCTAssertEqual(theme.borderRadius, CheckoutTheme.defaultFormFieldRadius, accuracy: 0.001)
        XCTAssertEqual(theme.paymentContainerRadius, CheckoutTheme.defaultPaymentContainerRadius, accuracy: 0.001)
        XCTAssertEqual(theme.borderWidth, 1, accuracy: 0.001)
        XCTAssertEqual(theme.fieldStrokeWidth(hasError: false), 1, accuracy: 0.001)
        XCTAssertEqual(theme.fieldStrokeWidth(hasError: true), 1.5, accuracy: 0.001)
    }

    func testAppearanceShapesReachFieldsAndContainer() {
        let theme = resolve(
            appearance: ["shapes": ["borderRadius": 4, "borderWidth": 2.5]],
            isDark: false
        )
        XCTAssertEqual(theme.formFieldRadius, 4, accuracy: 0.001)
        XCTAssertEqual(theme.paymentContainerRadius, CheckoutTheme.defaultPaymentContainerRadius, accuracy: 0.001)
        XCTAssertEqual(theme.rowRadius, CheckoutTheme.defaultRowRadius, accuracy: 0.001)
        XCTAssertEqual(theme.borderWidth, 2.5, accuracy: 0.001)
        XCTAssertEqual(theme.fieldStrokeWidth(hasError: false), 2.5, accuracy: 0.001)
        XCTAssertEqual(theme.fieldStrokeWidth(hasError: true), 2.5, accuracy: 0.001)
    }

    func testButtonRadiusFollowsPrimaryButtonShape() {
        XCTAssertEqual(resolve(isDark: false).buttonRadius(forHeight: 48), 24, accuracy: 0.001)
        let square = resolve(appearance: ["primaryButton": ["shapes": ["borderRadius": 0]]], isDark: false)
        XCTAssertEqual(square.buttonRadius(forHeight: 48), 0, accuracy: 0.001)
        let rounded = resolve(appearance: ["primaryButton": ["shapes": ["borderRadius": 8]]], isDark: false)
        XCTAssertEqual(rounded.buttonRadius(forHeight: 52), 8, accuracy: 0.001)
    }

    func testZeroBorderWidthStillShowsErrorRing() {
        let theme = resolve(
            appearance: ["shapes": ["borderWidth": 0]],
            isDark: false
        )
        XCTAssertEqual(theme.fieldStrokeWidth(hasError: false), 0, accuracy: 0.001)
        XCTAssertEqual(theme.fieldStrokeWidth(hasError: true), 1.5, accuracy: 0.001)
    }

    func testErrorColorOverridesFieldErrorChrome() {
        let theme = resolve(
            appearance: ["colors": ["error": "#00AA55"]],
            isDark: false
        )
        let error = color("#00AA55")
        XCTAssertEqual(theme.errorBorder.hexString, error.hexString)
        XCTAssertEqual(theme.errorText.hexString, error.hexString)
    }

    func testOmittedErrorKeepsBrandedFieldChrome() {
        let theme = resolve(isDark: false)
        XCTAssertEqual(theme.errorBorder.hexString, "#dc2626")
        XCTAssertEqual(theme.errorText.hexString, "#dc2626")
        XCTAssertEqual(theme.errorBadge.hexString, "#dc2626")
    }

    func testPrimaryButtonFontFallsBackToAppearanceFont() {
        let theme = resolve(
            appearance: ["font": ["family": "Inter"]],
            isDark: false
        )
        XCTAssertEqual(theme.fontFamily, "Inter")
        XCTAssertEqual(theme.primaryButtonFontFamily, "Inter")
    }

    func testSelectedWashesDeriveFromPrimary() {
        let theme = resolve(appearance: ["colors": ["primary": "#0E7C66"]], isDark: false)
        let primary = color("#0E7C66")
        XCTAssertEqual(theme.selectedBackground.hexRGBA, primary.withAlphaComponent(0x0F / 255.0).hexRGBA)
        XCTAssertEqual(theme.accentIconBackground.hexRGBA, primary.withAlphaComponent(0x1F / 255.0).hexRGBA)
        XCTAssertEqual(theme.radioIdle.hexRGBA, theme.unselectedRing.hexRGBA)
        XCTAssertEqual(theme.textBrand.hexRGBA, primary.hexRGBA)
        XCTAssertEqual(theme.iconBrand.hexRGBA, primary.hexRGBA)

        let dark = resolve(appearance: ["colors": ["primary": "#0E7C66"]], isDark: true)
        XCTAssertEqual(dark.selectedBackground.hexRGBA, primary.withAlphaComponent(0x2E / 255.0).hexRGBA)
        XCTAssertEqual(dark.accentIconBackground.hexRGBA, primary.withAlphaComponent(0x3D / 255.0).hexRGBA)
    }

    func testOmittedPrimaryKeepsBrandedWashes() {
        let theme = resolve(isDark: false)
        XCTAssertEqual(theme.selectedBackground.hexString, "#f7f6ff")
        XCTAssertEqual(theme.accentIconBackground.hexString, "#ece5ff")
        XCTAssertEqual(theme.radioIdle.hexRGBA, color("#7C4DFF").withAlphaComponent(CGFloat(0xCC) / 255.0).hexRGBA)
        XCTAssertEqual(theme.textBrand.hexString, "#7a4bfb")
        XCTAssertEqual(theme.iconBrand.hexString, "#7c4dff")
    }

    func testSecondaryTextOverridesSecondaryCopy() {
        let theme = resolve(appearance: ["colors": ["secondaryText": "#335577"]], isDark: false)
        let secondary = color("#335577")
        XCTAssertEqual(theme.metaText.hexString, secondary.hexString)
        XCTAssertEqual(theme.sectionLabelColor.hexString, secondary.hexString)
        XCTAssertEqual(theme.orLabel.hexRGBA, secondary.withAlphaComponent(0.40).hexRGBA)
        XCTAssertEqual(theme.poweredByText.hexRGBA, secondary.withAlphaComponent(0.30).hexRGBA)
        XCTAssertEqual(theme.poweredByLogo.hexRGBA, secondary.withAlphaComponent(0.42).hexRGBA)
    }

    func testOmittedSecondaryTextKeepsBrandedCopy() {
        let theme = resolve(isDark: false)
        XCTAssertEqual(theme.metaText.hexString, "#63606d")
        XCTAssertEqual(theme.sectionLabelColor.hexString, "#6b6779")
        XCTAssertEqual(theme.orLabel.hexString, "#63606d")
        XCTAssertEqual(theme.poweredByText.hexString, "#9691a3")
    }

    func testPlaceholderTextOverridesInputPlaceholder() {
        let light = resolve(appearance: ["colors": ["placeholderText": "#AA3300"]], isDark: false)
        XCTAssertEqual(light.inputPlaceholder.hexString, color("#AA3300").hexString)
        let dark = resolve(appearance: ["colorsDark": ["placeholderText": "#00AA33"]], isDark: true)
        XCTAssertEqual(dark.inputPlaceholder.hexString, color("#00AA33").hexString)

        XCTAssertEqual(resolve(isDark: false).inputPlaceholder.hexString, "#9691a3")
        XCTAssertEqual(resolve(isDark: true).inputPlaceholder.hexString, "#69696f")
    }

    func testInverseTextContrastsWithPrimaryText() {
        XCTAssertEqual(resolve(isDark: false).inverseText.hexString, "#f7f6ff")
        XCTAssertEqual(resolve(isDark: true).inverseText.hexString, "#09090b")
        let custom = resolve(
            appearance: ["colors": ["primaryText": "#FFFFFF", "background": "#FFFFFF"]],
            isDark: false
        )
        XCTAssertEqual(custom.inverseText.hexString, "#16141a")
    }

    func testDangerTintsUseErrorRedAtFixedAlphas() {
        let wash = color("#EF4444")
        let light = resolve(isDark: false)
        XCTAssertEqual(light.dangerTint.hexRGBA, wash.withAlphaComponent(0.08).hexRGBA)
        XCTAssertEqual(light.dangerTintStrong.hexRGBA, wash.withAlphaComponent(0.09).hexRGBA)
        let dark = resolve(isDark: true)
        XCTAssertEqual(dark.dangerTint.hexRGBA, wash.withAlphaComponent(0.15).hexRGBA)
        XCTAssertEqual(dark.dangerTintStrong.hexRGBA, wash.withAlphaComponent(0.30).hexRGBA)
        let overridden = resolve(appearance: ["colors": ["error": "#00AA55"]], isDark: false)
        XCTAssertEqual(overridden.dangerTint.hexRGBA, light.dangerTint.hexRGBA)
        XCTAssertEqual(overridden.errorBorder.hexString, "#00aa55")
    }

    func testEightDigitHexIsARGBMatchingAndroid() {
        let parsed = UIColor(hex: "#1FFFFFFF")
        XCTAssertNotNil(parsed)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        parsed?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1, accuracy: 0.01)
        XCTAssertEqual(g, 1, accuracy: 0.01)
        XCTAssertEqual(b, 1, accuracy: 0.01)
        XCTAssertEqual(a, CGFloat(0x1F) / 255.0, accuracy: 0.01)

        let theme = resolve(
            appearance: ["colorsDark": ["componentBorder": "#1FFFFFFF", "containerBorder": "#1FFFFFFF"]],
            isDark: true
        )
        XCTAssertEqual(theme.componentBorder.hexRGBA, "#1fffffff")
        XCTAssertEqual(theme.containerBorder.hexRGBA, "#1fffffff")
    }

    func testContainerBorderNoneIsTransparent() {
        let theme = resolve(appearance: ["colors": ["containerBorder": "none"]], isDark: false)
        XCTAssertEqual(theme.containerBorder.cgColor.alpha, 0, accuracy: 0.001)
        XCTAssertEqual(theme.containerBorderWidth, 0)
    }

    func testComponentBorderOverridesFieldBorder() {
        let theme = resolve(
            appearance: ["colors": ["componentBorder": "#AABBCC"]],
            isDark: false
        )
        XCTAssertEqual(theme.fieldBorder.hexString, color("#AABBCC").hexString)
    }

    func testComponentDividerOverridesFieldDivider() {
        let theme = resolve(
            appearance: ["colors": ["componentDivider": "#112233"]],
            isDark: false
        )
        XCTAssertEqual(theme.fieldDivider.hexString, color("#112233").hexString)
    }

    func testContainerBorderDefaultsUseInkAlphas() {
        let light = resolve(isDark: false)
        let lightInk = color("#16141A")
        XCTAssertEqual(light.containerBorder.cgColor.alpha, 0, accuracy: 0.001)
        XCTAssertEqual(light.footerBorder.hexRGBA, lightInk.withAlphaComponent(0x0F / 255.0).hexRGBA)
        XCTAssertEqual(light.fieldBorder.hexString, "#e3e1e8")
        XCTAssertEqual(light.fieldDivider.hexString, "#e3e1e8")
        XCTAssertEqual(light.mutedIcon.hexString, "#9691a3")
        XCTAssertEqual(light.unselectedRing.hexRGBA, lightInk.withAlphaComponent(0x29 / 255.0).hexRGBA)
        XCTAssertEqual(light.orDivider.hexString, "#e3e1e8")
        XCTAssertEqual(light.grabber.hexString, "#e3e1e8")
        XCTAssertEqual(light.background.hexString, "#f7f6ff")
        XCTAssertEqual(light.componentBorder.hexString, "#d1cddb")
        XCTAssertEqual(light.componentDivider.hexString, "#d1cddb")
        XCTAssertEqual(light.primaryButtonBorderRadius, CheckoutTheme.defaultPrimaryButtonRadius, accuracy: 0.001)
        XCTAssertEqual(light.errorText.hexString, "#dc2626")
        XCTAssertEqual(light.errorBorder.hexString, "#dc2626")
        XCTAssertEqual(light.formFieldRadius, CheckoutTheme.defaultFormFieldRadius, accuracy: 0.001)
        XCTAssertEqual(light.paymentContainerRadius, CheckoutTheme.defaultPaymentContainerRadius, accuracy: 0.001)
        XCTAssertEqual(light.rowRadius, CheckoutTheme.defaultRowRadius, accuracy: 0.001)
        XCTAssertEqual(light.brandTileRadius, CheckoutTheme.defaultBrandTileRadius, accuracy: 0.001)
        XCTAssertNil(light.visaTint)

        let dark = resolve(isDark: true)
        let darkInk = color("#F7F6F9")
        let white = UIColor.white
        XCTAssertEqual(dark.background.hexString, "#18181b")
        XCTAssertEqual(dark.componentBackground.hexString, "#1f1f23")
        XCTAssertEqual(dark.primaryText.hexString, "#fafafa")
        XCTAssertEqual(dark.componentBorder.hexString, "#3f3b48")
        XCTAssertEqual(dark.containerBorder.hexRGBA, darkInk.withAlphaComponent(0x17 / 255.0).hexRGBA)
        XCTAssertEqual(dark.footerBorder.hexRGBA, white.withAlphaComponent(0x14 / 255.0).hexRGBA)
        XCTAssertEqual(dark.fieldBorder.hexRGBA, white.withAlphaComponent(0x1A / 255.0).hexRGBA)
        XCTAssertEqual(dark.fieldDivider.hexRGBA, white.withAlphaComponent(0x1A / 255.0).hexRGBA)
        XCTAssertEqual(dark.mutedIcon.hexString, "#69696f")
        XCTAssertEqual(dark.unselectedRing.hexRGBA, white.withAlphaComponent(0x33 / 255.0).hexRGBA)
        XCTAssertEqual(dark.checkboxRing.hexRGBA, white.withAlphaComponent(0x3D / 255.0).hexRGBA)
        XCTAssertEqual(dark.grabber.hexRGBA, white.withAlphaComponent(0x1A / 255.0).hexRGBA)
        XCTAssertEqual(dark.orDivider.hexRGBA, white.withAlphaComponent(0x1A / 255.0).hexRGBA)
        XCTAssertEqual(dark.selectedBackground.hexString, "#2a2a2f")
        XCTAssertEqual(dark.accentIconBackground.hexString, "#24124c")
        XCTAssertEqual(dark.textBrand.hexString, "#926bff")
        XCTAssertEqual(dark.poweredByText.hexString, "#605c70")
        XCTAssertEqual(dark.errorText.hexString, "#ef4444")
        XCTAssertEqual(dark.errorBadge.hexString, "#dc2626")
        XCTAssertEqual(dark.neutralChip.hexRGBA, darkInk.withAlphaComponent(0x0D / 255.0).hexRGBA)
        XCTAssertEqual(dark.errorBorder.hexString, "#ef4444")
        XCTAssertEqual(dark.visaTint?.hexString, "#ffffff")
        XCTAssertEqual(dark.brandTileBackground.hexString, "#1f1f23")
        XCTAssertEqual(dark.scrim.hexRGBA, UIColor.black.withAlphaComponent(0.60).hexRGBA)
    }

    func testLegacyThemeAliasesMatchCanonicalNames() {
        let theme = resolve(isDark: false)
        XCTAssertEqual(theme.subtleBorder.hexRGBA, theme.containerBorder.hexRGBA)
        XCTAssertEqual(theme.hairline.hexRGBA, theme.footerBorder.hexRGBA)
        XCTAssertEqual(theme.selectionTint.hexRGBA, theme.selectedBackground.hexRGBA)
        XCTAssertEqual(theme.errorTextStrong.hexRGBA, theme.errorText.hexRGBA)
        XCTAssertEqual(theme.containerRadius, theme.paymentContainerRadius)
        XCTAssertEqual(theme.fieldGroupRadius, theme.formFieldRadius)
        XCTAssertEqual(theme.fieldRowHeight, theme.formFieldHeight)
    }

    private func color(_ hex: String) -> UIColor {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        let value = Int(cleaned, radix: 16) ?? 0
        return UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

private extension UIColor {
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    var hexRGBA: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "#%02x%02x%02x%02x",
            Int((a * 255).rounded()),
            Int((r * 255).rounded()),
            Int((g * 255).rounded()),
            Int((b * 255).rounded())
        )
    }
}
#endif
