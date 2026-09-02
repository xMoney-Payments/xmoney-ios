import SwiftUI
import UIKit
import XMoneyCore

/// Default demo order: €19.99 (or `ExampleSecrets.currency`).
let SAMPLE_AMOUNT_MINOR: Int64 = 1_999

func exampleForcedStyle(_ isDark: Bool) -> PaymentConfig.UserInterfaceStyle {
    isDark ? .alwaysDark : .alwaysLight
}

func exampleWalletAppearance(isDark: Bool) -> PaymentConfig.WalletAppearance {
    PaymentConfig.WalletAppearance(color: isDark ? .white : .black)
}

/**
 * Example-app `AppearanceConfig` so Sheet / Element / Apple Pay match this
 * merchant chrome (especially dark). Copy this pattern in your app — SDK
 * defaults stay xMoney purple on a white card until you set `options.appearance`.
 *
 * `primary` is the interactive accent (Edit, selected marks, “Use other card”,
 * focused field outline). `borderRadius` is the card field and payment-methods
 * container radius (SDK default 16 pt fields / 20 pt container when omitted).
 * For a light brand fill, pass a dark readable `primary` and the fill as
 * `buttonBackground` so links stay above WCAG contrast on white.
 * `primaryDark` / `buttonBackground` default to `primary` (same as Android).
 */
func exampleAppearance(
    primary: Color = ExampleColors.purple,
    primaryDark: Color? = nil,
    buttonBackground: Color? = nil,
    buttonText: Color = .white
) -> PaymentConfig.AppearanceConfig {
    let darkPrimary = primaryDark ?? primary
    let fill = buttonBackground ?? primary
    let pay = PaymentConfig.PrimaryButtonColors(
        background: fill.toAppearanceHex(),
        text: buttonText.toAppearanceHex()
    )
    return PaymentConfig.AppearanceConfig(
        colorsLight: exampleAppearanceColors(
            primary: primary,
            background: ExampleColors.lightBg,
            component: ExampleColors.lightCard,
            text: ExampleColors.lightText,
            muted: ExampleColors.lightMuted,
            hairline: ExampleColors.lightHairline
        ),
        colorsDark: exampleAppearanceColors(
            primary: darkPrimary,
            background: ExampleColors.darkBg,
            component: ExampleColors.darkCard,
            text: ExampleColors.darkText,
            muted: ExampleColors.darkMuted,
            hairline: ExampleColors.darkHairline
        ),
        borderRadius: 24,
        primaryButton: PaymentConfig.PrimaryButtonConfig(
            colorsLight: pay,
            colorsDark: pay,
            borderRadius: 9999,
            borderWidth: 0
        )
    )
}

func defaultPaymentConfig(
    isDark: Bool,
    applePayEnabled: Bool = true,
    savedCardsEnabled: Bool = true,
    appearance: PaymentConfig.AppearanceConfig = exampleAppearance()
) -> PaymentConfig {
    PaymentConfig(
        publicKey: ExampleSecrets.publicKey,
        card: .init(savedCards: .init(enabled: savedCardsEnabled)),
        paymentMethods: .init(
            applePay: .init(enabled: applePayEnabled, appearance: exampleWalletAppearance(isDark: isDark))
        ),
        options: .init(
            style: exampleForcedStyle(isDark),
            appearance: appearance
        )
    )
}

func formatMoney(_ amountMinor: Int64, currency: String) -> String {
    let amount = Decimal(amountMinor) / 100
    let format = NumberFormatter()
    format.numberStyle = .currency
    format.currencyCode = currency.uppercased()
    let hasCents = amountMinor % 100 != 0
    format.minimumFractionDigits = hasCents ? 2 : 0
    format.maximumFractionDigits = 2
    return format.string(from: amount as NSDecimalNumber) ?? "\(amount) \(currency)"
}

/// SwiftUI `.task` cancel often arrives as `URLError.cancelled` ("cancelled"), not `CancellationError`.
func isCancellation(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if Task.isCancelled { return true }
    if let url = error as? URLError, url.code == .cancelled { return true }
    let ns = error as NSError
    return ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
}

/// Complete/Failed always consume. Canceled consumes only after pay started (e.g. 3DS).
func orderConsumed(_ result: PaymentResult, didProcess: Bool) -> Bool {
    switch result {
    case .complete, .failed: return true
    case .canceled: return didProcess
    }
}

private func exampleAppearanceColors(
    primary: Color,
    background: Color,
    component: Color,
    text: Color,
    muted: Color,
    hairline: Color
) -> PaymentConfig.AppearanceColors {
    PaymentConfig.AppearanceColors(
        primary: primary.toAppearanceHex(),
        background: background.toAppearanceHex(),
        componentBackground: component.toAppearanceHex(),
        componentBorder: hairline.toAppearanceHex(),
        componentDivider: hairline.toAppearanceHex(),
        primaryText: text.toAppearanceHex(),
        secondaryText: muted.toAppearanceHex(),
        componentText: text.toAppearanceHex(),
        placeholderText: muted.toAppearanceHex(),
        icon: muted.toAppearanceHex(),
        error: ExampleColors.error.toAppearanceHex(),
        containerBorder: hairline.toAppearanceHex()
    )
}

extension Color {
    func toAppearanceHex() -> String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        let ai = Int(round(a * 255))
        if ai == 255 {
            return String(format: "#%02X%02X%02X", ri, gi, bi)
        }
        return String(format: "#%02X%02X%02X%02X", ai, ri, gi, bi)
    }
}
