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
    DemoOption(label: "Courier New", value: "CourierNewPSMT"),
    DemoOption(label: "Avenir Next", value: "AvenirNext-Regular"),
    DemoOption(label: "Helvetica Neue", value: "HelveticaNeue"),
]

func playgroundStyle(_ value: String) -> PaymentConfig.UserInterfaceStyle {
    PaymentConfig.UserInterfaceStyle(rawValue: value) ?? .automatic
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
    let appearance: PaymentConfig.AppearanceConfig
}

enum AppearancePresets {
    static let all: [AppearancePreset] = [
        AppearancePreset(id: "example", label: "Example chrome", description: "Matches this app", appearance: exampleAppearance()),
        AppearancePreset(id: "default", label: "Default", description: "SDK defaults", appearance: .init()),
        AppearancePreset(
            id: "night",
            label: "Night",
            description: "Dark surfaces, indigo accent",
            appearance: PaymentConfig.AppearanceConfig(
                colors: PaymentConfig.AppearanceColors(
                    primary: "#818CF8",
                    background: "#0B0B0F",
                    componentBackground: "#16161D",
                    componentBorder: "#2E2E3A",
                    componentDivider: "#2E2E3A",
                    primaryText: "#F4F4F8",
                    secondaryText: "#A8A8B8",
                    componentText: "#E8E8F0",
                    placeholderText: "#6E6E80",
                    icon: "#A8A8B8",
                    error: "#F87171"
                ),
                borderRadius: 12,
                borderWidth: 1,
                primaryButton: .init(
                    colors: .init(background: "#6366F1", text: "#FFFFFF"),
                    borderRadius: 12
                )
            )
        ),
        AppearancePreset(
            id: "soft_light",
            label: "Soft light",
            description: "Warm paper, soft teal",
            appearance: PaymentConfig.AppearanceConfig(
                colors: PaymentConfig.AppearanceColors(
                    primary: "#0E7C66",
                    background: "#F7F3EC",
                    componentBackground: "#FFFBF5",
                    componentBorder: "#D9D0C3",
                    componentDivider: "#E8DFD2",
                    primaryText: "#14202B",
                    secondaryText: "#5C6B78",
                    componentText: "#14202B",
                    placeholderText: "#8A96A1",
                    icon: "#5C6B78",
                    error: "#B42318",
                    containerBorder: "none"
                ),
                borderRadius: 14,
                borderWidth: 1,
                primaryButton: .init(
                    colors: .init(background: "#0E7C66", text: "#FFFFFF"),
                    borderRadius: 14
                )
            )
        ),
        AppearancePreset(
            id: "minimal_sharp",
            label: "Minimal sharp",
            description: "High contrast, square corners",
            appearance: PaymentConfig.AppearanceConfig(
                colors: PaymentConfig.AppearanceColors(
                    primary: "#111111",
                    background: "#FFFFFF",
                    componentBackground: "#FFFFFF",
                    componentBorder: "#111111",
                    componentDivider: "#E5E5E5",
                    primaryText: "#111111",
                    secondaryText: "#555555",
                    componentText: "#111111",
                    placeholderText: "#888888",
                    icon: "#111111",
                    error: "#D92D20"
                ),
                borderRadius: 0,
                borderWidth: 1.5,
                primaryButton: .init(
                    colors: .init(background: "#111111", text: "#FFFFFF"),
                    borderRadius: 0,
                    borderWidth: 0
                )
            )
        ),
    ]
}
