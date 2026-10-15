import Foundation

@MainActor
package final class PaymentSession {
    package let configuration: PaymentConfig
    package private(set) var engine: PaymentEngine
    package private(set) var state: SheetState?
    package private(set) var isProcessing = false
    package private(set) var isOrderConsumed = false

    package var intent: PaymentIntent { engine.intent }

    package var isInteractionEnabled: Bool { !isProcessing && !isOrderConsumed }

    /// Idle/loading sheets may dismiss; in-flight pay must wait for the payment result.
    package var canDismiss: Bool { !isProcessing }

    private var boundKey: String?
    private var bindGeneration = 0
    private let http: HTTPClient

    package convenience init(configuration: PaymentConfig, intent: PaymentIntent) throws {
        try self.init(configuration: configuration, intent: intent, http: HTTPClient())
    }

    init(configuration: PaymentConfig, intent: PaymentIntent, http: HTTPClient) throws {
        self.configuration = configuration
        self.http = http
        self.engine = try PaymentEngine(configuration: configuration, intent: intent, http: http)
        injectCardHolderVerification()
    }

    /// A loaded order that has not been applied to the session yet.
    package struct BindCandidate {
        fileprivate let key: String
        fileprivate let engine: PaymentEngine
        package let state: SheetState
        fileprivate let alreadyBound: Bool
    }

    /// True once an order has been committed and `intent` is the order that pay paths charge.
    package var isBound: Bool { boundKey != nil && state != nil }

    package func isBound(_ intent: PaymentIntent) -> Bool {
        isBound && boundKey == Self.key(for: intent)
    }

    /// Loads `intent` without changing what the session charges. Hosts check
    /// their own supersession, then call ``commit(_:)``.
    package func load(intent: PaymentIntent) async throws -> BindCandidate {
        #if DEBUG
        if let testingBindError {
            self.testingBindError = nil
            throw testingBindError
        }
        #endif
        let key = Self.key(for: intent)
        if boundKey == key, let state {
            return BindCandidate(key: key, engine: engine, state: state, alreadyBound: true)
        }

        let engineToLoad: PaymentEngine
        if boundKey == nil, Self.key(for: engine.intent) == key {
            engineToLoad = engine
        } else {
            engineToLoad = try PaymentEngine(configuration: configuration, intent: intent, http: http)
            if let callback = configuration.card.cardHolderVerification?.onCardHolderVerification {
                engineToLoad.onCardHolderVerification = callback
            }
        }

        let loaded: SheetState
        #if DEBUG
        if let testingLoad {
            loaded = try await testingLoad(intent)
        } else {
            loaded = try await engineToLoad.load()
        }
        #else
        loaded = try await engineToLoad.load()
        #endif
        try Task.checkCancellation()
        return BindCandidate(key: key, engine: engineToLoad, state: loaded, alreadyBound: false)
    }

    @discardableResult
    package func commit(_ candidate: BindCandidate) -> SheetState {
        guard !candidate.alreadyBound || boundKey != candidate.key else { return candidate.state }
        engine = candidate.engine
        boundKey = candidate.key
        state = candidate.state
        isOrderConsumed = false
        isProcessing = false
        return candidate.state
    }

    /// `load` then `commit`. Overlapping calls: only the newest commits.
    package func bind(intent: PaymentIntent) async throws -> SheetState {
        bindGeneration += 1
        let generation = bindGeneration
        let candidate = try await load(intent: intent)
        guard generation == bindGeneration else {
            throw CancellationError()
        }
        return commit(candidate)
    }

    #if DEBUG
    package var testingBindError: Error?
    package var testingLoad: ((PaymentIntent) async throws -> SheetState)?

    package func testingInstall(intent: PaymentIntent, state: SheetState, processing: Bool = false) throws {
        let key = Self.key(for: intent)
        if Self.key(for: engine.intent) != key {
            engine = try PaymentEngine(configuration: configuration, intent: intent, http: http)
        }
        boundKey = key
        self.state = state
        self.isProcessing = processing
        self.isOrderConsumed = false
    }
    #endif

    package func submitNewCard(_ input: CardInput, presenter: ThreeDSPresenter) async -> EngineResult {
        await submit(didAuthorize: true) {
            try await self.engine.submitNewCard(input, presenter: presenter)
        }
    }

    package func submitSavedCard(cardId: String, presenter: ThreeDSPresenter) async -> EngineResult {
        await submit(didAuthorize: true) {
            try await self.engine.submitSavedCard(cardId: cardId, presenter: presenter)
        }
    }

    package func startWallet(_ authorizer: DigitalWalletAuthorizing) async -> EngineResult {
        guard beginOperation() else { return Self.canceled }
        let result = await authorizer.start()
        finish(result, didAuthorize: authorizer.didAuthorizePayment)
        return result
    }

    package func deleteSavedCard(cardId: String) async throws -> SheetState {
        try await engine.deleteSavedCard(cardId: cardId)
        let cards = try await engine.refreshSavedCards()
        guard let current = state else {
            throw PaymentError.load("Missing session state")
        }
        let updated = current.withSavedCards(cards)
        state = updated
        return updated
    }

    package func makeWalletAuthorizer(presenter: ThreeDSPresenter) -> (any DigitalWalletAuthorizing)? {
        guard let state else { return nil }
        return DigitalWalletFactory.makeApplePay?(engine, presenter, state.orderInfo)
    }

    package var onCardHolderVerification: ((CardHolderVerificationResult) -> Bool)? {
        get { engine.onCardHolderVerification }
        set { engine.onCardHolderVerification = newValue }
    }

    private func injectCardHolderVerification() {
        if let callback = configuration.card.cardHolderVerification?.onCardHolderVerification {
            engine.onCardHolderVerification = callback
        }
    }

    private func submit(
        didAuthorize: Bool,
        operation: () async throws -> EngineResult
    ) async -> EngineResult {
        guard beginOperation() else { return Self.canceled }
        do {
            let result = try await operation()
            finish(result, didAuthorize: didAuthorize)
            return result
        } catch is CancellationError {
            isProcessing = false
            return Self.canceled
        } catch let error as PaymentError {
            return finishFailed(error)
        } catch {
            return finishFailed(.payment(error.localizedDescription))
        }
    }

    private func beginOperation() -> Bool {
        guard !isProcessing, !isOrderConsumed else { return false }
        isProcessing = true
        return true
    }

    private func finish(_ result: EngineResult, didAuthorize: Bool) {
        isProcessing = false
        if OrderConsumption.shouldConsume(status: result.status, didAuthorize: didAuthorize) {
            isOrderConsumed = true
        }
    }

    private func finishFailed(_ error: PaymentError) -> EngineResult {
        let failed = EngineResult.failed(error)
        finish(failed, didAuthorize: true)
        return failed
    }

    private static func key(for intent: PaymentIntent) -> String {
        "\(intent.orderPayload):\(intent.orderChecksum)"
    }

    private static let canceled = EngineResult(
        status: .canceled,
        transaction: nil,
        errorCode: nil,
        errorMessage: nil
    )
}
