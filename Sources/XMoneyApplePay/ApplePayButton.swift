import PassKit
import SwiftUI
import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

public final class ApplePayButton: UIView {
    public var onTap: (() -> Void)?
    /// Fires after the PassKit button first draws, or after a short cap if it
    /// never does. Fires again when an appearance change rebuilds the button,
    /// and when the button is moved into a new window.
    public var onFirstDraw: (() -> Void)?

    private var paymentButton: PKPaymentButton
    private var heightConstraint: NSLayoutConstraint
    private var appearance: PaymentConfig.WalletAppearance
    private var isDarkBackground: Bool
    private var didNotifyDraw = false
    private var drawWatch: Task<Void, Never>?

    public init(
        appearance: PaymentConfig.WalletAppearance = .init(),
        height: CGFloat = 56,
        isDarkBackground: Bool = false
    ) {
        self.appearance = appearance
        self.isDarkBackground = isDarkBackground
        let button = Self.makeButton(
            type: Self.buttonType(from: appearance.type),
            style: Self.buttonStyle(appearance: appearance, isDarkBackground: isDarkBackground)
        )
        paymentButton = button
        heightConstraint = button.heightAnchor.constraint(equalToConstant: height)
        super.init(frame: .zero)
        ApplePay.register()

        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        applyCornerRadius(height: height)
        addSubview(button)
        installConstraints(for: button, height: heightConstraint)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else {
            drawWatch?.cancel()
            drawWatch = nil
            didNotifyDraw = false
            return
        }
        scheduleDrawWatch()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        scheduleDrawWatch()
    }

    public var isEnabled: Bool {
        get { paymentButton.isEnabled }
        set { paymentButton.isEnabled = newValue }
    }

    public var buttonHeight: CGFloat {
        get { heightConstraint.constant }
        set {
            guard heightConstraint.constant != newValue else { return }
            heightConstraint.constant = newValue
            applyCornerRadius(height: newValue)
        }
    }

    public func apply(appearance: PaymentConfig.WalletAppearance, isDarkBackground: Bool? = nil) {
        let newDark = isDarkBackground ?? self.isDarkBackground
        let needsNewButton =
            Self.buttonType(from: appearance.type) != Self.buttonType(from: self.appearance.type)
            || Self.buttonStyle(appearance: appearance, isDarkBackground: newDark)
                != Self.buttonStyle(appearance: self.appearance, isDarkBackground: self.isDarkBackground)

        self.appearance = appearance
        self.isDarkBackground = newDark

        if needsNewButton {
            rebuildButton()
        } else {
            applyCornerRadius(height: heightConstraint.constant)
        }
    }

    private func rebuildButton() {
        didNotifyDraw = false
        drawWatch?.cancel()
        drawWatch = nil
        let wasEnabled = paymentButton.isEnabled
        let height = heightConstraint.constant
        paymentButton.removeFromSuperview()

        let button = Self.makeButton(
            type: Self.buttonType(from: appearance.type),
            style: Self.buttonStyle(appearance: appearance, isDarkBackground: isDarkBackground)
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        button.isEnabled = wasEnabled
        let newHeight = button.heightAnchor.constraint(equalToConstant: height)
        paymentButton = button
        heightConstraint = newHeight
        applyCornerRadius(height: height)
        addSubview(button)
        installConstraints(for: button, height: newHeight)
        scheduleDrawWatch()
    }

    private func scheduleDrawWatch() {
        guard !didNotifyDraw, drawWatch == nil else { return }
        guard window != nil, bounds.width > 1, bounds.height > 1 else { return }
        let button = paymentButton
        drawWatch = Task { @MainActor [weak self] in
            await SurfacePaint.waitUntilButtonDrawn(button)
            guard !Task.isCancelled, let self, !self.didNotifyDraw, self.window != nil else { return }
            self.didNotifyDraw = true
            self.drawWatch = nil
            self.onFirstDraw?()
        }
    }

    private func installConstraints(for button: PKPaymentButton, height: NSLayoutConstraint) {
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            height,
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

    private static func makeButton(type: PKPaymentButtonType, style: PKPaymentButtonStyle) -> PKPaymentButton {
        ApplePayButtonFactory.make(type: type, style: style)
    }

    private static func buttonStyle(
        appearance: PaymentConfig.WalletAppearance,
        isDarkBackground: Bool
    ) -> PKPaymentButtonStyle {
        ApplePayButtonFactory.style(appearance: appearance, isDarkBackground: isDarkBackground)
    }

    private static func buttonType(from type: PaymentConfig.WalletButtonType?) -> PKPaymentButtonType {
        ApplePayButtonFactory.type(from: type)
    }
}

// MARK: - SwiftUI

public struct ApplePayButtonView: UIViewRepresentable {
    public var appearance: PaymentConfig.WalletAppearance
    public var height: CGFloat
    public var isEnabled: Bool
    public var isDarkBackground: Bool
    public var onTap: () -> Void
    public var onFirstDraw: () -> Void

    public init(
        appearance: PaymentConfig.WalletAppearance = .init(),
        height: CGFloat = 56,
        isEnabled: Bool = true,
        isDarkBackground: Bool = false,
        onTap: @escaping () -> Void,
        onFirstDraw: @escaping () -> Void = {}
    ) {
        self.appearance = appearance
        self.height = height
        self.isEnabled = isEnabled
        self.isDarkBackground = isDarkBackground
        self.onTap = onTap
        self.onFirstDraw = onFirstDraw
    }

    public func makeUIView(context: Context) -> ApplePayButton {
        let button = ApplePayButton(
            appearance: appearance,
            height: height,
            isDarkBackground: isDarkBackground
        )
        button.onTap = onTap
        button.onFirstDraw = onFirstDraw
        button.isEnabled = isEnabled
        return button
    }

    public func updateUIView(_ uiView: ApplePayButton, context: Context) {
        uiView.onTap = onTap
        uiView.onFirstDraw = onFirstDraw
        uiView.isEnabled = isEnabled
        uiView.buttonHeight = height
        uiView.apply(appearance: appearance, isDarkBackground: isDarkBackground)
    }
}
