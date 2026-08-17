import Foundation
import PassKit
#if !COCOAPODS
import XMoneyCore
#endif

package final class ApplePayHandler: NSObject, PKPaymentAuthorizationControllerDelegate, DigitalWalletAuthorizing {
    private let engine: PaymentEngine
    private let presenter: ThreeDSPresenter
    private let orderInfo: OrderPayloadInfo

    private var controller: PKPaymentAuthorizationController?
    private var continuation: CheckedContinuation<EngineResult, Never>?
    private var didProduceResult = false

    /// `true` once the user authorizes a payment (token submit / 3DS may follow).
    /// Pre-authorize sheet dismiss is canceled without this flag.
    package private(set) var didAuthorizePayment = false

    package init(engine: PaymentEngine, presenter: ThreeDSPresenter, orderInfo: OrderPayloadInfo) {
        self.engine = engine
        self.presenter = presenter
        self.orderInfo = orderInfo
    }

    package func start() async -> EngineResult {
        let params: WalletParams
        do {
            params = try await engine.walletParams(walletType: "applePay")
        } catch let error as PaymentError {
            return .failed(error)
        } catch {
            return failureResult(message: error.localizedDescription)
        }

        guard let merchantId = params.merchantId, !merchantId.isEmpty else {
            return failureResult(message: "Missing Apple Pay merchant ID from wallet params.")
        }

        guard let currency = orderInfo.currency, !currency.isEmpty, let amount = orderInfo.amount else {
            return failureResult(message: PaymentError.missingApplePayAmountOrCurrency)
        }

        // canMakePayments(usingNetworks:) is unreliable on Simulator.
        guard ApplePayCapabilities.canMakePayments() else {
            return failureResult(
                message: "Apple Pay is not available on this device. " +
                    "Add the Apple Pay capability in Xcode with merchant ID \"\(merchantId)\" and test on a physical device."
            )
        }

        let request = buildRequest(params: params, merchantId: merchantId, currency: currency, amount: amount)
        return await withCheckedContinuation { cont in
            self.continuation = cont
            let controller = PKPaymentAuthorizationController(paymentRequest: request)
            controller.delegate = self
            self.controller = controller
            controller.present { presented in
                if !presented {
                    self.resolve(.init(status: .canceled, transaction: nil, errorCode: nil, errorMessage: nil))
                }
            }
        }
    }

    private func buildRequest(
        params: WalletParams,
        merchantId: String,
        currency: String,
        amount: Double
    ) -> PKPaymentRequest {
        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantId
        request.countryCode = params.merchantCountry ?? "US"
        request.currencyCode = currency
        request.merchantCapabilities = [.threeDSecure]
        request.supportedNetworks = ApplePayCapabilities.mapNetworks(params.supportedNetworks)
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(
                label: params.merchantName ?? "Total",
                amount: NSDecimalNumber(value: amount),
                type: .final
            ),
        ]
        return request
    }

    private func failureResult(message: String) -> EngineResult {
        .failed(.applePay(message))
    }

    private func resolve(_ result: EngineResult) {
        guard !didProduceResult else { return }
        didProduceResult = true
        continuation?.resume(returning: result)
        continuation = nil
    }

    private func requestMerchantSessionUpdate() async -> PKPaymentRequestMerchantSessionUpdate {
        do {
            let response = try await engine.validateApplePayMerchant(
                validationURL: ApplePayMerchantSessionParser.gatewayValidationURL
            )
            guard let session = ApplePayMerchantSessionParser.merchantSession(from: response) else {
                resolve(failureResult(message: "Invalid Apple Pay merchant session response."))
                return .init(status: .failure, merchantSession: nil)
            }
            return .init(status: .success, merchantSession: session)
        } catch let error as PaymentError {
            resolve(.failed(error))
            return .init(status: .failure, merchantSession: nil)
        } catch {
            resolve(failureResult(message: error.localizedDescription))
            return .init(status: .failure, merchantSession: nil)
        }
    }

    // MARK: - PKPaymentAuthorizationControllerDelegate

    package func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        didAuthorizePayment = true
        let tokenData = payment.token.paymentData
        let token = String(data: tokenData, encoding: .utf8) ?? ""

        Task { @MainActor in
            do {
                let result = try await self.engine.submitWallet(
                    walletType: "applePay",
                    token: token,
                    presenter: self.presenter
                )
                completion(PKPaymentAuthorizationResult(
                    status: result.status == .complete ? .success : .failure,
                    errors: nil
                ))
                self.resolve(result)
            } catch let error as PaymentError {
                completion(PKPaymentAuthorizationResult(status: .failure, errors: [error]))
                self.resolve(.failed(error))
            } catch {
                completion(PKPaymentAuthorizationResult(status: .failure, errors: [error]))
                self.resolve(failureResult(message: error.localizedDescription))
            }
        }
    }

    package func paymentAuthorizationControllerDidRequestMerchantSessionUpdate(
        _ controller: PKPaymentAuthorizationController
    ) async -> PKPaymentRequestMerchantSessionUpdate {
        await requestMerchantSessionUpdate()
    }

    package func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss()
        guard !didProduceResult else { return }
        resolve(.init(status: .canceled, transaction: nil, errorCode: nil, errorMessage: nil))
    }
}
