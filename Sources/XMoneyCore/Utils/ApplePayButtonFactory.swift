import PassKit

/// Shared PassKit button construction for Payment Element, Payment Sheet and
/// the standalone Apple Pay button.
@MainActor
package enum ApplePayButtonFactory {
    /// iOS 26 paints card art onto the default button after the rest of the form.
    /// `disableCardArt` restores the mark that is ready on the first frame.
    /// The initializer is only in the iOS 26 SDK, so Xcode 16 (iOS 18 SDK) must not see the call.
    package static func make(type: PKPaymentButtonType, style: PKPaymentButtonStyle) -> PKPaymentButton {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return PKPaymentButton(type: type, style: style, disableCardArt: true)
        }
        #endif
        return PKPaymentButton(paymentButtonType: type, paymentButtonStyle: style)
    }

    package static func style(
        appearance: PaymentConfig.WalletAppearance,
        isDarkBackground: Bool
    ) -> PKPaymentButtonStyle {
        switch appearance.color {
        case .white: return .white
        case .whiteOutline: return .whiteOutline
        case .black: return .black
        case nil: return isDarkBackground ? .white : .black
        }
    }

    package static func type(from type: PaymentConfig.WalletButtonType?) -> PKPaymentButtonType {
        switch type {
        case .buy: return .buy
        case .checkout: return .checkout
        case .donate: return .donate
        case .order: return .order
        case .pay: return .inStore
        case .subscribe: return .subscribe
        case .book: return .book
        case .topUp: return .topUp
        case .plain, nil: return .plain
        }
    }
}
