import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

package struct CheckoutTheme {
    package let primary: UIColor
    package let background: UIColor
    package let componentBackground: UIColor
    package let componentBorder: UIColor
    package let componentDivider: UIColor
    package let primaryText: UIColor
    package let secondaryText: UIColor
    package let componentText: UIColor
    package let placeholderText: UIColor
    package let icon: UIColor
    package let error: UIColor
    package let borderRadius: CGFloat
    package let borderWidth: CGFloat
    package let fontScale: CGFloat
    package let fontFamily: String?
    package let primaryButtonFontFamily: String?

    /// xMoney brand purple. Initial session-load coin always uses this — never appearance primary.
    package static let brandPrimary = UIColor(red: 0x7C / 255, green: 0x4D / 255, blue: 0xFF / 255, alpha: 1)
    package static let defaultFormFieldRadius: CGFloat = 16
    package static let defaultPaymentContainerRadius: CGFloat = 16
    package static let defaultPrimaryButtonRadius: CGFloat = 9999
    private static let defaultErrorBorder = UIColor(hex: "#EF4444")!
    private static let defaultErrorText = UIColor(hex: "#DC2626")!
    package let primaryButtonBackground: UIColor
    package let primaryButtonText: UIColor
    package let primaryButtonBorder: UIColor
    package let primaryButtonBorderRadius: CGFloat
    package let primaryButtonBorderWidth: CGFloat

    package let isDark: Bool
    package let selectedBackground: UIColor
    package let accentIconBackground: UIColor
    package let containerBorder: UIColor
    package let neutralChip: UIColor
    package let fieldBorder: UIColor
    package let fieldDivider: UIColor
    package let mutedIcon: UIColor
    package let unselectedRing: UIColor
    package let checkboxRing: UIColor
    package let errorBorder: UIColor
    package let errorText: UIColor
    package let footerBorder: UIColor
    package let grabber: UIColor
    package let brandTileBackground: UIColor
    package let brandTileBorder: UIColor
    package let visaTint: UIColor?
    package let orDivider: UIColor
    package let orLabel: UIColor
    package let poweredByText: UIColor
    package let poweredByLogo: UIColor
    package let scrim: UIColor

    package let sheetCornerRadius: CGFloat
    package let paymentContainerRadius: CGFloat
    package let rowRadius: CGFloat
    package let formFieldRadius: CGFloat
    package let brandTileRadius: CGFloat
    package let walletButtonHeight: CGFloat
    package let formFieldHeight: CGFloat
    package let payButtonHeight: CGFloat

    package var containerBorderWidth: CGFloat {
        var a: CGFloat = 0
        containerBorder.getRed(nil, green: nil, blue: nil, alpha: &a)
        return a < 0.01 ? 0 : 1
    }

    package var selectionTint: UIColor { selectedBackground }
    package var subtleBorder: UIColor { containerBorder }
    package var hairline: UIColor { footerBorder }
    package var errorTextStrong: UIColor { errorText }
    package var containerRadius: CGFloat { paymentContainerRadius }
    package var fieldGroupRadius: CGFloat { formFieldRadius }
    package var fieldRowHeight: CGFloat { formFieldHeight }

    /// Empty-field color shared by card and personal-details inputs.
    package var inputPlaceholder: UIColor {
        isDark ? (UIColor(hex: "#6E6878") ?? placeholderText) : (UIColor(hex: "#D1CDDB") ?? placeholderText)
    }

    /// Secondary row copy (saved-card meta, powered-by).
    package var metaText: UIColor {
        isDark ? secondaryText : (UIColor(hex: "#9691A3") ?? secondaryText)
    }

    /// Section labels such as "Card details" and "Contact info".
    package var sectionLabelColor: UIColor {
        isDark ? secondaryText : (UIColor(hex: "#797585") ?? icon)
    }

    /// Unselected radio fill. Checked radios use `primary` with a white dot.
    package var radioIdle: UIColor {
        isDark ? unselectedRing : (UIColor(hex: "#DED4FF") ?? unselectedRing)
    }

    package func fieldStrokeWidth(hasError: Bool) -> CGFloat {
        hasError ? max(borderWidth, 1.5) : borderWidth
    }

    package func font(
        ofSize size: CGFloat,
        weight: UIFont.Weight = .regular,
        family: String? = nil
    ) -> UIFont {
        let scaled = size * fontScale
        let name = family ?? fontFamily
        if let name, let custom = UIFont(name: name, size: scaled) {
            return custom
        }
        if PaymentFontFamily.isAvailable {
            return PaymentFontFamily.font(weight: weight, size: scaled)
        }
        return .systemFont(ofSize: scaled, weight: weight)
    }

    package func payFont(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        font(ofSize: size, weight: weight, family: primaryButtonFontFamily)
    }

    /// Figma type-scale line heights; sizes outside the scale keep the font's natural height.
    package static func lineHeight(forSize size: CGFloat) -> CGFloat? {
        switch size {
        case 10, 12, 14: return 16
        case 16, 18: return 24
        default: return nil
        }
    }

    /// Text attributes with -1% tracking and the Figma line height for `size`.
    /// Pass `lineBreakMode: .byWordWrapping` for multi-line labels; a truncating mode
    /// in the paragraph style collapses a UILabel to a single line.
    package func titleAttributes(
        size: CGFloat = 16,
        weight: UIFont.Weight = .bold,
        color: UIColor? = nil,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        alignment: NSTextAlignment = .natural,
        family: String? = nil,
        lineHeight: CGFloat? = nil
    ) -> [NSAttributedString.Key: Any] {
        let font = self.font(ofSize: size, weight: weight, family: family)
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: -0.01 * size * fontScale,
        ]
        if let lineHeight = lineHeight ?? Self.lineHeight(forSize: size) {
            let scaled = lineHeight * fontScale
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = scaled
            paragraph.maximumLineHeight = scaled
            paragraph.lineBreakMode = lineBreakMode
            paragraph.alignment = alignment
            attrs[.paragraphStyle] = paragraph
            attrs[.baselineOffset] = (scaled - font.lineHeight) / 4
        }
        if let color {
            attrs[.foregroundColor] = color
        }
        return attrs
    }

    /// Applies `titleAttributes` to `label` so it picks up tracking and line height.
    package func style(
        _ label: UILabel,
        text: String,
        size: CGFloat,
        weight: UIFont.Weight,
        color: UIColor,
        multiline: Bool = false,
        alignment: NSTextAlignment = .natural,
        lineHeight: CGFloat? = nil
    ) {
        label.numberOfLines = multiline ? 0 : 1
        label.attributedText = NSAttributedString(
            string: text,
            attributes: titleAttributes(
                size: size,
                weight: weight,
                color: color,
                lineBreakMode: multiline ? .byWordWrapping : .byTruncatingTail,
                alignment: alignment,
                lineHeight: lineHeight
            )
        )
    }

    package var text: UIColor { primaryText }
    package var fieldBackground: UIColor { componentBackground }
    package var border: UIColor { componentBorder }
    package var cornerRadius: CGFloat { borderRadius }

    package static func resolve(config: PaymentConfig, isDark: Bool) -> CheckoutTheme {
        let appearance = config.options.appearance
        let defaults = isDark ? DefaultColors.dark : DefaultColors.light
        let modeColors = isDark ? appearance.colorsDark : appearance.colorsLight
        let sharedColors = appearance.colors

        func color(
            _ key: (PaymentConfig.AppearanceColors) -> String?,
            fallback: UIColor
        ) -> UIColor {
            if let hex = modeColors.flatMap({ key($0) }) ?? sharedColors.flatMap({ key($0) }) {
                return UIColor(hex: hex) ?? fallback
            }
            return fallback
        }

        func optionalColor(
            _ key: (PaymentConfig.AppearanceColors) -> String?,
            fallback: UIColor
        ) -> UIColor {
            let raw = modeColors.flatMap({ key($0) }) ?? sharedColors.flatMap({ key($0) })
            guard let raw else { return fallback }
            let token = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if token == "none" || token == "transparent" {
                return .clear
            }
            return UIColor(hex: raw) ?? fallback
        }

        let ink = isDark ? Ink.dark : Ink.light
        func inkAlpha(_ alphaByte: Int) -> UIColor {
            ink.withAlphaComponent(CGFloat(alphaByte) / 255.0)
        }
        func chromeAlpha(_ alphaByte: Int) -> UIColor {
            (isDark ? Ink.darkChrome : ink).withAlphaComponent(CGFloat(alphaByte) / 255.0)
        }

        let pbMode = isDark ? appearance.primaryButton?.colorsDark : appearance.primaryButton?.colorsLight
        let pbShared = appearance.primaryButton?.colors
        let pbShapes = appearance.primaryButton

        let primary = color(\.primary, fallback: defaults.primary)
        let icon = color(\.icon, fallback: defaults.icon)
        let background = color(\.background, fallback: defaults.background)
        let componentBackground = color(\.componentBackground, fallback: defaults.componentBackground)
        let primaryText = color(\.primaryText, fallback: defaults.primaryText)
        let secondaryText = color(\.secondaryText, fallback: defaults.secondaryText)
        let footerBorder = chromeAlpha(isDark ? 0x14 : 0x0F)

        return CheckoutTheme(
            primary: primary,
            background: background,
            componentBackground: componentBackground,
            componentBorder: color(\.componentBorder, fallback: defaults.componentBorder),
            componentDivider: color(\.componentDivider, fallback: defaults.componentDivider),
            primaryText: primaryText,
            secondaryText: secondaryText,
            componentText: color(\.componentText, fallback: defaults.componentText),
            placeholderText: color(\.placeholderText, fallback: defaults.placeholderText),
            icon: icon,
            error: color(\.error, fallback: defaults.error),
            borderRadius: CGFloat(appearance.borderRadius ?? Double(Self.defaultFormFieldRadius)),
            borderWidth: CGFloat(appearance.borderWidth ?? 1),
            fontScale: CGFloat(appearance.fontScale ?? 1),
            fontFamily: appearance.fontFamily,
            primaryButtonFontFamily: appearance.primaryButton?.fontFamily ?? appearance.fontFamily,
            primaryButtonBackground: UIColor(hex: pbMode?.background ?? pbShared?.background)
                ?? primary,
            primaryButtonText: UIColor(hex: pbMode?.text ?? pbShared?.text) ?? .white,
            primaryButtonBorder: UIColor(hex: pbMode?.border ?? pbShared?.border)
                ?? primary,
            primaryButtonBorderRadius: CGFloat(pbShapes?.borderRadius ?? Self.defaultPrimaryButtonRadius),
            primaryButtonBorderWidth: CGFloat(pbShapes?.borderWidth ?? 0),
            isDark: isDark,
            selectedBackground: isDark
                ? primary.withAlphaComponent(CGFloat(0x2E) / 255.0)
                : UIColor(hex: "#F7F6FF")!,
            accentIconBackground: isDark
                ? primary.withAlphaComponent(CGFloat(0x3D) / 255.0)
                : UIColor(hex: "#ECE5FF")!,
            containerBorder: optionalColor(\.containerBorder, fallback: isDark ? inkAlpha(0x17) : .clear),
            neutralChip: inkAlpha(0x0D),
            fieldBorder: color(\.componentBorder, fallback: isDark ? inkAlpha(0x1A) : UIColor(hex: "#E3E1E8")!),
            fieldDivider: color(\.componentDivider, fallback: isDark ? inkAlpha(0x14) : UIColor(hex: "#E3E1E8")!),
            mutedIcon: isDark ? icon : inkAlpha(0x52),
            unselectedRing: isDark ? chromeAlpha(0x33) : inkAlpha(0x29),
            checkboxRing: chromeAlpha(isDark ? 0x3D : 0x33),
            errorBorder: color(\.error, fallback: Self.defaultErrorBorder),
            errorText: color(\.error, fallback: Self.defaultErrorText),
            footerBorder: footerBorder,
            grabber: isDark ? chromeAlpha(0x29) : UIColor(hex: "#E3E1E8")!,
            brandTileBackground: isDark ? UIColor(hex: "#1F1F23")! : componentBackground,
            brandTileBorder: isDark ? chromeAlpha(0x1F) : UIColor(hex: "#EFEEF1")!,
            visaTint: isDark ? .white : nil,
            orDivider: isDark ? chromeAlpha(0x1A) : UIColor(hex: "#E3E1E8")!,
            orLabel: isDark ? secondaryText.withAlphaComponent(0.40) : UIColor(hex: "#797585")!,
            poweredByText: isDark ? secondaryText.withAlphaComponent(0.30) : UIColor(hex: "#9691A3")!,
            poweredByLogo: isDark ? secondaryText.withAlphaComponent(0.42) : UIColor(hex: "#9691A3")!,
            scrim: isDark
                ? UIColor.black.withAlphaComponent(0.60)
                : Ink.light.withAlphaComponent(0.45),
            sheetCornerRadius: 32,
            paymentContainerRadius: CGFloat(
                appearance.borderRadius ?? Double(Self.defaultPaymentContainerRadius)
            ),
            rowRadius: 12,
            formFieldRadius: CGFloat(
                appearance.borderRadius ?? Double(Self.defaultFormFieldRadius)
            ),
            brandTileRadius: 9,
            walletButtonHeight: 52,
            formFieldHeight: 48,
            payButtonHeight: 52
        )
    }

    private enum Ink {
        static let light = UIColor(hex: "#16141A")!
        static let dark = UIColor(hex: "#F7F6F9")!
        static let darkChrome = UIColor.white
    }

    private enum DefaultColors {
        static let light = Palette(
            primary: UIColor(hex: "#7C4DFF")!,
            background: UIColor(hex: "#F7F6FF")!,
            componentBackground: UIColor(hex: "#FFFFFF")!,
            componentBorder: UIColor(hex: "#D1CDDB")!,
            componentDivider: UIColor(hex: "#D1CDDB")!,
            primaryText: UIColor(hex: "#16141A")!,
            secondaryText: UIColor(hex: "#4A4653")!,
            componentText: UIColor(hex: "#4A4653")!,
            placeholderText: UIColor(hex: "#797585")!,
            icon: UIColor(hex: "#797585")!,
            error: UIColor(hex: "#FF6B6B")!
        )
        static let dark = Palette(
            primary: UIColor(hex: "#7C4DFF")!,
            background: UIColor(hex: "#18181B")!,
            componentBackground: UIColor(hex: "#18181B")!,
            componentBorder: UIColor(hex: "#3F3B48")!,
            componentDivider: UIColor(hex: "#3F3B48")!,
            primaryText: UIColor(hex: "#F7F6F9")!,
            secondaryText: UIColor(hex: "#D1CDDB")!,
            componentText: UIColor(hex: "#D1CDDB")!,
            placeholderText: UIColor(hex: "#797585")!,
            icon: UIColor(hex: "#797585")!,
            error: UIColor(hex: "#FF6B6B")!
        )
    }

    private struct Palette {
        let primary: UIColor
        let background: UIColor
        let componentBackground: UIColor
        let componentBorder: UIColor
        let componentDivider: UIColor
        let primaryText: UIColor
        let secondaryText: UIColor
        let componentText: UIColor
        let placeholderText: UIColor
        let icon: UIColor
        let error: UIColor
    }
}

extension UIColor {
    var resolvedLuminance: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    package convenience init?(hex: String?) {
        guard var hex = hex?.trimmingCharacters(in: .whitespaces) else { return nil }
        hex = hex.replacingOccurrences(of: "#", with: "")
        if hex.count == 8 {
            guard let value = UInt64(hex, radix: 16) else { return nil }
            // AARRGGBB — same as Android CheckoutTheme.parseColor.
            self.init(
                red: CGFloat((value >> 16) & 0xFF) / 255.0,
                green: CGFloat((value >> 8) & 0xFF) / 255.0,
                blue: CGFloat(value & 0xFF) / 255.0,
                alpha: CGFloat((value >> 24) & 0xFF) / 255.0
            )
            return
        }
        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255.0,
            green: CGFloat((value >> 8) & 0xFF) / 255.0,
            blue: CGFloat(value & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
