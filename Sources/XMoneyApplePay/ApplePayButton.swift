import PassKit
import SwiftUI
import UIKit
import XMoneyCore

public final class ApplePayButton: UIView {
    public var onTap: (() -> Void)?

    private var paymentButton: PKPaymentButton
    private let heightConstraint: NSLayoutConstraint
    private var appearance: PaymentConfig.WalletAppearance
    private var isDarkBackground: Bool

    public init(
        appearance: PaymentConfig.WalletAppearance = .init(),
        height: CGFloat = 56,
        isDarkBackground: Bool = false
    ) {
        self.appearance = appearance
        self.isDarkBackground = isDarkBackground
        paymentButton = PKPaymentButton(
            paymentButtonType: Self.buttonType(from: appearance.type),
            paymentButtonStyle: Self.buttonStyle(
                appearance: appearance,
                isDarkBackground: isDarkBackground
            )
        )
        heightConstraint = paymentButton.heightAnchor.constraint(equalToConstant: height)
        super.init(frame: .zero)
        ApplePay.register()

        paymentButton.translatesAutoresizingMaskIntoConstraints = false
        paymentButton.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        applyCornerRadius(height: height)
        addSubview(paymentButton)
        NSLayoutConstraint.activate([
            paymentButton.topAnchor.constraint(equalTo: topAnchor),
            paymentButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            paymentButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            paymentButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightConstraint,
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public var isEnabled: Bool {
        get { paymentButton.isEnabled }
        set { paymentButton.isEnabled = newValue }
    }

    public var buttonHeight: CGFloat {
        get { heightConstraint.constant }
        set {
            heightConstraint.constant = newValue
            applyCornerRadius(height: newValue)
        }
    }

    public func apply(appearance: PaymentConfig.WalletAppearance, isDarkBackground: Bool? = nil) {
        self.appearance = appearance
        if let isDarkBackground {
            self.isDarkBackground = isDarkBackground
        }
        rebuildButton()
    }

    private func rebuildButton() {
        let wasEnabled = paymentButton.isEnabled
        paymentButton.removeFromSuperview()
        let button = PKPaymentButton(
            paymentButtonType: Self.buttonType(from: appearance.type),
            paymentButtonStyle: Self.buttonStyle(
                appearance: appearance,
                isDarkBackground: isDarkBackground
            )
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        button.isEnabled = wasEnabled
        paymentButton = button
        applyCornerRadius(height: heightConstraint.constant)
        addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightConstraint,
        ])
    }

    private func applyCornerRadius(height: CGFloat) {
        if let radius = appearance.radius {
            paymentButton.cornerRadius = CGFloat(radius)
        } else {
            paymentButton.cornerRadius = height / 2
        }
    }

    @objc private func tapped() {
        onTap?()
    }

    private static func buttonStyle(
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

    private static func buttonType(from type: PaymentConfig.WalletButtonType?) -> PKPaymentButtonType {
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

// MARK: - SwiftUI

public struct ApplePayButtonView: UIViewRepresentable {
    public var appearance: PaymentConfig.WalletAppearance
    public var height: CGFloat
    public var isEnabled: Bool
    public var isDarkBackground: Bool
    public var onTap: () -> Void

    public init(
        appearance: PaymentConfig.WalletAppearance = .init(),
        height: CGFloat = 56,
        isEnabled: Bool = true,
        isDarkBackground: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.appearance = appearance
        self.height = height
        self.isEnabled = isEnabled
        self.isDarkBackground = isDarkBackground
        self.onTap = onTap
    }

    public func makeUIView(context: Context) -> ApplePayButton {
        let button = ApplePayButton(
            appearance: appearance,
            height: height,
            isDarkBackground: isDarkBackground
        )
        button.onTap = onTap
        button.isEnabled = isEnabled
        return button
    }

    public func updateUIView(_ uiView: ApplePayButton, context: Context) {
        uiView.onTap = onTap
        uiView.isEnabled = isEnabled
        uiView.buttonHeight = height
        uiView.apply(appearance: appearance, isDarkBackground: isDarkBackground)
    }
}
