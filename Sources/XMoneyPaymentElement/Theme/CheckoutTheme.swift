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
    package static let defaultPaymentContainerRadius: CGFloat = 24
    package static let defaultRowRadius: CGFloat = 16
    package static let defaultBrandTileRadius: CGFloat = 12
    package static let defaultPrimaryButtonRadius: CGFloat = 9999
    /// `kyc-status-danger-solid`. The "!" badge keeps this in both themes.
    private static let defaultErrorBadge = UIColor(hex: "#DC2626")!
    private static let defaultErrorTextLight = UIColor(hex: "#DC2626")!
    private static let defaultErrorTextDark = UIColor(hex: "#EF4444")!
    package let primaryButtonBackground: UIColor
    package let primaryButtonText: UIColor
    package let primaryButtonPressed: UIColor
    package let primaryButtonDisabledBackground: UIColor
    package let primaryButtonDisabledText: UIColor
    package let primaryButtonBorder: UIColor
    package let primaryButtonBorderRadius: CGFloat
    package let primaryButtonBorderWidth: CGFloat
    package let secondaryButtonBackground: UIColor
    package let secondaryButtonText: UIColor
    package let focusRing: UIColor
    package let stateIndicatorBorder: UIColor
    package let checkboxRadius: CGFloat
    package let brandShadow: UIColor

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

    /// Empty personal-details fields. Card placeholders use `metaText`.
    package let inputPlaceholder: UIColor
    /// Tertiary copy: "or", "Visa or Mastercard", empty card fields, "Card details".
    package let metaText: UIColor
    /// Muted copy: saved-card header and meta, crypto subtitle, personal-details headings.
    package let sectionLabelColor: UIColor
    /// Unselected radio and checkbox stroke. Translucent, so it composites on the card.
    package let radioIdle: UIColor
    /// Brand-coloured labels such as Edit and "Use another card".
    package let textBrand: UIColor
    /// Plus, chevron, and the crypto glyph.
    package let iconBrand: UIColor
    /// Fill of the error "!" badge (`kyc-status-danger-solid`).
    package let errorBadge: UIColor
    /// `#EF4444` wash behind a card being removed and its confirm panel.
    package let dangerTint: UIColor
    /// Stronger `#EF4444` wash behind the trash button.
    package let dangerTintStrong: UIColor
    /// Text on the "Keep it" pill. The KYC inverse token, unless the merchant sets `primaryText`.
    package let inverseText: UIColor
    /// Text drawn on the sheet. Stays readable when field text follows a flipped card.
    package let sheetText: UIColor
    /// The resolved sheet is dark, independent of the color-scheme flag.
    package let isDarkSurface: Bool

    /** Low-contrast brands stay the brand color. The ink outline is not drawn. */
    package var filledBrandNeedsOutline: Bool { false }

    /// Close and back icons sit on the sheet. Field text can follow a lighter card.
    package var sheetChromeText: UIColor { sheetText }

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

    /// Corner radius for any button, following `primaryButton.borderRadius` so every button shares one shape.
    package func buttonRadius(forHeight height: CGFloat) -> CGFloat {
        min(max(primaryButtonBorderRadius, 0), height / 2)
    }

    package func fieldStrokeWidth(hasError: Bool) -> CGFloat {
        hasError ? max(borderWidth, 1.5) : borderWidth
    }

    package func font(
        ofSize size: CGFloat,
        weight: UIFont.Weight = .regular,
        family: String? = nil
    ) -> UIFont {
        let scaled = UIFontMetrics(forTextStyle: .body).scaledValue(for: size)
        let name = family ?? fontFamily
        if let name {
            if let custom = Self.font(inFamily: name, size: scaled, weight: weight) {
                return custom
            }
            AppearanceLog.warn("font family '\(name)' is not registered")
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
            .kern: fontFamily == nil ? -0.01 * size : 0,
        ]
        if let lineHeight = lineHeight ?? Self.lineHeight(forSize: size) {
            let scaled = UIFontMetrics(forTextStyle: .body).scaledValue(for: lineHeight)
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
        label.adjustsFontForContentSizeCategory = true
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

    package static func font(inFamily family: String, size: CGFloat, weight: UIFont.Weight) -> UIFont? {
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: family,
            .traits: [UIFontDescriptor.TraitKey.weight: weight],
        ])
        let font = UIFont(descriptor: descriptor, size: size)
        let matches = font.familyName.caseInsensitiveCompare(family) == .orderedSame
            || font.fontName.caseInsensitiveCompare(family) == .orderedSame
        if matches { return font }
        return UIFont(name: family, size: size)
    }

    private static func contrast(_ color: UIColor, against other: UIColor) -> CGFloat {
        func luminance(_ color: UIColor) -> CGFloat {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return 0 }
            func linear(_ channel: CGFloat) -> CGFloat {
                channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
        let lighter = max(luminance(color), luminance(other))
        let darker = min(luminance(color), luminance(other))
        return (lighter + 0.05) / (darker + 0.05)
    }

    package static func resolve(
        config: PaymentConfig,
        isDark: Bool,
        contentSizeScale: CGFloat = 1,
        increasedContrast: Bool = false
    ) -> CheckoutTheme {
        let tokens = ThemeDerivation.resolve(
            appearance: config.options.appearance,
            isDark: isDark,
            contentSizeScale: contentSizeScale,
            increasedContrast: increasedContrast
        )
        return CheckoutTheme(
            primary: tokens.primary,
            background: tokens.background,
            componentBackground: tokens.componentBackground,
            componentBorder: tokens.componentBorder,
            componentDivider: tokens.componentDivider,
            primaryText: tokens.primaryText,
            secondaryText: tokens.secondaryText,
            componentText: tokens.componentText,
            placeholderText: tokens.placeholderText,
            icon: tokens.icon,
            error: tokens.error,
            borderRadius: tokens.borderRadius,
            borderWidth: tokens.borderWidth,
            fontScale: contentSizeScale,
            fontFamily: tokens.fontFamily,
            primaryButtonFontFamily: tokens.fontFamily,
            primaryButtonBackground: tokens.primaryButtonBackground,
            primaryButtonText: tokens.primaryButtonText,
            primaryButtonPressed: tokens.primaryButtonPressed,
            primaryButtonDisabledBackground: tokens.primaryButtonDisabledBackground,
            primaryButtonDisabledText: tokens.primaryButtonDisabledText,
            primaryButtonBorder: tokens.primaryButtonBorder,
            primaryButtonBorderRadius: tokens.primaryButtonBorderRadius,
            primaryButtonBorderWidth: 0,
            secondaryButtonBackground: tokens.secondaryButtonBackground,
            secondaryButtonText: tokens.secondaryButtonText,
            focusRing: tokens.focusRing,
            stateIndicatorBorder: tokens.stateIndicatorBorder,
            checkboxRadius: tokens.checkboxRadius,
            brandShadow: tokens.brandShadow,
            isDark: isDark,
            selectedBackground: tokens.selectedBackground,
            accentIconBackground: tokens.accentIconBackground,
            containerBorder: tokens.containerBorder,
            neutralChip: tokens.neutralChip,
            fieldBorder: tokens.fieldBorder,
            fieldDivider: tokens.fieldDivider,
            mutedIcon: tokens.mutedIcon,
            unselectedRing: tokens.unselectedRing,
            checkboxRing: tokens.checkboxRing,
            errorBorder: tokens.errorBorder,
            errorText: tokens.errorText,
            footerBorder: tokens.footerBorder,
            grabber: tokens.grabber,
            brandTileBackground: tokens.brandTileBackground,
            brandTileBorder: tokens.brandTileBorder,
            visaTint: tokens.visaTint,
            orDivider: tokens.orDivider,
            orLabel: tokens.orLabel,
            poweredByText: tokens.poweredByText,
            poweredByLogo: tokens.poweredByLogo,
            scrim: tokens.scrim,
            sheetCornerRadius: tokens.sheetCornerRadius,
            paymentContainerRadius: tokens.paymentContainerRadius,
            rowRadius: tokens.rowRadius,
            formFieldRadius: tokens.formFieldRadius,
            brandTileRadius: tokens.brandTileRadius,
            walletButtonHeight: tokens.walletButtonHeight,
            formFieldHeight: tokens.formFieldHeight,
            payButtonHeight: tokens.payButtonHeight,
            inputPlaceholder: tokens.inputPlaceholder,
            metaText: tokens.metaText,
            sectionLabelColor: tokens.sectionLabelColor,
            radioIdle: tokens.radioIdle,
            textBrand: tokens.textBrand,
            iconBrand: tokens.iconBrand,
            errorBadge: tokens.errorBadge,
            dangerTint: tokens.dangerTint,
            dangerTintStrong: tokens.dangerTintStrong,
            inverseText: tokens.inverseText,
            sheetText: tokens.sheetText,
            isDarkSurface: tokens.isDarkSurface
        )
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
