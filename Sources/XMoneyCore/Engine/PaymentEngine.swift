import Foundation
import OSLog

package protocol ThreeDSPresenter: AnyObject {
    func presentThreeDS(url: URL) async -> ThreeDSChallengeEnd
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
    package let customerDetailsVisibility: CustomerDetailsVisibility
    /// Shared with the form so entered details survive rebuilds.
    package let personalDetails: PersonalDetailsProgress

    package init(
        sessionToken: String,
        orderInfo: OrderPayloadInfo,
        savedCards: [SavedCard],
        applePayAvailable: Bool,
        applePayReady: Bool = false,
        nameCheckValidationEnabled: Bool = false,
        customerDetailsVisibility: CustomerDetailsVisibility = .inactive,
        personalDetails: PersonalDetailsProgress = PersonalDetailsProgress()
    ) {
        self.sessionToken = sessionToken
        self.orderInfo = orderInfo
        self.savedCards = savedCards
        self.applePayAvailable = applePayAvailable
        self.applePayReady = applePayReady
        self.nameCheckValidationEnabled = nameCheckValidationEnabled
        self.customerDetailsVisibility = customerDetailsVisibility
        self.personalDetails = personalDetails
    }

    package func withSavedCards(_ cards: [SavedCard]) -> SheetState {
        SheetState(
            sessionToken: sessionToken,
            orderInfo: orderInfo,
            savedCards: cards,
            applePayAvailable: applePayAvailable,
            applePayReady: applePayReady,
            nameCheckValidationEnabled: nameCheckValidationEnabled,
            customerDetailsVisibility: customerDetailsVisibility,
            personalDetails: personalDetails
        )
    }
}

package final class PaymentEngine {
    private static let logger = Logger(subsystem: "com.xmoney.paymentsheet", category: "customer-details")
    private static let paymentLogger = Logger(subsystem: "com.xmoney.paymentsheet", category: "payment")

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
    private let inlineFields: InlineCheckoutFieldsService

    private var sessionToken: String = ""
    private var nameCheckValidationEnabled: Bool = false
    private var cachedWalletParams: [String: WalletParams] = [:]
    package private(set) var customerDetailsVisibility: CustomerDetailsVisibility = .inactive

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
        self.inlineFields = InlineCheckoutFieldsService(http: http, env: env)
        self.onCardHolderVerification = configuration.card.cardHolderVerification?.onCardHolderVerification
    }

    package func load(personalDetails: PersonalDetailsProgress = PersonalDetailsProgress()) async throws -> SheetState {
        sessionToken = try await account.getSessionToken(
            orderPayload: intent.orderPayload,
            orderChecksum: intent.orderChecksum
        )

        let orderInfo = OrderPayloadDecoder.info(from: intent.orderPayload)

        let token = sessionToken
        let showSavedCards = configuration.card.savedCards.enabled
            && !orderInfo.isVerifyCard
            && !orderInfo.isRecurring
        let applePayEnabled = configuration.paymentMethods.applePay.enabled
        let configService = configService
        let cards = cards
        let wallets = wallets

        let customerFieldsSource = customerDetailFieldsSource()
        let inlineFields = inlineFields

        // No `async let` here: optimized builds abort in the runtime's task
        // allocator when these bindings finish (Xcode 16 and Xcode 26).
        var siteConfig = SiteConfig()
        var savedCards: [SavedCard] = []
        var applePayParams: WalletParams?
        var customerFields: [String] = []
        var fieldsUnavailable = false
        await withTaskGroup(of: LoadPart.self) { group in
            group.addTask {
                do {
                    return .siteConfig(try await configService.getSiteConfig(sessionToken: token))
                } catch {
                    return .siteConfig(SiteConfig())
                }
            }
            group.addTask {
                guard showSavedCards else { return .savedCards([]) }
                do {
                    return .savedCards(try await cards.getCards(sessionToken: token))
                } catch {
                    return .savedCards([])
                }
            }
            group.addTask {
                guard applePayEnabled else { return .applePayParams(nil) }
                do {
                    return .applePayParams(
                        try await wallets.getParams(walletType: "applePay", sessionToken: token)
                    )
                } catch {
                    return .applePayParams(nil)
                }
            }
            group.addTask {
                switch customerFieldsSource {
                case .resolved(let fields):
                    return .customerFields(InlineFieldsResult(fields: fields, unavailable: false))
                case .inlineCheckout:
                    return .customerFields(await inlineFields.getFields(sessionToken: token))
                }
            }
            for await part in group {
                switch part {
                case .siteConfig(let config): siteConfig = config
                case .savedCards(let list): savedCards = list
                case .applePayParams(let params): applePayParams = params
                case .customerFields(let result):
                    customerFields = result.fields
                    fieldsUnavailable = result.unavailable
                }
            }
        }
        if fieldsUnavailable && configuration.customerDetails.card {
            throw PaymentError.load(PaymentError.genericLoad)
        }
        nameCheckValidationEnabled = siteConfig.nameCheckValidationEnabled
        customerDetailsVisibility = CustomerDetailsVisibility.resolve(fields: customerFields)
        personalDetails.defaults = CustomerDetailsResolver.resolve(
            configuration.customerDetails.defaultValues,
            visibility: customerDetailsVisibility
        )
        personalDetails.revalidate(visibility: customerDetailsVisibility)

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
            nameCheckValidationEnabled: nameCheckValidationEnabled,
            customerDetailsVisibility: customerDetailsVisibility,
            personalDetails: personalDetails
        )
    }

    package func submitNewCard(
        _ card: CardInput,
        presenter: ThreeDSPresenter,
        customerDetails: CustomerDetails? = nil
    ) async throws -> EngineResult {
        try requireCustomerDetails(customerDetails)
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
            orderChecksum: intent.orderChecksum,
            customerDetails: customerDetails
        )
        return try await submit(fields: fields, presenter: presenter)
    }

    package func submitSavedCard(
        cardId: String,
        presenter: ThreeDSPresenter,
        customerDetails: CustomerDetails? = nil
    ) async throws -> EngineResult {
        try requireCustomerDetails(customerDetails)
        let fields = payment.savedCardFields(
            cardId: cardId,
            orderPayload: intent.orderPayload,
            orderChecksum: intent.orderChecksum,
            customerDetails: customerDetails
        )
        return try await submit(fields: fields, presenter: presenter)
    }

    package func submitWallet(
        walletType: String,
        token: String,
        presenter: ThreeDSPresenter,
        customerDetails: CustomerDetails? = nil
    ) async throws -> EngineResult {
        let fields = payment.walletFields(
            walletType: walletType,
            token: token,
            orderPayload: intent.orderPayload,
            orderChecksum: intent.orderChecksum,
            customerDetails: customerDetails
        )
        return try await submit(fields: fields, presenter: presenter)
    }

    package func submitCrypto(
        presenter: ThreeDSPresenter,
        customerDetails: CustomerDetails? = nil
    ) async throws -> EngineResult {
        try requireCustomerDetails(customerDetails)
        let fields = payment.cryptoFields(
            orderPayload: intent.orderPayload,
            orderChecksum: intent.orderChecksum,
            customerDetails: customerDetails
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

    private func requireCustomerDetails(_ details: CustomerDetails?) throws {
        guard configuration.customerDetails.card, customerDetailsVisibility.isActive else { return }
        guard let details else { throw PaymentError.invalidCustomerDetails }
        func blank(_ value: String?) -> Bool {
            value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
        }
        let visibility = customerDetailsVisibility
        if visibility.showFullName && blank(details.fullName) { throw PaymentError.invalidCustomerDetails }
        if visibility.showEmail && blank(details.email) { throw PaymentError.invalidCustomerDetails }
        if visibility.showPhone && blank(details.phone) { throw PaymentError.invalidCustomerDetails }
        if visibility.showAddressSection {
            if blank(details.country) || blank(details.address) || blank(details.city) {
                throw PaymentError.invalidCustomerDetails
            }
            let format = AddressFormats.format(countryCode: details.country ?? "")
            if format.showRegion && blank(details.region) { throw PaymentError.invalidCustomerDetails }
            if format.showPostal && blank(details.postalCode) { throw PaymentError.invalidCustomerDetails }
        }
    }

    private func customerDetailFieldsSource() -> CustomerFieldsSource {
        guard configuration.customerDetails.isAnyEnabled else { return .resolved([]) }
        if let fields = configuration.customerDetails.fields {
            let resolved = CustomerDetailsResolver.inlineCheckoutFields(fields)
            if resolved.isEmpty {
                Self.logger.debug("[customer-details] customerDetails.fields has every field disabled.")
            }
            return .resolved(resolved)
        }
        return .inlineCheckout
    }

    package func validateApplePayMerchant(validationURL: String) async throws -> [String: Any] {
        try await wallets.validateMerchant(validationURL: validationURL, sessionToken: sessionToken)
    }

    private func submit(fields: [String: String], presenter: ThreeDSPresenter) async throws -> EngineResult {
        let kind = Self.paymentKind(fields)
        Self.paymentLogger.info("submit \(kind, privacy: .public)")
        let response: ConfirmPaymentResponse
        do {
            response = try await payment.confirmPayment(fields: fields)
        } catch {
            Self.paymentLogger.error(
                "submit \(kind, privacy: .public) failed before a payment result: \(String(describing: error), privacy: .public)"
            )
            throw error
        }
        let parsed: PaymentService.ParsedResponse
        do {
            parsed = try payment.parse(response)
        } catch {
            Self.paymentLogger.error(
                "submit \(kind, privacy: .public) response parse failed code=\(response.code ?? -1) status=\(response.status ?? "", privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            throw error
        }
        Self.paymentLogger.info(
            "submit \(kind, privacy: .public) accepted transaction=\(parsed.transactionId ?? "", privacy: .public)"
        )

        switch parsed.submission {
        case let .needs3DS(url):
            let transactionId = try requireTransactionIdForThreeDS(parsed.transactionId)
            return try await handleThreeDSWithBackgroundRefresh(
                url: url,
                transactionId: transactionId,
                presenter: presenter
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

    private static func paymentKind(_ fields: [String: String]) -> String {
        if let type = fields["paymentMethod"] { return type }
        if let wallet = fields["digitalWalletType"] { return wallet }
        if fields["cardId"] != nil { return "saved-card" }
        return "card"
    }

    private enum LoadPart {
        case siteConfig(SiteConfig)
        case savedCards([SavedCard])
        case applePayParams(WalletParams?)
        case customerFields(InlineFieldsResult)
    }

    private enum CustomerFieldsSource {
        case resolved([String])
        case inlineCheckout
    }

    private enum ThreeDSEvent {
        case pollResult(Result<EngineResult, Error>)
        case challengeFinished(ThreeDSChallengeEnd)
    }

    private func handleThreeDSWithBackgroundRefresh(
        url: URL,
        transactionId: String,
        presenter: ThreeDSPresenter
    ) async throws -> EngineResult {
        let pollTask = Task {
            try await self.resolveByPolling(transactionId: transactionId)
        }
        let challengeTask = Task {
            await presenter.presentThreeDS(url: url)
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
                    presenter.dismissThreeDS()
                    challengeTask.cancel()
                    group.cancelAll()
                    throw error
                case .challengeFinished(let end):
                    switch threeDSChallengeFollowUp(end) {
                    case .waitForPoll:
                        break
                    case .reconcileCancel(let grace):
                        return await reconcileCanceledThreeDS(
                            fetchTransaction: {
                                try await self.transactions.getTransaction(
                                    id: transactionId,
                                    sessionToken: self.sessionToken
                                )
                            },
                            pollTask: pollTask,
                            graceNanoseconds: grace
                        )
                    case .throwThreeDS(let message):
                        presenter.dismissThreeDS()
                        challengeTask.cancel()
                        group.cancelAll()
                        throw PaymentError.threeDS(message)
                    case .throwThreeDSUnlessComplete(let message):
                        presenter.dismissThreeDS()
                        challengeTask.cancel()
                        group.cancelAll()
                        if let tx = try? await self.transactions.getTransaction(
                            id: transactionId,
                            sessionToken: self.sessionToken
                        ), isTransactionComplete(tx) {
                            pollTask.cancel()
                            return resultFromTransaction(tx)
                        }
                        pollTask.cancel()
                        throw PaymentError.threeDS(message)
                    }
                }
            }
            throw PaymentError.payment("3DS flow ended unexpectedly")
        }
    }
}
