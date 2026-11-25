import PassKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

enum ApplePayBootstrap {
    static func install() {
        DigitalWalletFactory.canMakePayments = {
            PKPaymentAuthorizationController.canMakePayments()
        }
        DigitalWalletFactory.makeApplePay = { engine, presenter, orderInfo, visibility in
            ApplePayHandler(
                engine: engine,
                presenter: presenter,
                orderInfo: orderInfo,
                customerDetailsVisibility: visibility
            )
        }
    }
}

@_cdecl("XMoneyApplePayInstall")
public func XMoneyApplePayInstall() {
    ApplePayBootstrap.install()
}
