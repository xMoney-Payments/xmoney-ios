import Foundation

/// Merchant-facing checkout configuration (appearance, payment methods, locale).
/// Pair with a ``PaymentIntent`` when presenting the payment sheet.
public struct PaymentConfig: Sendable {
    public let publicKey: String
    public var card: CardConfig
    public var paymentMethods: PaymentMethodsConfig
    public var customerDetails: CustomerDetailsConfig
    public var options: OptionsConfig

    public init(
        publicKey: String,
        card: CardConfig = .init(),
        paymentMethods: PaymentMethodsConfig = .init(),
        customerDetails: CustomerDetailsConfig = .init(),
        options: OptionsConfig = .init()
    ) {
        self.publicKey = publicKey
        self.card = card
        self.paymentMethods = paymentMethods
        self.customerDetails = customerDetails
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

    /// When a method is enabled, checkout asks `/inline-checkout/fields` which
    /// shopper fields to collect, unless ``fields`` is set. That override replaces
    /// the server list and is not merged with it. ``defaultValues`` prefills the
    /// card form only. Card payments stay blocked until those fields are valid.
    /// Apple Pay asks the wallet for the same sections and sends whatever comes back.
    public struct CustomerDetailsConfig: Equatable, Sendable {
        public var card: Bool
        public var applePay: Bool
        /// Replaces `/inline-checkout/fields` when set. A flag left off is not collected.
        public var fields: Fields?
        /// Prefills the card form. Apple Pay does not use these values.
        public var defaultValues: DefaultValues?

        public init(
            card: Bool = false,
            applePay: Bool = false,
            fields: Fields? = nil,
            defaultValues: DefaultValues? = nil
        ) {
            self.card = card
            self.applePay = applePay
            self.fields = fields
            self.defaultValues = defaultValues
        }

        public var isAnyEnabled: Bool { card || applePay }

        /// Which blocks to collect. Missing flags are off.
        public struct Fields: Equatable, Sendable {
            public var fullName: Bool
            public var email: Bool
            public var phone: Bool
            public var address: Bool

            public init(
                fullName: Bool = false,
                email: Bool = false,
                phone: Bool = false,
                address: Bool = false
            ) {
                self.fullName = fullName
                self.email = email
                self.phone = phone
                self.address = address
            }
        }

        /// Values written into the card form before the shopper edits it.
        /// Blank text and values that are not in the country, region, or phone lists are ignored.
        public struct DefaultValues: Equatable, Sendable {
            public var fullName: String?
            public var email: String?
            public var phone: String?
            public var country: String?
            public var region: String?
            public var city: String?
            public var postalCode: String?
            public var address: String?

            public init(
                fullName: String? = nil,
                email: String? = nil,
                phone: String? = nil,
                country: String? = nil,
                region: String? = nil,
                city: String? = nil,
                postalCode: String? = nil,
                address: String? = nil
            ) {
                self.fullName = fullName
                self.email = email
                self.phone = phone
                self.country = country
                self.region = region
                self.city = city
                self.postalCode = postalCode
                self.address = address
            }
        }
    }

    struct PaymentMethodsConfig: Equatable, Sendable {
        public var applePay: ApplePayConfig
        public var crypto: CryptoConfig

        public init(applePay: ApplePayConfig = .init(), crypto: CryptoConfig = .init()) {
            self.applePay = applePay
            self.crypto = crypto
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

    /// Shows the "Pay with crypto" option. Continue redirects the shopper to a secure page to complete the payment.
    struct CryptoConfig: Equatable, Sendable {
        public var enabled: Bool

        public init(enabled: Bool = false) {
            self.enabled = enabled
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
        public var appearance: Appearance

        public init(
            locale: String = "en-US",
            appearance: Appearance = .init()
        ) {
            self.locale = locale
            self.appearance = appearance
        }
    }
}

