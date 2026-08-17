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
        XCTAssertEqual(theme.fontScale, 1.25, accuracy: 0.001)
        XCTAssertEqual(theme.borderRadius, 12, accuracy: 0.001)
        XCTAssertEqual(theme.borderWidth, 2, accuracy: 0.001)
        XCTAssertEqual(theme.primaryButtonBorderRadius, 8, accuracy: 0.001)
        XCTAssertEqual(theme.primaryButtonBorderWidth, 1, accuracy: 0.001)
    }

    func testSelectedWashesDeriveFromPrimary() {
        let theme = resolve(appearance: ["colors": ["primary": "#0E7C66"]], isDark: false)
        let primary = color("#0E7C66")
        XCTAssertEqual(theme.selectedBackground.hexRGBA, primary.withAlphaComponent(0x0F / 255.0).hexRGBA)
        XCTAssertEqual(theme.accentIconBackground.hexRGBA, primary.withAlphaComponent(0x1F / 255.0).hexRGBA)
    }

    func testContainerBorderNoneIsTransparent() {
        let theme = resolve(appearance: ["colors": ["containerBorder": "none"]], isDark: false)
        XCTAssertEqual(theme.containerBorder.cgColor.alpha, 0, accuracy: 0.001)
        XCTAssertEqual(theme.containerBorderWidth, 0)
    }

    func testContainerBorderDefaultsMatchAndroidInkAlphas() {
        let light = resolve(isDark: false)
        let lightInk = color("#16141A")
        XCTAssertEqual(light.containerBorder.hexRGBA, lightInk.withAlphaComponent(0x17 / 255.0).hexRGBA)
        XCTAssertEqual(light.footerBorder.hexRGBA, lightInk.withAlphaComponent(0x0F / 255.0).hexRGBA)
        XCTAssertEqual(light.fieldBorder.hexRGBA, lightInk.withAlphaComponent(0x1A / 255.0).hexRGBA)
        XCTAssertEqual(light.fieldDivider.hexRGBA, lightInk.withAlphaComponent(0x14 / 255.0).hexRGBA)
        XCTAssertEqual(light.mutedIcon.hexRGBA, lightInk.withAlphaComponent(0x52 / 255.0).hexRGBA)
        XCTAssertEqual(light.unselectedRing.hexRGBA, lightInk.withAlphaComponent(0x29 / 255.0).hexRGBA)

        let dark = resolve(isDark: true)
        let darkInk = color("#F7F6F9")
        XCTAssertEqual(dark.containerBorder.hexRGBA, darkInk.withAlphaComponent(0x17 / 255.0).hexRGBA)
        XCTAssertEqual(dark.footerBorder.hexRGBA, darkInk.withAlphaComponent(0x0F / 255.0).hexRGBA)
        XCTAssertEqual(dark.mutedIcon.hexRGBA, color("#797585").hexRGBA)
        XCTAssertEqual(dark.unselectedRing.hexRGBA, darkInk.withAlphaComponent(0x66 / 255.0).hexRGBA)
    }

    func testLegacyAliasesMatchAndroidNames() {
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
