import CoreText
import SwiftUI
import UIKit
import XMoneyPaymentElement

/// Registers Roobert from the linked Payment Element bundle, matching Android `PaymentElementR.font`.
enum ExampleRoobert {
    private static var didRegister = false

    static func registerIfNeeded() {
        guard !didRegister else { return }
        didRegister = true
        for name in ["roobert_regular", "roobert_medium", "roobert_semibold", "roobert_bold"] {
            guard let url = fontURL(named: name) else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    private static func fontURL(named: String) -> URL? {
        for bundle in resourceBundles() {
            if let url = bundle.url(forResource: named, withExtension: "otf", subdirectory: "Fonts") {
                return url
            }
            if let url = bundle.url(forResource: named, withExtension: "otf") {
                return url
            }
        }
        return nil
    }

    private static func resourceBundles() -> [Bundle] {
        var bundles: [Bundle] = [Bundle(for: PaymentElement.self), .main]
        let names = [
            "XMoneyPaymentSheet_XMoneyPaymentElement",
            "XMoneyPaymentElement_XMoneyPaymentElement",
            "XMoneyPaymentElement",
        ]
        for root in [Bundle(for: PaymentElement.self), Bundle.main] {
            for name in names {
                if let url = root.url(forResource: name, withExtension: "bundle"),
                   let found = Bundle(url: url) {
                    bundles.append(found)
                }
            }
        }
        return bundles
    }
}

/// Example-app type scale — same sizes / weights as Android `ExampleTypography`.
enum ExampleFont {
    static var labelMedium: Font { face("RoobertPRO-Bold", size: 12, weight: .bold) }
    static var bodyMedium: Font { face("RoobertPRO-Medium", size: 14, weight: .medium) }
    static var labelLarge: Font { face("RoobertPRO-SemiBold", size: 15, weight: .semibold) }
    static var titleMedium: Font { face("RoobertPRO-SemiBold", size: 16, weight: .semibold) }
    static var titleLarge: Font { face("RoobertPRO-SemiBold", size: 20, weight: .semibold) }
    static var headlineMedium: Font { face("RoobertPRO-Bold", size: 24, weight: .bold) }

    private static func face(_ name: String, size: CGFloat, weight: Font.Weight) -> Font {
        ExampleRoobert.registerIfNeeded()
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight)
    }
}

extension View {
    @ViewBuilder
    func exampleLabelMedium() -> some View {
        if #available(iOS 16.0, *) {
            font(ExampleFont.labelMedium).tracking(1.2)
        } else {
            font(ExampleFont.labelMedium)
        }
    }
}
