import SwiftUI
import XMoneyCore

struct DemoOption: Hashable {
    let label: String
    let value: String
}

enum IntegrationMode: String, CaseIterable {
    case paymentSheet = "Sheet"
    case applePay = "Apple Pay"
    case embedded = "Embedded"
}

let playgroundLocaleOptions = [
    DemoOption(label: "English", value: "en-US"),
    DemoOption(label: "Greek", value: "el-GR"),
    DemoOption(label: "Romanian", value: "ro-RO"),
    DemoOption(label: "Bulgarian", value: "bg-BG"),
    DemoOption(label: "Hungarian", value: "hu-HU"),
    DemoOption(label: "Polish", value: "pl-PL"),
]

let playgroundStyleOptions = [
    DemoOption(label: "Auto", value: "automatic"),
    DemoOption(label: "Light", value: "alwaysLight"),
    DemoOption(label: "Dark", value: "alwaysDark"),
]

let playgroundButtonTypeOptions = [
    DemoOption(label: "Pay", value: "pay"),
    DemoOption(label: "Book", value: "book"),
    DemoOption(label: "Buy", value: "buy"),
    DemoOption(label: "Checkout", value: "checkout"),
    DemoOption(label: "Donate", value: "donate"),
    DemoOption(label: "Order", value: "order"),
    DemoOption(label: "Subscribe", value: "subscribe"),
    DemoOption(label: "Top up", value: "topUp"),
    DemoOption(label: "Deposit", value: "deposit"),
]

let playgroundValidationOptions = [
    DemoOption(label: "On touched", value: "onTouched"),
    DemoOption(label: "On change", value: "onChange"),
    DemoOption(label: "On blur", value: "onBlur"),
    DemoOption(label: "On submit", value: "onSubmit"),
]

let playgroundGroupingOptions = [
    DemoOption(label: "Condensed", value: "condensed"),
    DemoOption(label: "Spaced", value: "spaced"),
]

let playgroundWalletColorOptions = [
    DemoOption(label: "Auto", value: "auto"),
    DemoOption(label: "Black", value: "black"),
    DemoOption(label: "White", value: "white"),
    DemoOption(label: "White outline", value: "white-outline"),
]

let playgroundWalletTypeOptions = [
    DemoOption(label: "Pay", value: "pay"),
    DemoOption(label: "Plain", value: "plain"),
    DemoOption(label: "Buy", value: "buy"),
    DemoOption(label: "Book", value: "book"),
    DemoOption(label: "Checkout", value: "checkout"),
    DemoOption(label: "Donate", value: "donate"),
    DemoOption(label: "Order", value: "order"),
    DemoOption(label: "Subscribe", value: "subscribe"),
]

let playgroundFontFamilyOptions = [
    DemoOption(label: "Default (Roobert)", value: ""),
    DemoOption(label: "Georgia", value: "Georgia"),
    DemoOption(label: "Courier New", value: "Courier New"),
    DemoOption(label: "Avenir Next", value: "Avenir Next"),
    DemoOption(label: "Helvetica Neue", value: "Helvetica Neue"),
]

func playgroundStyle(_ value: String) -> PaymentConfig.ColorSchemePreference {
    PaymentConfig.ColorSchemePreference.from(value)
}

func playgroundValidation(_ value: String) -> PaymentConfig.ValidationMode {
    PaymentConfig.ValidationMode(rawValue: value) ?? .onTouched
}

func playgroundGrouping(_ value: String) -> PaymentConfig.CardGrouping {
    PaymentConfig.CardGrouping(rawValue: value) ?? .condensed
}

func playgroundButtonType(_ value: String) -> PaymentConfig.SubmitButtonType {
    PaymentConfig.SubmitButtonType(rawValue: value) ?? .pay
}

func playgroundWalletType(_ value: String) -> PaymentConfig.WalletButtonType? {
    PaymentConfig.WalletButtonType.from(value)
}

struct AppearancePreset: Identifiable {
    let id: String
    let label: String
    let description: String
    let appearance: PaymentConfig.Appearance
}

private func themePair(_ light: String, _ dark: String) -> PaymentConfig.ThemeColor {
    PaymentConfig.ThemeColor(light: light, dark: dark)!
}

enum AppearancePresets {
    static let all: [AppearancePreset] = [
        AppearancePreset(id: "default", label: "xMoney", description: "Built-in light and dark", appearance: .init()),
        AppearancePreset(
            id: "sharp_blue",
            label: "Sharp blue",
            description: "Square corners, blue brand in both modes",
            appearance: .init(brandColor: themePair("#1D4ED8", "#436CDF"), shape: .init(corners: .sharp, pillButtons: false))
        ),
        AppearancePreset(
            id: "rounded_teal",
            label: "Rounded teal",
            description: "Rounded corners, teal brand in both modes",
            appearance: .init(brandColor: themePair("#0F766E", "#0F766E"), shape: .init(corners: .rounded))
        ),
        AppearancePreset(
            id: "yellow",
            label: "Yellow",
            description: "Yellow brand in both modes",
            appearance: .init(brandColor: themePair("#FACC15", "#FACC15"))
        ),
        AppearancePreset(
            id: "black",
            label: "Black",
            description: "Black on a light sheet, white on the lifted black sheet",
            appearance: .init(
                brandColor: themePair("#111111", "#FFFFFF"),
                backgroundColor: themePair("#F4F4F5", "#000000"),
                neutralTint: themePair("#6B7280", "#7B909A")
            )
        ),
        AppearancePreset(
            id: "warm_cream",
            label: "Warm cream",
            description: "Terracotta on cream, warm brown in dark",
            appearance: .init(
                brandColor: themePair("#B4532A", "#F0B090"),
                backgroundColor: themePair("#FBF5EA", "#140E0A"),
                neutralTint: themePair("#8A7560", "#CDB59A")
            )
        ),
    ]
}
