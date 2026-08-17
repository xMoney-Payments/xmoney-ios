import UIKit
#if !COCOAPODS
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

    /// xMoney brand purple. Initial session-load coin always uses this — never appearance primary.
    package static let brandPrimary = UIColor(red: 0x7C / 255, green: 0x4D / 255, blue: 0xFF / 255, alpha: 1)
    package let primaryButtonBackground: UIColor
    package let primaryButtonText: UIColor
    package let primaryButtonBorder: UIColor
    package let primaryButtonBorderRadius: CGFloat
    package let primaryButtonBorderWidth: CGFloat

    package let selectedBackground: UIColor
    package let accentIconBackground: UIColor
    package let containerBorder: UIColor
    package let neutralChip: UIColor
    package let fieldBorder: UIColor
    package let fieldDivider: UIColor
    package let mutedIcon: UIColor
    package let unselectedRing: UIColor
    package let errorBorder: UIColor
    package let errorText: UIColor
    package let footerBorder: UIColor

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

    package func font(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let scaled = size * fontScale
        if let fontFamily, let custom = UIFont(name: fontFamily, size: scaled) {
            return custom
        }
        if PaymentFontFamily.isAvailable {
            return PaymentFontFamily.font(weight: weight, size: scaled)
        }
        return .systemFont(ofSize: scaled, weight: weight)
    }

    package func titleAttributes(
        size: CGFloat = 16,
        weight: UIFont.Weight = .bold,
        color: UIColor? = nil
    ) -> [NSAttributedString.Key: Any] {
        let font = self.font(ofSize: size, weight: weight)
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: -0.01 * size * fontScale,
        ]
        if let color {
            attrs[.foregroundColor] = color
        }
        return attrs
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
        let ink = isDark ? Ink.dark : Ink.light

        func color(
            _ key: (PaymentConfig.AppearanceColors) -> String?,
            fallback: UIColor
        ) -> UIColor {
            if let hex = modeColors.flatMap({ key($0) }) ?? sharedColors.flatMap({ key($0) }) {
                return UIColor(hex: hex) ?? fallback
            }
            return fallback
        }

        func inkAlpha(_ alphaByte: Int) -> UIColor {
            ink.withAlphaComponent(CGFloat(alphaByte) / 255.0)
        }

        let pbMode = isDark ? appearance.primaryButton?.colorsDark : appearance.primaryButton?.colorsLight
        let pbShared = appearance.primaryButton?.colors
        let pbShapes = appearance.primaryButton

        let primary = color(\.primary, fallback: defaults.primary)
        let icon = color(\.icon, fallback: defaults.icon)

        let containerBorderOverride: UIColor? = {
            let raw = modeColors?.containerBorder ?? sharedColors?.containerBorder
            guard let raw else { return nil }
            let token = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if token == "none" || token == "transparent" {
                return .clear
            }
            return UIColor(hex: raw)
        }()

        return CheckoutTheme(
            primary: primary,
            background: color(\.background, fallback: defaults.background),
            componentBackground: color(\.componentBackground, fallback: defaults.componentBackground),
            componentBorder: color(\.componentBorder, fallback: defaults.componentBorder),
            componentDivider: color(\.componentDivider, fallback: defaults.componentDivider),
            primaryText: color(\.primaryText, fallback: defaults.primaryText),
            secondaryText: color(\.secondaryText, fallback: defaults.secondaryText),
            componentText: color(\.componentText, fallback: defaults.componentText),
            placeholderText: color(\.placeholderText, fallback: defaults.placeholderText),
            icon: icon,
            error: color(\.error, fallback: defaults.error),
            borderRadius: CGFloat(appearance.borderRadius ?? 8),
            borderWidth: CGFloat(appearance.borderWidth ?? 1),
            fontScale: CGFloat(appearance.fontScale ?? 1),
            fontFamily: appearance.fontFamily,
            primaryButtonBackground: UIColor(hex: pbMode?.background ?? pbShared?.background)
                ?? primary,
            primaryButtonText: UIColor(hex: pbMode?.text ?? pbShared?.text) ?? .white,
            primaryButtonBorder: UIColor(hex: pbMode?.border ?? pbShared?.border)
                ?? primary,
            primaryButtonBorderRadius: CGFloat(pbShapes?.borderRadius ?? 12),
            primaryButtonBorderWidth: CGFloat(pbShapes?.borderWidth ?? 0),
            selectedBackground: primary.withAlphaComponent(CGFloat(0x0F) / 255.0),
            accentIconBackground: primary.withAlphaComponent(CGFloat(0x1F) / 255.0),
            containerBorder: containerBorderOverride ?? inkAlpha(0x17),
            neutralChip: inkAlpha(0x0D),
            fieldBorder: inkAlpha(0x1A),
            fieldDivider: inkAlpha(0x14),
            mutedIcon: isDark ? icon : inkAlpha(0x52),
            unselectedRing: isDark ? inkAlpha(0x66) : inkAlpha(0x29),
            errorBorder: UIColor(hex: "#EF4444")!,
            errorText: UIColor(hex: "#DC2626")!,
            footerBorder: inkAlpha(0x0F),
            sheetCornerRadius: 32,
            paymentContainerRadius: 20,
            rowRadius: 15,
            formFieldRadius: 16,
            brandTileRadius: 9,
            walletButtonHeight: 56,
            formFieldHeight: 54,
            payButtonHeight: 52
        )
    }

    private enum Ink {
        static let light = UIColor(hex: "#16141A")!
        static let dark = UIColor(hex: "#F7F6F9")!
    }

    private enum DefaultColors {
        static let light = Palette(
            primary: UIColor(hex: "#7c4dff")!,
            background: UIColor(hex: "#ffffff")!,
            componentBackground: UIColor(hex: "#ffffff")!,
            componentBorder: UIColor(hex: "#d1cddb")!,
            componentDivider: UIColor(hex: "#d1cddb")!,
            primaryText: UIColor(hex: "#16141a")!,
            secondaryText: UIColor(hex: "#4a4653")!,
            componentText: UIColor(hex: "#4a4653")!,
            placeholderText: UIColor(hex: "#797585")!,
            icon: UIColor(hex: "#797585")!,
            error: UIColor(hex: "#ff6b6b")!
        )
        static let dark = Palette(
            primary: UIColor(hex: "#7c4dff")!,
            background: UIColor(hex: "#16141a")!,
            componentBackground: UIColor(hex: "#201e25")!,
            componentBorder: UIColor(hex: "#3f3b48")!,
            componentDivider: UIColor(hex: "#3f3b48")!,
            primaryText: UIColor(hex: "#f7f6f9")!,
            secondaryText: UIColor(hex: "#d1cddb")!,
            componentText: UIColor(hex: "#d1cddb")!,
            placeholderText: UIColor(hex: "#797585")!,
            icon: UIColor(hex: "#797585")!,
            error: UIColor(hex: "#ff6b6b")!
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

    convenience init?(hex: String?) {
        guard var hex = hex?.trimmingCharacters(in: .whitespaces) else { return nil }
        hex = hex.replacingOccurrences(of: "#", with: "")
        if hex.count == 8 {
            guard let value = UInt64(hex, radix: 16) else { return nil }
            self.init(
                red: CGFloat((value >> 24) & 0xFF) / 255.0,
                green: CGFloat((value >> 16) & 0xFF) / 255.0,
                blue: CGFloat((value >> 8) & 0xFF) / 255.0,
                alpha: CGFloat(value & 0xFF) / 255.0
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
