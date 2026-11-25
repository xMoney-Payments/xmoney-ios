import SwiftUI
import UIKit
import XMoneyCore

/// Default demo order: €19.99 (or `ExampleSecrets.currency`).
let SAMPLE_AMOUNT_MINOR: Int64 = 1_999

func exampleForcedStyle(_ isDark: Bool) -> PaymentConfig.ColorSchemePreference {
    isDark ? .dark : .light
}

func exampleWalletAppearance(isDark: Bool) -> PaymentConfig.WalletAppearance {
    PaymentConfig.WalletAppearance(color: isDark ? .white : .black)
}

/// Example-app appearance. The pay button uses the example purple; surfaces follow the app chrome.
func exampleAppearance(
    primary: Color = ExampleColors.purple,
    primaryDark: Color? = nil,
    buttonBackground: Color? = nil,
    buttonText: Color = .white,
    isDark: Bool = false
) -> PaymentConfig.Appearance {
    let brand = PaymentConfig.ThemeColor(
        light: PaymentConfig.SRGBColor(hex: (buttonBackground ?? primary).toAppearanceHex())!,
        dark: PaymentConfig.SRGBColor(hex: (primaryDark ?? buttonBackground ?? primary).toAppearanceHex())!
    )
    let background = PaymentConfig.ThemeColor(
        light: PaymentConfig.SRGBColor(hex: ExampleColors.lightBg.toAppearanceHex())!,
        dark: PaymentConfig.SRGBColor(hex: ExampleColors.darkBg.toAppearanceHex())!
    )
    return PaymentConfig.Appearance(
        colorScheme: exampleForcedStyle(isDark),
        brandColor: brand,
        backgroundColor: background,
        overrides: .init(onBrandColor: PaymentConfig.ThemeColor(hex: buttonText.toAppearanceHex())),
        corners: .rounded
    )
}

func defaultPaymentConfig(
    isDark: Bool,
    applePayEnabled: Bool = true,
    savedCardsEnabled: Bool = true,
    appearance: PaymentConfig.Appearance = exampleAppearance()
) -> PaymentConfig {
    var theme = appearance
    theme.colorScheme = exampleForcedStyle(isDark)
    return PaymentConfig(
        publicKey: ExampleSecrets.publicKey,
        card: .init(savedCards: .init(enabled: savedCardsEnabled)),
        paymentMethods: .init(
            applePay: .init(enabled: applePayEnabled, appearance: exampleWalletAppearance(isDark: isDark))
        ),
        options: .init(appearance: theme)
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
