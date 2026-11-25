import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

/// Turns `PaymentConfig.Appearance` into the colors and radii the checkout paints.
enum ThemeDerivation {
    struct Tokens {
        var primary: UIColor
        var background: UIColor
        var componentBackground: UIColor
        var componentBorder: UIColor
        var componentDivider: UIColor
        var primaryText: UIColor
        var secondaryText: UIColor
        var componentText: UIColor
        var placeholderText: UIColor
        var icon: UIColor
        var error: UIColor
        var borderRadius: CGFloat
        var borderWidth: CGFloat
        var fontFamily: String?
        var primaryButtonBackground: UIColor
        var primaryButtonText: UIColor
        var primaryButtonPressed: UIColor
        var primaryButtonDisabledBackground: UIColor
        var primaryButtonDisabledText: UIColor
        var primaryButtonBorder: UIColor
        var primaryButtonBorderRadius: CGFloat
        var secondaryButtonBackground: UIColor
        var secondaryButtonText: UIColor
        var selectedBackground: UIColor
        var accentIconBackground: UIColor
        var containerBorder: UIColor
        var neutralChip: UIColor
        var fieldBorder: UIColor
        var fieldDivider: UIColor
        var mutedIcon: UIColor
        var unselectedRing: UIColor
        var checkboxRing: UIColor
        var errorBorder: UIColor
        var errorText: UIColor
        var footerBorder: UIColor
        var grabber: UIColor
        var brandTileBackground: UIColor
        var brandTileBorder: UIColor
        var visaTint: UIColor?
        var orDivider: UIColor
        var orLabel: UIColor
        var poweredByText: UIColor
        var poweredByLogo: UIColor
        var scrim: UIColor
        var sheetCornerRadius: CGFloat
        var paymentContainerRadius: CGFloat
        var rowRadius: CGFloat
        var formFieldRadius: CGFloat
        var brandTileRadius: CGFloat
        var checkboxRadius: CGFloat
        var walletButtonHeight: CGFloat
        var formFieldHeight: CGFloat
        var payButtonHeight: CGFloat
        var inputPlaceholder: UIColor
        var metaText: UIColor
        var sectionLabelColor: UIColor
        var radioIdle: UIColor
        var textBrand: UIColor
        var iconBrand: UIColor
        var errorBadge: UIColor
        var dangerTint: UIColor
        var dangerTintStrong: UIColor
        var inverseText: UIColor
        var focusRing: UIColor
        var stateIndicatorBorder: UIColor
        var brandShadow: UIColor
        var sheetText: UIColor
        var isDarkSurface: Bool
    }

    static func resolve(
        appearance: PaymentConfig.Appearance,
        isDark: Bool,
        contentSizeScale: CGFloat = 1,
        increasedContrast: Bool = false
    ) -> Tokens {
        // Order: surfaces, derived roles, exact overrides, then shape (typography, borders, shape).
        let brand = appearance.brandColor?.resolved(isDark: isDark) ?? Defaults.brand
        let accent = appearance.accentColor?.resolved(isDark: isDark) ?? brand
        let customBrand = appearance.brandColor != nil
        let backdrop = appearance.backgroundColor?.resolved(isDark: isDark)
        let tint = appearance.neutralTint?.resolved(isDark: isDark)
        let lifted = isDark && backdrop != nil && tint != nil
        let sheet: PaymentConfig.SRGBColor
        if lifted, let backdrop, let tint {
            sheet = tint.mixed(over: backdrop, weight: ThemeConstants.sheetOverBackdropDark)
        } else if let backdrop {
            sheet = backdrop
        } else if isDark {
            sheet = Defaults.darkSheet
        } else if customBrand {
            sheet = brand.mixed(over: .white, weight: ThemeConstants.lightSurfaceBrandTint)
        } else {
            sheet = Defaults.lightSheet
        }
        let customSurface = appearance.backgroundColor != nil || tint != nil

        let derivedCard = customSurface
            ? (isDark
                ? (lifted
                    ? tint!.mixed(over: backdrop!, weight: ThemeConstants.cardOverBackdropDark)
                    : (tint ?? Defaults.darkGray).mixed(over: sheet, weight: ThemeConstants.cardOverSheetDark))
                : PaymentConfig.SRGBColor.white.mixed(over: sheet, weight: ThemeConstants.cardOverSheetLight))
            : (isDark ? Defaults.darkCard : Defaults.lightCard)
        let card = exact(appearance.overrides.componentColor?.resolved(isDark: isDark), fallback: derivedCard)

        let cardIsDark = card.relativeLuminance <= 0.5
        let sheetIsDark = sheet.relativeLuminance < 0.5
        let cardNeedsOwnInk = appearance.overrides.textColor == nil
            && (appearance.overrides.componentColor != nil || cardIsDark != sheetIsDark)
        let toneDark = cardNeedsOwnInk ? cardIsDark : isDark
        func gray(forDark dark: Bool) -> PaymentConfig.SRGBColor {
            tint ?? (dark ? Defaults.darkGray : Defaults.lightGray)
        }
        let derivedSelected = customSurface
            ? (toneDark
                ? (lifted
                    ? tint!.mixed(over: backdrop!, weight: ThemeConstants.selectedOverBackdropDark)
                    : gray(forDark: true).mixed(over: sheet, weight: ThemeConstants.selectedOverSheetDark))
                : gray(forDark: false).mixed(over: card, weight: ThemeConstants.selectedOverCardLight))
            : (toneDark ? Defaults.darkSelected : (customBrand ? sheet : Defaults.lightSelected))
        let selected = exact(appearance.overrides.selectedColor?.resolved(isDark: isDark), fallback: derivedSelected)

        let sentText = appearance.overrides.textColor?.resolved(isDark: isDark)
        let derivedSheet = customSurface
            ? bestInk(on: sheet)
            : (isDark ? Defaults.darkText : Defaults.lightText)
        let readableSheet = derivedSheet.contrast(against: sheet) >= 4.5 ? derivedSheet : bestInk(on: sheet)
        let sheetText = exact(sentText, fallback: readableSheet)
        let primaryText = cardNeedsOwnInk ? bestInk(on: card) : sheetText
        warnContrast("textColor", color: sentText, on: [sheet, card], minimum: 4.5)

        let graySeed = gray(forDark: toneDark)
        let sheetGray = gray(forDark: sheetIsDark)
        let grayTarget: (Double) -> Double = { increasedContrast ? 7 : $0 }
        func increasedDefault(
            _ color: PaymentConfig.SRGBColor,
            against surface: PaymentConfig.SRGBColor
        ) -> PaymentConfig.SRGBColor {
            guard increasedContrast else { return color }
            return color.withContrast(atLeast: 4.6, against: surface)
        }
        let secondary = customSurface
            ? graySeed.withContrast(atLeast: grayTarget(toneDark ? 6.41 : 7), against: selected)
            : increasedDefault(toneDark ? Defaults.darkSecondary : Defaults.lightSecondary, against: selected)
        let tertiary = customSurface
            ? graySeed.withContrast(atLeast: grayTarget(5.5), against: card)
            : (toneDark ? Defaults.darkTertiary : Defaults.lightTertiary)
        let muted = customSurface
            ? graySeed.withContrast(atLeast: grayTarget(4.5), against: card)
            : (toneDark ? Defaults.darkMuted : Defaults.lightMuted)
        let placeholder = customSurface
            ? graySeed.withContrast(atLeast: grayTarget(3), against: card)
            : increasedDefault(toneDark ? Defaults.darkPlaceholder : Defaults.lightPlaceholder, against: card)
        let powered = customSurface
            ? sheetGray.withContrast(atLeast: grayTarget(3), against: sheet)
            : increasedDefault(sheetIsDark ? Defaults.darkPowered : Defaults.lightPowered, against: sheet)
        let orLabelColor = customSurface
            ? sheetGray.withContrast(atLeast: grayTarget(4.5), against: sheet)
            : increasedDefault(sheetIsDark ? Defaults.darkTertiary : Defaults.lightTertiary, against: sheet)

        let onBrand = exact(appearance.overrides.onBrandColor?.resolved(isDark: isDark), fallback: bestLabel(on: brand))
        warnContrast("onBrandColor", color: appearance.overrides.onBrandColor?.resolved(isDark: isDark), on: [brand], minimum: 4.5)

        let linkSource = appearance.accentColor ?? appearance.brandColor
        let hasDistinctDark = linkSource.map { $0.light != $0.dark } ?? false
        let paintedAccent = (isDark && (customBrand || appearance.accentColor != nil) && !hasDistinctDark)
            ? PaymentConfig.SRGBColor.white.mixed(over: accent, weight: ThemeConstants.darkLinkTowardWhite)
            : accent
        let derivedLink = customBrand || appearance.accentColor != nil
            ? paintedAccent
            : ((cardNeedsOwnInk ? cardIsDark : isDark) ? Defaults.darkLink : Defaults.lightLink)
        let linkBase = exact(appearance.overrides.linkColor?.resolved(isDark: isDark), fallback: derivedLink)
        let linkSeed = appearance.overrides.linkColor == nil
            && !(customBrand || appearance.accentColor != nil)
            && cardNeedsOwnInk
            ? linkBase.withContrast(atLeast: 4.5, against: card)
            : linkBase
        warnContrast("linkColor", color: appearance.overrides.linkColor?.resolved(isDark: isDark), on: [sheet, card], minimum: 4.5)

        let derivedBorder = customSurface
            ? (tint ?? graySeed).withAlpha(toneDark ? ThemeConstants.borderAlphaDark : ThemeConstants.borderAlphaLight)
            : (toneDark ? Defaults.darkBorder : Defaults.lightBorder)
        let border = exact(appearance.overrides.borderColor?.resolved(isDark: isDark), fallback: derivedBorder)
        if let sent = appearance.overrides.borderColor?.resolved(isDark: isDark), sent.alpha > 0.01 {
            let onSheet = sent.contrast(against: sheet, compositedOver: sheet)
            let onCard = sent.contrast(against: card, compositedOver: card)
            if onSheet < 3 && onCard < 3 {
                AppearanceLog.warn("borderColor is below 3:1 where it is used as a state indicator")
            }
        }

        let errorBase = toneDark ? Defaults.darkError : Defaults.lightError
        let error = customSurface || appearance.overrides.componentColor != nil
            ? errorBase.withContrast(atLeast: 4.5, against: card)
            : errorBase
        let focus = meeting(accent, minimum: 3, on: [sheet, card])
        var idleRing = uncheckedRing(accent: accent, isDark: sheetIsDark)
        if idleRing.contrast(against: card, compositedOver: card) < 3 {
            idleRing = uncheckedRing(accent: accent, isDark: cardIsDark)
        }
        if idleRing.contrast(against: card, compositedOver: card) < 3 {
            AppearanceLog.warn("idle ring is below 3:1 on the card")
        }

        let pressed = brand.mixed(over: onBrand, weight: 1 - ThemeConstants.pressedTowardLabel)
        let disabledFill = brand.withAlpha(ThemeConstants.disabledFillAlpha).composited(over: sheet)
        let disabledText = onBrand.withContrast(atLeast: 4.5, against: disabledFill)

        let derivedSecondary = toneDark
            ? brand.withAlpha(ThemeConstants.secondaryOverCardDark).composited(over: card)
            : brand.mixed(over: sheet, weight: ThemeConstants.secondaryOverSheetLight)
        let secondaryFill = exact(
            appearance.overrides.secondaryButtonColor?.resolved(isDark: isDark),
            fallback: derivedSecondary
        )
        let secondaryLabel = linkSeed.withContrast(atLeast: 4.5, against: secondaryFill)

        let subtle = customBrand
            ? (toneDark
                ? brand.mixed(over: .black, weight: 0.28)
                : brand.mixed(over: .white, weight: ThemeConstants.lightIconChipBrand))
            : (toneDark ? Defaults.darkSubtle : Defaults.lightSubtle)
        let shadowAlpha = increasedContrast ? 0 : (brand.isAchromatic ? ThemeConstants.achromaticShadow : ThemeConstants.brandShadow)
        let radii = radii(for: appearance)
        let scale = max(contentSizeScale, 1)
        let builtInBrand = appearance.brandColor == nil && appearance.accentColor == nil
        let builtInCard = appearance.overrides.componentColor == nil && !customSurface
        let builtInIcon = toneDark ? Defaults.darkLink : Defaults.brand
        let icon = builtInBrand
            ? (cardNeedsOwnInk ? builtInIcon.withContrast(atLeast: 4.5, against: card) : builtInIcon)
            : paintedAccent
        let inverse = appearance.overrides.textColor != nil || customSurface || cardNeedsOwnInk
            ? bestInk(on: primaryText)
            : (isDark ? Defaults.darkInverse : Defaults.lightSheet)

        func ui(_ color: PaymentConfig.SRGBColor) -> UIColor { UIColor(color) }

        return Tokens(
            primary: ui(brand),
            background: ui(sheet),
            componentBackground: ui(card),
            componentBorder: ui(border),
            componentDivider: ui(border),
            primaryText: ui(primaryText),
            secondaryText: ui(secondary),
            componentText: ui(secondary),
            placeholderText: ui(placeholder),
            icon: ui(placeholder),
            error: ui(error),
            borderRadius: radii.field,
            borderWidth: CGFloat(min(max(appearance.borders.width, 0), 4)),
            fontFamily: appearance.typography.fontFamily,
            primaryButtonBackground: ui(brand),
            primaryButtonText: ui(onBrand),
            primaryButtonPressed: ui(pressed),
            primaryButtonDisabledBackground: ui(disabledFill),
            primaryButtonDisabledText: ui(disabledText),
            primaryButtonBorder: ui(brand),
            primaryButtonBorderRadius: radii.button,
            secondaryButtonBackground: ui(secondaryFill),
            secondaryButtonText: ui(secondaryLabel),
            selectedBackground: ui(selected),
            accentIconBackground: ui(subtle),
            containerBorder: appearance.overrides.borderColor == nil ? .clear : ui(border),
            neutralChip: ui((tint ?? graySeed).withAlpha(isDark ? 0.40 : 0.20).composited(over: sheet)),
            fieldBorder: ui(border),
            fieldDivider: ui(border),
            mutedIcon: ui(placeholder),
            unselectedRing: ui(idleRing),
            checkboxRing: ui(idleRing),
            errorBorder: ui(error),
            errorText: ui(error),
            footerBorder: ui((sheetIsDark ? PaymentConfig.SRGBColor.white : PaymentConfig.SRGBColor.ink).withAlpha(sheetIsDark ? 0.08 : 0.06)),
            grabber: ui(border),
            brandTileBackground: builtInCard ? ui(.white) : ui(card),
            brandTileBorder: ui(border),
            visaTint: toneDark && !builtInCard ? .white : nil,
            orDivider: ui(border),
            orLabel: ui(orLabelColor),
            poweredByText: ui(powered),
            poweredByLogo: ui(powered),
            scrim: sheetIsDark ? UIColor.black.withAlphaComponent(0.60) : UIColor(PaymentConfig.SRGBColor.ink).withAlphaComponent(0.40),
            sheetCornerRadius: radii.sheet,
            paymentContainerRadius: radii.container,
            rowRadius: radii.row,
            formFieldRadius: radii.field,
            brandTileRadius: radii.tile,
            checkboxRadius: radii.checkbox,
            walletButtonHeight: 52 * scale,
            formFieldHeight: 48 * scale,
            payButtonHeight: 52 * scale,
            inputPlaceholder: ui(placeholder),
            metaText: ui(tertiary),
            sectionLabelColor: ui(muted),
            radioIdle: ui(idleRing),
            textBrand: ui(linkSeed),
            iconBrand: ui(icon),
            errorBadge: UIColor(Defaults.errorBadge),
            dangerTint: UIColor(Defaults.dangerWash).withAlphaComponent(isDark ? 0.15 : 0.08),
            dangerTintStrong: UIColor(Defaults.dangerWash).withAlphaComponent(isDark ? 0.30 : 0.09),
            inverseText: ui(inverse),
            focusRing: ui(focus),
            stateIndicatorBorder: ui(sheetIsDark ? PaymentConfig.SRGBColor.paper : PaymentConfig.SRGBColor.ink),
            brandShadow: UIColor(brand).withAlphaComponent(shadowAlpha),
            sheetText: ui(sheetText),
            isDarkSurface: sheetIsDark
        )
    }

    /// A set override is painted as sent. The derived color is used only when the override is nil.
    private static func exact(
        _ sent: PaymentConfig.SRGBColor?,
        fallback: PaymentConfig.SRGBColor
    ) -> PaymentConfig.SRGBColor {
        sent ?? fallback
    }

    /// Smallest change that clears `minimum` on every surface.
    private static func meeting(
        _ color: PaymentConfig.SRGBColor,
        minimum: Double,
        on surfaces: [PaymentConfig.SRGBColor]
    ) -> PaymentConfig.SRGBColor {
        var current = color
        for _ in 0..<3 {
            guard let worst = surfaces.min(by: {
                current.contrast(against: $0) < current.contrast(against: $1)
            }) else { return current }
            if current.contrast(against: worst) >= minimum { return current }
            let next = current.withContrast(atLeast: minimum, against: worst)
            if next.red == current.red, next.green == current.green, next.blue == current.blue { return current }
            current = next
        }
        return current
    }

    /// Idle checkbox and radio stroke. Alpha stays so the ring composites on the card, not the sheet.
    private static func uncheckedRing(
        accent: PaymentConfig.SRGBColor,
        isDark: Bool
    ) -> PaymentConfig.SRGBColor {
        if isDark {
            return accent.mixed(over: .white, weight: 0.72).withAlpha(0.63)
        }
        return accent.withAlpha(0.80)
    }

    private static func bestInk(on surface: PaymentConfig.SRGBColor) -> PaymentConfig.SRGBColor {
        PaymentConfig.SRGBColor.ink.contrast(against: surface) >= PaymentConfig.SRGBColor.paper.contrast(against: surface)
            ? .ink : .paper
    }

    private static func bestLabel(on fill: PaymentConfig.SRGBColor) -> PaymentConfig.SRGBColor {
        PaymentConfig.SRGBColor.white.contrast(against: fill) >= PaymentConfig.SRGBColor.ink.contrast(against: fill)
            ? .white : .ink
    }

    private static func warnContrast(
        _ name: String,
        color: PaymentConfig.SRGBColor?,
        on surfaces: [PaymentConfig.SRGBColor],
        minimum: Double
    ) {
        guard let color else { return }
        if color.alpha < 0.99 {
            AppearanceLog.warn("\(name) is transparent")
        }
        if surfaces.contains(where: { color.contrast(against: $0) < minimum }) {
            AppearanceLog.warn("\(name) is below \(minimum):1 on a surface where it appears")
        }
    }

    private struct Radii {
        var button: CGFloat
        var field: CGFloat
        var row: CGFloat
        var container: CGFloat
        var sheet: CGFloat
        var checkbox: CGFloat
        var tile: CGFloat
    }

    private static func radii(for appearance: PaymentConfig.Appearance) -> Radii {
        let scale = appearance.shape.corners.scale
        let control = interpolate(0, 12, 24, scale: scale)
        let field = interpolate(0, 16, 24, scale: scale)
        let container = interpolate(0, 24, 32, scale: scale)
        let sheet: CGFloat = 32
        let checkbox = interpolate(0, 8, 12, scale: scale)
        let inset: CGFloat = 8
        let row: CGFloat
        if container >= 16 {
            row = max(8, min(field, container - inset))
        } else {
            row = min(control, container)
        }
        let button = appearance.shape.pillButtons ? CheckoutTheme.defaultPrimaryButtonRadius : control
        return Radii(
            button: button,
            field: field,
            row: row,
            container: container,
            sheet: sheet,
            checkbox: checkbox,
            tile: control
        )
    }

    private static func interpolate(_ sharp: Double, _ regular: Double, _ rounded: Double, scale: Double) -> CGFloat {
        let value: Double
        if scale <= 16 {
            value = sharp + (regular - sharp) * (scale / 16)
        } else {
            value = regular + (rounded - regular) * ((scale - 16) / 8)
        }
        return CGFloat(value.rounded())
    }
}

enum ThemeConstants {
    /// Dark extended theme: neutral tint mixed over the raw background.
    static let sheetOverBackdropDark = 0.24
    static let cardOverBackdropDark = 0.34
    static let selectedOverBackdropDark = 0.46
    static let cardOverSheetDark = 0.24
    static let cardOverSheetLight = 0.75
    static let selectedOverSheetDark = 0.36
    static let selectedOverCardLight = 0.12
    static let borderAlphaDark = 0.30
    static let borderAlphaLight = 0.25
    static let secondaryOverSheetLight = 0.15
    static let secondaryOverCardDark = 0.16
    static let pressedTowardLabel = 0.12
    static let disabledFillAlpha = 0.40
    static let brandShadow = 0.30
    static let achromaticShadow = 0.14
    /// Brand mixed over white for the light sheet and selected row.
    static let lightSurfaceBrandTint = 0.06
    /// Brand mixed over white for the light plus and details chips.
    static let lightIconChipBrand = 0.15
    /// Dark links and icons move this far toward white when no dark brand is set.
    static let darkLinkTowardWhite = 0.17
}

private enum Defaults {
    static let brand = PaymentConfig.SRGBColor(hex: "#7C4DFF")!
    static let lightSheet = PaymentConfig.SRGBColor(hex: "#F7F6FF")!
    static let darkSheet = PaymentConfig.SRGBColor(hex: "#18181B")!
    static let darkInverse = PaymentConfig.SRGBColor(hex: "#09090B")!
    static let lightCard = PaymentConfig.SRGBColor(hex: "#FFFFFF")!
    static let darkCard = PaymentConfig.SRGBColor(hex: "#1F1F23")!
    static let lightText = PaymentConfig.SRGBColor(hex: "#16141A")!
    static let darkText = PaymentConfig.SRGBColor(hex: "#FAFAFA")!
    static let lightLink = PaymentConfig.SRGBColor(hex: "#7A4BFB")!
    static let darkLink = PaymentConfig.SRGBColor(hex: "#926BFF")!
    static let lightSubtle = PaymentConfig.SRGBColor(hex: "#ECE5FF")!
    static let darkSubtle = PaymentConfig.SRGBColor(hex: "#24124C")!
    static let lightSelected = PaymentConfig.SRGBColor(hex: "#F7F6FF")!
    static let darkSelected = PaymentConfig.SRGBColor(hex: "#2A2A2F")!
    static let lightSecondary = PaymentConfig.SRGBColor(hex: "#4A4653")!
    static let darkSecondary = PaymentConfig.SRGBColor(hex: "#D1CDDB")!
    static let lightTertiary = PaymentConfig.SRGBColor(hex: "#63606D")!
    static let darkTertiary = PaymentConfig.SRGBColor(hex: "#95959D")!
    static let lightMuted = PaymentConfig.SRGBColor(hex: "#6B6779")!
    static let darkMuted = PaymentConfig.SRGBColor(hex: "#85858D")!
    static let lightPlaceholder = PaymentConfig.SRGBColor(hex: "#9691A3")!
    static let darkPlaceholder = PaymentConfig.SRGBColor(hex: "#69696F")!
    static let lightPowered = PaymentConfig.SRGBColor(hex: "#9691A3")!
    static let darkPowered = PaymentConfig.SRGBColor(hex: "#605C70")!
    static let lightBorder = PaymentConfig.SRGBColor(hex: "#E3E1E8")!
    static let darkBorder = PaymentConfig.SRGBColor.white.withAlpha(0x1A / 255)
    static let lightGray = PaymentConfig.SRGBColor(hex: "#9691A3")!
    static let darkGray = PaymentConfig.SRGBColor(hex: "#8A868F")!
    static let lightError = PaymentConfig.SRGBColor(hex: "#DC2626")!
    static let darkError = PaymentConfig.SRGBColor(hex: "#EF4444")!
    static let errorBadge = PaymentConfig.SRGBColor(hex: "#DC2626")!
    static let dangerWash = PaymentConfig.SRGBColor(hex: "#EF4444")!
}

extension UIColor {
    convenience init(_ color: PaymentConfig.SRGBColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }
}
