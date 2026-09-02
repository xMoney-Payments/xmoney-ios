import Foundation

package protocol ThreeDSPresenter: AnyObject {
    func presentThreeDS(url: URL, returnURLMatcher: @escaping (URL) -> Bool) async -> Bool
    func dismissThreeDS()
}

package struct SheetState {
    package let sessionToken: String
    package let orderInfo: OrderPayloadInfo
    package let savedCards: [SavedCard]
    /// Site/config returned a usable Apple Pay merchant ID for this order.
    package let applePayAvailable: Bool
    /// PassKit reports this device can make Apple Pay payments.
    package let applePayReady: Bool
    package let nameCheckValidationEnabled: Bool

    package init(
        sessionToken: String,
        orderInfo: OrderPayloadInfo,
        savedCards: [SavedCard],
        applePayAvailable: Bool,
        applePayReady: Bool = false,
        nameCheckValidationEnabled: Bool = false
    ) {
        self.sessionToken = sessionToken
        self.orderInfo = orderInfo
        self.savedCards = savedCards
        self.applePayAvailable = applePayAvailable
        self.applePayReady = applePayReady
        self.nameCheckValidationEnabled = nameCheckValidationEnabled
    }

    package func withSavedCards(_ cards: [SavedCard]) -> SheetState {
        SheetState(
            sessionToken: sessionToken,
            orderInfo: orderInfo,
            savedCards: cards,
            applePayAvailable: applePayAvailable,
            applePayReady: applePayReady,
            nameCheckValidationEnabled: nameCheckValidationEnabled
        )
    }
}

package final class PaymentEngine {
    package let configuration: PaymentConfig
    package let intent: PaymentIntent
    let env: PaymentEnvironment

    private let http: HTTPClient
    private let account: AccountService
    private let configService: ConfigService
    private let cards: CardsService
    private let wallets: DigitalWalletsService
    private let payment: PaymentService
    private let transactions: TransactionService

    private var sessionToken: String = ""
    private var nameCheckValidationEnabled: Bool = false
    private var cachedWalletParams: [String: WalletParams] = [:]

    package var onCardHolderVerification: ((CardHolderVerificationResult) -> Bool)?

    package convenience init(configuration: PaymentConfig, intent: PaymentIntent) throws {
        try self.init(configuration: configuration, intent: intent, http: HTTPClient())
    }

    init(configuration: PaymentConfig, intent: PaymentIntent, http: HTTPClient) throws {
        guard let env = PaymentEnvironment(publicKey: configuration.publicKey) else {
            throw PaymentError.invalidKey("Invalid public key")
        }
        self.configuration = configuration
        self.intent = intent
        self.env = env
        self.http = http
        self.account = AccountService(http: http, env: env)
        self.configService = ConfigService(http: http, env: env)
        self.cards = CardsService(http: http, env: env)
        self.wallets = DigitalWalletsService(http: http, env: env)
        self.payment = PaymentService(http: http, env: env)
        self.transactions = TransactionService(http: http, env: env)
        self.onCardHolderVerification = configuration.card.cardHolderVerification?.onCardHolderVerification
    }

    package func load() async throws -> SheetState {
        sessionToken = try await account.getSessionToken(
            orderPayload: intent.orderPayload,
            orderChecksum: intent.orderChecksum
        )

        let orderInfo = OrderPayloadDecoder.info(from: intent.orderPayload)

        let token = sessionToken
        let showSavedCards = configuration.card.savedCards.enabled
            && !orderInfo.isVerifyCard
            && !orderInfo.isRecurring

        // `async let x = try? foo()` crashes the Swift 5.10 runtime (Xcode 16 CI).
        async let siteConfigTask: SiteConfig = {
            (try? await self.configService.getSiteConfig(sessionToken: token)) ?? SiteConfig()
        }()
        async let savedCardsTask: [SavedCard] = {
            guard showSavedCards else { return [] }
            return (try? await self.cards.getCards(sessionToken: token)) ?? []
        }()
        async let applePayParamsTask = fetchApplePayParamsIfEnabled()

        let siteConfig = await siteConfigTask
        let savedCards = await savedCardsTask
        let applePayParams = await applePayParamsTask
        nameCheckValidationEnabled = siteConfig.nameCheckValidationEnabled

        var applePayAvailable = false
        if let params = applePayParams, let merchantId = params.merchantId, !merchantId.isEmpty {
            cachedWalletParams["applePay"] = params
            applePayAvailable = true
        }
        let applePayReady = applePayAvailable && DigitalWalletFactory.canMakePayments()

        return SheetState(
            sessionToken: sessionToken,
            orderInfo: orderInfo,
            savedCards: savedCards,
            applePayAvailable: applePayAvailable,
            applePayReady: applePayReady,
            nameCheckValidationEnabled: nameCheckValidationEnabled
        )
    }

    package func submitNewCard(_ card: CardInput, presenter: ThreeDSPresenter) async throws -> EngineResult {
        if let verification = configuration.card.cardHolderVerification {
            if !nameCheckValidationEnabled {
                throw PaymentError.cardHolderVerification(PaymentError.nameCheckNotEnabled)
            }
            guard let currency = OrderPayloadDecoder.info(from: intent.orderPayload).currency else {
                throw PaymentError.payment("Missing currency for card holder verification")
            }
            let result = try await account.validateAccount(
                card: card,
                name: verification.name,
                currency: currency,
                sessionToken: sessionToken
            )
            let callback = onCardHolderVerification ?? verification.onCardHolderVerification
            let accepted = await MainActor.run { callback(result) }
            if !accepted {
                return EngineResult(
                    status: .failed,
                    transaction: nil,
                    errorCode: "CARD_HOLDER_VERIFICATION",
                    errorMessage: PaymentError.verificationRejected
                )
            }
        }
        let fields = payment.cardFields(
            card: card,
            orderPayload: intent.orderPayload,
            orderChecksum: intent.orderChecksum
        )
        return try await submit(fields: fields, presenter: presenter)
    }

    package func submitSavedCard(cardId: String, presenter: ThreeDSPresenter) async throws -> EngineResult {
        let fields = payment.savedCardFields(
            cardId: cardId,
            orderPayload: intent.orderPayload,
            orderChecksum: intent.orderChecksum
        )
        return try await submit(fields: fields, presenter: presenter)
    }

    package func submitWallet(walletType: String, token: String, presenter: ThreeDSPresenter) async throws -> EngineResult {
        let fields = payment.walletFields(
            walletType: walletType,
            token: token,
            orderPayload: intent.orderPayload,
            orderChecksum: intent.orderChecksum
        )
        return try await submit(fields: fields, presenter: presenter)
    }

    package func walletParams(walletType: String) async throws -> WalletParams {
        if let cached = cachedWalletParams[walletType] {
            return cached
        }
        let params = try await wallets.getParams(walletType: walletType, sessionToken: sessionToken)
        cachedWalletParams[walletType] = params
        return params
    }

    package func deleteSavedCard(cardId: String) async throws {
        try await cards.deleteCard(cardId: cardId, sessionToken: sessionToken)
    }

    package func refreshSavedCards() async throws -> [SavedCard] {
        let orderInfo = OrderPayloadDecoder.info(from: intent.orderPayload)
        let showSavedCards = configuration.card.savedCards.enabled
            && !orderInfo.isVerifyCard
            && !orderInfo.isRecurring
        guard showSavedCards else { return [] }
        return try await cards.getCards(sessionToken: sessionToken)
    }

    private func fetchApplePayParamsIfEnabled() async -> WalletParams? {
        guard configuration.paymentMethods.applePay.enabled else { return nil }
        return try? await wallets.getParams(walletType: "applePay", sessionToken: sessionToken)
    }

    package func validateApplePayMerchant(validationURL: String) async throws -> [String: Any] {
        try await wallets.validateMerchant(validationURL: validationURL, sessionToken: sessionToken)
    }

    private func submit(fields: [String: String], presenter: ThreeDSPresenter) async throws -> EngineResult {
        let response = try await payment.confirmPayment(fields: fields)
        let parsed = try payment.parse(response)

        switch parsed.submission {
        case let .needs3DS(url):
            let transactionId = try requireTransactionIdForThreeDS(parsed.transactionId)
            let backURL = OrderPayloadDecoder.backURL(from: intent.orderPayload)
            let matcher: (URL) -> Bool = { returnURL in
                guard let backURL else { return false }
                return OrderPayloadDecoder.matchesReturnURL(returnURL, backURL: backURL)
            }
            return try await handleThreeDSWithBackgroundRefresh(
                url: url,
                transactionId: transactionId,
                presenter: presenter,
                returnURLMatcher: matcher
            )

        case .redirect:
            return try await resolveByPolling(transactionId: parsed.transactionId)

        case let .transaction(id):
            return try await resolveByPolling(transactionId: id)
        }
    }

    private func resolveByPolling(transactionId: String?) async throws -> EngineResult {
        guard let transactionId else {
            throw PaymentError.payment("Missing transaction id")
        }
        let tx = try await transactions.poll(transactionId: transactionId, sessionToken: sessionToken)
        return resultFromTransaction(tx)
    }

    private enum ThreeDSEvent {
        case pollResult(Result<EngineResult, Error>)
        case challengeFinished(Bool)
    }

    private func handleThreeDSWithBackgroundRefresh(
        url: URL,
        transactionId: String,
        presenter: ThreeDSPresenter,
        returnURLMatcher: @escaping (URL) -> Bool
    ) async throws -> EngineResult {
        let pollTask = Task {
            try await self.resolveByPolling(transactionId: transactionId)
        }
        let challengeTask = Task {
            await presenter.presentThreeDS(url: url, returnURLMatcher: returnURLMatcher)
        }

        defer {
            pollTask.cancel()
            challengeTask.cancel()
        }

        return try await withThrowingTaskGroup(of: ThreeDSEvent.self) { group in
            group.addTask {
                do {
                    return .pollResult(.success(try await pollTask.value))
                } catch is CancellationError {
                    return .pollResult(.failure(CancellationError()))
                } catch {
                    return .pollResult(.failure(error))
                }
            }
            group.addTask {
                .challengeFinished(await challengeTask.value)
            }

            while let event = try await group.next() {
                switch event {
                case .pollResult(.success(let result)):
                    presenter.dismissThreeDS()
                    challengeTask.cancel()
                    group.cancelAll()
                    return result
                case .pollResult(.failure(let error)):
                    if error is CancellationError { continue }
                    challengeTask.cancel()
                    group.cancelAll()
                    throw error
                case .challengeFinished(let completed):
                    if !completed {
                        return await reconcileCanceledThreeDS(
                            fetchTransaction: {
                                try await self.transactions.getTransaction(
                                    id: transactionId,
                                    sessionToken: self.sessionToken
                                )
                            },
                            pollTask: pollTask
                        )
                    }
                }
            }
            throw PaymentError.payment("3DS flow ended unexpectedly")
        }
    }
}
