import Foundation
import PassKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

package final class ApplePayHandler: NSObject, PKPaymentAuthorizationControllerDelegate, DigitalWalletAuthorizing {
    private let engine: PaymentEngine
    private let presenter: ThreeDSPresenter
    private let orderInfo: OrderPayloadInfo

    private var controller: PKPaymentAuthorizationController?
    private var continuation: CheckedContinuation<EngineResult, Never>?
    private var authorizationCompletion: ((PKPaymentAuthorizationResult) -> Void)?
    private var challengeReady: (() -> Void)?
    private var handingOffToThreeDS = false
    private var didProduceResult = false

    /// PassKit holds its delegate weakly, and the surfaces release their
    /// handler as soon as the result is delivered — while PassKit may still
    /// be showing the success tick or the error. Without this, the later
    /// `paymentAuthorizationControllerDidFinish` has no receiver, `dismiss()`
    /// is never called and the sheet can't be closed. Set while the sheet is
    /// on screen; cleared once PassKit has dismissed it.
    private var presentationRetain: ApplePayHandler?

    /// `true` once the user authorizes a payment (token submit / 3DS may follow).
    /// Pre-authorize sheet dismiss is canceled without this flag.
    package private(set) var didAuthorizePayment = false

    package init(engine: PaymentEngine, presenter: ThreeDSPresenter, orderInfo: OrderPayloadInfo) {
        self.engine = engine
        self.presenter = presenter
        self.orderInfo = orderInfo
        super.init()
        (presenter as? ApplePayThreeDSPresenter)?.attach(self)
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
            self.presentationRetain = self
            controller.present { presented in
                if !presented {
                    self.resolve(.init(status: .canceled, transaction: nil, errorCode: nil, errorMessage: nil))
                    self.releasePresentation()
                }
            }
        }
    }

    /// Dismisses the authorization controller before the user authorizes.
    /// No-op after authorize (token submit / 3DS), matching Payment Sheet.
    package func dismiss() {
        guard !didAuthorizePayment else { return }
        controller?.dismiss { [self] in
            // PassKit does not always follow a programmatic dismiss with
            // didFinish; resolve here so the caller isn't left waiting.
            if !didAuthorizePayment {
                resolve(.init(status: .canceled, transaction: nil, errorCode: nil, errorMessage: nil))
            }
            releasePresentation()
        }
    }

    private func releasePresentation() {
        DispatchQueue.main.async { [self] in
            controller = nil
            presentationRetain = nil
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
        authorizationCompletion = completion
        let tokenData = payment.token.paymentData
        let token = String(data: tokenData, encoding: .utf8) ?? ""

        Task { @MainActor in
            do {
                let result = try await self.engine.submitWallet(
                    walletType: "applePay",
                    token: token,
                    presenter: self.presenter
                )
                self.completePassKit(with: result)
                self.resolve(result)
            } catch let error as PaymentError {
                let failed = EngineResult.failed(error)
                self.completePassKit(with: failed)
                self.resolve(failed)
            } catch {
                let failed = self.failureResult(message: error.localizedDescription)
                self.completePassKit(with: failed)
                self.resolve(failed)
            }
        }
    }

    /// Closes the Apple Pay sheet before the challenge is shown.
    ///
    /// PassKit has no "challenge required" status and draws above the app, so the
    /// sheet is closed with success. That checkmark is wallet authorization.
    /// The SDK result is still the charge result, delivered after the poll.
    func relinquishSheetForChallenge() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                self.handingOffToThreeDS = true
                guard let completion = self.authorizationCompletion else {
                    cont.resume()
                    return
                }
                self.authorizationCompletion = nil
                self.challengeReady = { cont.resume() }
                completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
            }
        }
    }

    private func completePassKit(with result: EngineResult) {
        guard let completion = authorizationCompletion else { return }
        authorizationCompletion = nil
        let status: PKPaymentAuthorizationStatus = result.status == .complete ? .success : .failure
        completion(PKPaymentAuthorizationResult(status: status, errors: nil))
    }

    package func paymentAuthorizationControllerDidRequestMerchantSessionUpdate(
        _ controller: PKPaymentAuthorizationController
    ) async -> PKPaymentRequestMerchantSessionUpdate {
        await requestMerchantSessionUpdate()
    }

    package func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        let ready = challengeReady
        challengeReady = nil
        controller.dismiss { [self] in
            releasePresentation()
            ready?()
        }
        if handingOffToThreeDS { return }
        guard !didProduceResult else { return }
        resolve(.init(status: .canceled, transaction: nil, errorCode: nil, errorMessage: nil))
    }
}
