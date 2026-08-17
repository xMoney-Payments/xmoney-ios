import PassKit
import XMoneyCore

enum ApplePayBootstrap {
    static func install() {
        DigitalWalletFactory.canMakePayments = {
            PKPaymentAuthorizationController.canMakePayments()
        }
        DigitalWalletFactory.makeApplePay = { engine, presenter, orderInfo in
            ApplePayHandler(engine: engine, presenter: presenter, orderInfo: orderInfo)
        }
    }
}

@_cdecl("XMoneyApplePayInstall")
public func XMoneyApplePayInstall() {
    ApplePayBootstrap.install()
}
