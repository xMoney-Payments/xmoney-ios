import Foundation

package protocol DigitalWalletAuthorizing: AnyObject {
    var didAuthorizePayment: Bool { get }
    func start() async -> EngineResult
    func dismiss()
}

extension DigitalWalletAuthorizing {
    package func dismiss() {}
}

package enum DigitalWalletFactory {
    package static var canMakePayments: () -> Bool = { false }

    package static var makeApplePay: (
        (PaymentEngine, ThreeDSPresenter, OrderPayloadInfo) -> any DigitalWalletAuthorizing
    )?
}
