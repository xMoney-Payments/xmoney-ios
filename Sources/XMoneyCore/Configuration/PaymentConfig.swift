import Foundation

/// Merchant-facing checkout configuration (appearance, payment methods, locale).
/// Pair with a ``PaymentIntent`` when presenting the payment sheet.
public struct PaymentConfig: Sendable {
    public let publicKey: String
    public var card: CardConfig
    public var paymentMethods: PaymentMethodsConfig
    public var options: OptionsConfig

    public init(
        publicKey: String,
        card: CardConfig = .init(),
        paymentMethods: PaymentMethodsConfig = .init(),
        options: OptionsConfig = .init()
    ) {
        self.publicKey = publicKey
        self.card = card
        self.paymentMethods = paymentMethods
        self.options = options
    }
}

// MARK: - Nested configuration

public extension PaymentConfig {
    struct CardConfig: @unchecked Sendable {
        public var savedCards: SavedCardsConfig
        public var cardHolderVerification: CardHolderVerification?
        public var inputs: CardInputsConfig
        public var validationMode: ValidationMode
        public var submitButton: SubmitButtonConfig

        public init(
            savedCards: SavedCardsConfig = .init(),
            cardHolderVerification: CardHolderVerification? = nil,
            inputs: CardInputsConfig = .init(),
            validationMode: ValidationMode = .onTouched,
            submitButton: SubmitButtonConfig = .init()
        ) {
            self.savedCards = savedCards
            self.cardHolderVerification = cardHolderVerification
            self.inputs = inputs
            self.validationMode = validationMode
            self.submitButton = submitButton
        }
    }

    struct CardInputsConfig: Equatable, Sendable {
        public var grouping: CardGrouping

        public var isSpaced: Bool { grouping == .spaced }

        public init(grouping: CardGrouping = .condensed) {
            self.grouping = grouping
        }
    }

    enum CardGrouping: String, Equatable, Sendable {
        case condensed
        case spaced
    }

    struct SavedCardsConfig: Equatable, Sendable {
        public var enabled: Bool
        public var optInVisible: Bool

        public init(enabled: Bool = false, optInVisible: Bool = true) {
            self.enabled = enabled
            self.optInVisible = optInVisible
        }
    }

    struct SubmitButtonConfig: Equatable, Sendable {
        /// Embedded only. Payment Sheet always shows the SDK Pay button.
        public var visible: Bool
        public var type: SubmitButtonType

        public init(visible: Bool = true, type: SubmitButtonType = .pay) {
            self.visible = visible
            self.type = type
        }
    }

    enum ValidationMode: String, Equatable, Sendable {
        case onSubmit
        case onChange
        case onBlur
        case onTouched
    }

    enum SubmitButtonType: String, Equatable, Sendable {
        case book, buy, checkout, donate, order, pay, subscribe, topUp, deposit
    }

    struct PaymentMethodsConfig: Equatable, Sendable {
        public var applePay: ApplePayConfig

        public init(applePay: ApplePayConfig = .init()) {
            self.applePay = applePay
        }
    }

    struct ApplePayConfig: Equatable, Sendable {
        public var enabled: Bool
        public var appearance: WalletAppearance

        public init(enabled: Bool = false, appearance: WalletAppearance = .init()) {
            self.enabled = enabled
            self.appearance = appearance
        }
    }

    enum WalletButtonColor: String, Equatable, Sendable {
        case white
        case black
        case whiteOutline = "white-outline"

        public static func from(_ raw: String?) -> WalletButtonColor? {
            guard let raw else { return nil }
            switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "white", "light": return .white
            case "black", "dark": return .black
            case "white-outline", "whiteoutline": return .whiteOutline
            default: return WalletButtonColor(rawValue: raw.lowercased())
            }
        }
    }

    enum WalletButtonType: String, Equatable, Sendable {
        case plain
        case pay
        case buy
        case book
        case checkout
        case donate
        case order
        case subscribe
        case topUp

        public static func from(_ raw: String?) -> WalletButtonType? {
            guard let raw else { return nil }
            let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch normalized {
            case "topup", "top-up", "top_up": return .topUp
            default: return WalletButtonType(rawValue: normalized)
            }
        }
    }

    struct WalletAppearance: Equatable, Sendable {
        public var color: WalletButtonColor?
        public var radius: Double?
        public var type: WalletButtonType?

        public init(
            color: WalletButtonColor? = nil,
            radius: Double? = nil,
            type: WalletButtonType? = nil
        ) {
            self.color = color
            self.radius = radius
            self.type = type
        }
    }

    struct OptionsConfig: Equatable, Sendable {
        public var locale: String
        public var style: UserInterfaceStyle
        public var appearance: AppearanceConfig

        public init(
            locale: String = "en-US",
            style: UserInterfaceStyle = .automatic,
            appearance: AppearanceConfig = .init()
        ) {
            self.locale = locale
            self.style = style
            self.appearance = appearance
        }
    }

    enum UserInterfaceStyle: String, Equatable, Sendable {
        case automatic
        case alwaysLight
        case alwaysDark
    }

    struct AppearanceConfig: Equatable, Sendable {
        public var fontFamily: String?
        public var fontScale: Double?
        public var colors: AppearanceColors?
        public var colorsLight: AppearanceColors?
        public var colorsDark: AppearanceColors?
        public var borderRadius: Double?
        public var borderWidth: Double?
        public var primaryButton: PrimaryButtonConfig?

        public init(
            fontFamily: String? = nil,
            fontScale: Double? = nil,
            colors: AppearanceColors? = nil,
            colorsLight: AppearanceColors? = nil,
            colorsDark: AppearanceColors? = nil,
            borderRadius: Double? = nil,
            borderWidth: Double? = nil,
            primaryButton: PrimaryButtonConfig? = nil
        ) {
            self.fontFamily = fontFamily
            self.fontScale = fontScale
            self.colors = colors
            self.colorsLight = colorsLight
            self.colorsDark = colorsDark
            self.borderRadius = borderRadius
            self.borderWidth = borderWidth
            self.primaryButton = primaryButton
        }

        public static func from(_ dict: [String: Any]?) -> AppearanceConfig {
            guard let dict else { return AppearanceConfig() }
            let font = appearanceDictionary(dict["font"])
            let shapes = appearanceDictionary(dict["shapes"])
            return AppearanceConfig(
                fontFamily: font?["family"] as? String,
                fontScale: appearanceDouble(font?["scale"]),
                colors: AppearanceColors.from(appearanceDictionary(dict["colors"])),
                colorsLight: AppearanceColors.from(appearanceDictionary(dict["colorsLight"])),
                colorsDark: AppearanceColors.from(appearanceDictionary(dict["colorsDark"])),
                borderRadius: appearanceDouble(shapes?["borderRadius"]),
                borderWidth: appearanceDouble(shapes?["borderWidth"]),
                primaryButton: PrimaryButtonConfig.from(appearanceDictionary(dict["primaryButton"]))
            )
        }
    }

    struct AppearanceColors: Equatable, Sendable {
        public var primary: String?
        public var background: String?
        public var componentBackground: String?
        public var componentBorder: String?
        public var componentDivider: String?
        public var primaryText: String?
        public var secondaryText: String?
        public var componentText: String?
        public var placeholderText: String?
        public var icon: String?
        public var error: String?
        public var containerBorder: String?

        public init(
            primary: String? = nil,
            background: String? = nil,
            componentBackground: String? = nil,
            componentBorder: String? = nil,
            componentDivider: String? = nil,
            primaryText: String? = nil,
            secondaryText: String? = nil,
            componentText: String? = nil,
            placeholderText: String? = nil,
            icon: String? = nil,
            error: String? = nil,
            containerBorder: String? = nil
        ) {
            self.primary = primary
            self.background = background
            self.componentBackground = componentBackground
            self.componentBorder = componentBorder
            self.componentDivider = componentDivider
            self.primaryText = primaryText
            self.secondaryText = secondaryText
            self.componentText = componentText
            self.placeholderText = placeholderText
            self.icon = icon
            self.error = error
            self.containerBorder = containerBorder
        }

        public static func from(_ dict: [String: Any]?) -> AppearanceColors? {
            guard let dict else { return nil }
            return AppearanceColors(
                primary: dict["primary"] as? String,
                background: dict["background"] as? String,
                componentBackground: dict["componentBackground"] as? String,
                componentBorder: dict["componentBorder"] as? String,
                componentDivider: dict["componentDivider"] as? String,
                primaryText: dict["primaryText"] as? String,
                secondaryText: dict["secondaryText"] as? String,
                componentText: dict["componentText"] as? String,
                placeholderText: dict["placeholderText"] as? String,
                icon: dict["icon"] as? String,
                error: dict["error"] as? String,
                containerBorder: dict["containerBorder"] as? String
            )
        }
    }

    struct PrimaryButtonConfig: Equatable, Sendable {
        public var fontFamily: String?
        public var colors: PrimaryButtonColors?
        public var colorsLight: PrimaryButtonColors?
        public var colorsDark: PrimaryButtonColors?
        public var borderRadius: Double?
        public var borderWidth: Double?

        public init(
            fontFamily: String? = nil,
            colors: PrimaryButtonColors? = nil,
            colorsLight: PrimaryButtonColors? = nil,
            colorsDark: PrimaryButtonColors? = nil,
            borderRadius: Double? = nil,
            borderWidth: Double? = nil
        ) {
            self.fontFamily = fontFamily
            self.colors = colors
            self.colorsLight = colorsLight
            self.colorsDark = colorsDark
            self.borderRadius = borderRadius
            self.borderWidth = borderWidth
        }

        public static func from(_ dict: [String: Any]?) -> PrimaryButtonConfig? {
            guard let dict else { return nil }
            let shapes = appearanceDictionary(dict["shapes"])
            let font = appearanceDictionary(dict["font"])
            return PrimaryButtonConfig(
                fontFamily: font?["family"] as? String,
                colors: PrimaryButtonColors.from(appearanceDictionary(dict["colors"])),
                colorsLight: PrimaryButtonColors.from(appearanceDictionary(dict["colorsLight"])),
                colorsDark: PrimaryButtonColors.from(appearanceDictionary(dict["colorsDark"])),
                borderRadius: appearanceDouble(shapes?["borderRadius"]),
                borderWidth: appearanceDouble(shapes?["borderWidth"])
            )
        }
    }

    struct PrimaryButtonColors: Equatable, Sendable {
        public var background: String?
        public var text: String?
        public var border: String?

        public init(background: String? = nil, text: String? = nil, border: String? = nil) {
            self.background = background
            self.text = text
            self.border = border
        }

        public static func from(_ dict: [String: Any]?) -> PrimaryButtonColors? {
            guard let dict else { return nil }
            return PrimaryButtonColors(
                background: dict["background"] as? String,
                text: dict["text"] as? String,
                border: dict["border"] as? String
            )
        }
    }
}

private func appearanceDictionary(_ value: Any?) -> [String: Any]? {
    guard let dict = value as? NSDictionary else { return nil }
    var result: [String: Any] = [:]
    dict.enumerateKeysAndObjects { key, object, _ in
        guard let key = key as? String else { return }
        result[key] = object
    }
    return result
}

private func appearanceDouble(_ value: Any?) -> Double? {
    guard let value, !(value is NSNull) else { return nil }
    if let number = value as? NSNumber {
        if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
        return number.doubleValue
    }
    if let double = value as? Double { return double }
    if let int = value as? Int { return Double(int) }
    if let float = value as? Float { return Double(float) }
    return nil
}
