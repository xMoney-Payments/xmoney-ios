import SwiftUI
import UIKit
import XCTest
@testable import XMoneyPaymentElement
@testable import XMoneyCore

private actor EmbeddedOrderGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}

private enum EmbeddedOrderError: Error {
    case failed
}

final class EmbeddedSmokeTests: XCTestCase {
    func testCheckoutThemeResolvesPrimary() {
        let config = PaymentConfig(publicKey: "pk_test_x")
        let theme = CheckoutTheme.resolve(config: config, isDark: false)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        theme.primary.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Int(r * 255), 0x7C)
        XCTAssertEqual(Int(g * 255), 0x4D)
        XCTAssertEqual(Int(b * 255), 0xFF)
    }

    func testBrandPrimaryIsXMoneyPurple() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        CheckoutTheme.brandPrimary.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Int(r * 255), 0x7C)
        XCTAssertEqual(Int(g * 255), 0x4D)
        XCTAssertEqual(Int(b * 255), 0xFF)
    }

    func testEmbeddedEventCasesExist() {
        let ready = EmbeddedEvent.ready
        let processing = EmbeddedEvent.processing(true)
        if case .ready = ready {} else { XCTFail() }
        if case .processing(let value) = processing {
            XCTAssertTrue(value)
        } else {
            XCTFail()
        }
    }

    @MainActor
    func testPersonalDetailsFormStaysVisibleInTheSheet() {
        let visibility = CustomerDetailsVisibility.resolve(
            fields: ["firstName", "email", "phone", "country", "city", "zipCode", "address"]
        )
        let cases: [PaymentConfig] = [
            PaymentConfig(publicKey: "pk_test_x"),
            PaymentConfig(
                publicKey: "pk_test_x",
                card: .init(inputs: .init(grouping: .spaced))
            ),
            PaymentConfig(
                publicKey: "pk_test_x",
                options: .init(locale: "el-GR")
            ),
        ]
        for config in cases {
            let details = PersonalDetailsViewController(
                config: config,
                visibility: visibility,
                initialValues: PersonalDetailsValues()
            )
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
            window.rootViewController = details
            window.makeKeyAndVisible()
            details.view.layoutIfNeeded()

            let scroll = details.view.firstScrollView()
            XCTAssertGreaterThan(scroll?.bounds.height ?? 0, 200, config.options.locale)
            XCTAssertGreaterThan(scroll?.firstTextField()?.bounds.height ?? 0, 0)
            let title = details.view.firstMultilineLabel()
            if config.options.locale == "el-GR" {
                XCTAssertGreaterThan(
                    title?.bounds.height ?? 0,
                    40,
                    "Greek title height \(title?.bounds.height ?? 0)"
                )
            }
        }
    }

    @MainActor
    func testCountryChangeShowsThePostalErrorBeforeSubmit() {
        let visibility = CustomerDetailsVisibility.resolve(fields: ["country", "city", "zipCode", "address"])
        let config = PaymentConfig(publicKey: "pk_test_x", card: .init(validationMode: .onSubmit))
        let form = PersonalDetailsFormView(
            theme: CheckoutTheme.resolve(config: config, isDark: false),
            visibility: visibility,
            validationMode: .onSubmit,
            locale: "en",
            grouping: .spaced,
            values: PersonalDetailsValues(country: "US", postalCode: "12")
        )
        let postal = form.firstTextField(withText: "12")
        form.textFieldDidEndEditing(postal!)
        XCTAssertFalse(form.containsVisibleText("Please enter a valid ZIP code."))
        form.setCountry("RO")
        XCTAssertTrue(form.containsVisibleText("Please enter a valid postal code."))
    }

    @MainActor
    func testCountryChangeUpdatesRegionAndPostalAccessibilityLabels() {
        let visibility = CustomerDetailsVisibility.resolve(fields: ["country", "state", "zipCode", "address"])
        let config = PaymentConfig(publicKey: "pk_test_x")
        let form = PersonalDetailsFormView(
            theme: CheckoutTheme.resolve(config: config, isDark: false),
            visibility: visibility,
            validationMode: .onSubmit,
            locale: "en",
            grouping: .spaced,
            values: PersonalDetailsValues(country: "US")
        )
        XCTAssertNotNil(form.firstControl(accessibilityLabel: Strings.text("personalDetails.region.state", locale: "en")))
        XCTAssertNotNil(form.firstControl(accessibilityLabel: Strings.text("personalDetails.postal.zipCode", locale: "en")))
        form.setCountry("CA")
        XCTAssertNil(form.firstControl(accessibilityLabel: Strings.text("personalDetails.region.state", locale: "en")))
        XCTAssertNotNil(form.firstControl(accessibilityLabel: Strings.text("personalDetails.region.province", locale: "en")))
        XCTAssertNotNil(form.firstControl(accessibilityLabel: Strings.text("personalDetails.postal.postalCode", locale: "en")))
    }

    @MainActor
    func testCondensedFormShowsSectionErrorsOnSubmit() {
        let visibility = CustomerDetailsVisibility.resolve(fields: ["firstName", "email", "country", "address"])
        let config = PaymentConfig(publicKey: "pk_test_x")
        let form = PersonalDetailsFormView(
            theme: CheckoutTheme.resolve(config: config, isDark: false),
            visibility: visibility,
            validationMode: .onSubmit,
            locale: "en",
            grouping: .condensed,
            values: PersonalDetailsValues()
        )
        XCTAssertFalse(form.validateAndShowErrors())
        XCTAssertTrue(form.containsVisibleText(Strings.text("personalDetails.errors.fullNameRequired", locale: "en")))
        XCTAssertTrue(form.containsVisibleText(Strings.text("personalDetails.errors.countryRequired", locale: "en")))
    }

    @MainActor
    func testEmbeddedFormShowsThePersonalDetailsRow() {
        let form = Self.detailsForm(savedCards: [])
        form.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        form.layoutIfNeeded()
        XCTAssertNotNil(form.firstSubview(of: PersonalDetailsEntryRow.self))
    }

    @MainActor
    func testNewCardPayStaysBlockedUntilPersonalDetailsAreComplete() {
        let progress = PersonalDetailsProgress()
        let form = Self.detailsForm(savedCards: [], progress: progress)
        form.frame = CGRect(x: 0, y: 0, width: 390, height: 900)
        form.layoutIfNeeded()
        form.setTextField(accessibilityLabel: "Card Number", text: "4242424242424242")
        form.setTextField(accessibilityLabel: "Expiration Date", text: "1230")
        form.setTextField(accessibilityLabel: "CVV", text: "123")
        form.setTextField(accessibilityLabel: "Cardholder Name", text: "Ada Lovelace")

        var paid: CustomerDetails??
        form.onPayCard = { _, details in paid = details }
        form.confirm()
        XCTAssertNil(paid)
        XCTAssertTrue(form.containsVisibleText(Strings.text("personalDetails.completeDetails", locale: "en")))

        progress.commit(PersonalDetailsValues(email: "ada@example.com"))
        form.refreshPersonalDetailsRow()
        form.confirm()
        XCTAssertEqual(paid??.email, "ada@example.com")
    }

    @MainActor
    func testSavedCardPayStaysBlockedUntilPersonalDetailsAreComplete() {
        let progress = PersonalDetailsProgress()
        let card = SavedCard(id: "card_1", cardNumber: "4242", cardType: "visa", cardExpiryDate: "12/30")
        let form = Self.detailsForm(savedCards: [card], progress: progress)
        form.frame = CGRect(x: 0, y: 0, width: 390, height: 900)
        form.layoutIfNeeded()

        var selected: CustomerDetails??
        form.onSelectSaved = { _, details in selected = details }
        form.confirm()
        XCTAssertNil(selected)
        XCTAssertTrue(form.containsVisibleText(Strings.text("personalDetails.completeDetails", locale: "en")))

        progress.commit(PersonalDetailsValues(email: "ada@example.com"))
        form.refreshPersonalDetailsRow()
        form.confirm()
        XCTAssertEqual(selected??.email, "ada@example.com")
    }

    @MainActor
    func testHostConfirmValidatesAnOpenDetailsPageThenPays() {
        let visibility = CustomerDetailsVisibility.resolve(fields: ["email"])
        let state = SheetState(
            sessionToken: "tok",
            orderInfo: OrderPayloadInfo(
                cardTransactionMode: nil,
                isVerifyCard: false,
                amount: 19.99,
                currency: "EUR",
                externalOrderId: "order-1",
                isRecurring: false
            ),
            savedCards: [],
            applePayAvailable: false,
            customerDetailsVisibility: visibility
        )
        let payment = EmbeddedPayment(
            configuration: PaymentConfig(publicKey: "pk_test_x", customerDetails: .init(card: true))
        ) { _ in }
        payment._controller.preview(state)
        let element = PaymentElement(payment: payment) { _ in }
        element.mountPreview()

        let host = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 900))
        window.rootViewController = host
        window.makeKeyAndVisible()
        element.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(element)
        NSLayoutConstraint.activate([
            element.topAnchor.constraint(equalTo: host.view.topAnchor),
            element.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            element.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
        ])
        host.view.layoutIfNeeded()
        element.firstSubview(of: PersonalDetailsEntryRow.self)?.onTap?()
        host.view.layoutIfNeeded()

        element.confirm()
        XCTAssertFalse(state.personalDetails.isComplete)
        XCTAssertTrue(element.containsVisibleText(Strings.text("personalDetails.errors.emailRequired", locale: "en")))
        XCTAssertTrue(element.containsVisibleText(Strings.text("personalDetails.continue", locale: "en")))
        XCTAssertFalse(element.containsVisibleText(Strings.text("errors.cardNumberRequired", locale: "en")))

        let filled = SheetState(
            sessionToken: "tok",
            orderInfo: state.orderInfo,
            savedCards: [],
            applePayAvailable: false,
            customerDetailsVisibility: visibility
        )
        filled.personalDetails.draft = PersonalDetailsValues(email: "ada@example.com")
        let filledPayment = EmbeddedPayment(
            configuration: PaymentConfig(publicKey: "pk_test_x", customerDetails: .init(card: true))
        ) { _ in }
        filledPayment._controller.preview(filled)
        let filledElement = PaymentElement(payment: filledPayment) { _ in }
        filledElement.mountPreview()
        filledElement.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(filledElement)
        NSLayoutConstraint.activate([
            filledElement.topAnchor.constraint(equalTo: host.view.topAnchor),
            filledElement.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            filledElement.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
        ])
        host.view.layoutIfNeeded()
        filledElement.firstSubview(of: PersonalDetailsEntryRow.self)?.onTap?()
        host.view.layoutIfNeeded()
        filledElement.confirm()

        XCTAssertTrue(filled.personalDetails.isComplete)
        XCTAssertEqual(filled.personalDetails.committed?.email, "ada@example.com")
        XCTAssertFalse(filledElement.containsVisibleText(Strings.text("personalDetails.continue", locale: "en")))
        XCTAssertTrue(filledElement.containsVisibleText(Strings.text("errors.cardNumberRequired", locale: "en")))
    }

    @MainActor
    func testCountrySelectExposesItsValueToAccessibility() {
        let visibility = CustomerDetailsVisibility.resolve(fields: ["country"])
        let config = PaymentConfig(publicKey: "pk_test_x")
        let form = PersonalDetailsFormView(
            theme: CheckoutTheme.resolve(config: config, isDark: false),
            visibility: visibility,
            validationMode: .onSubmit,
            locale: "en",
            grouping: .spaced,
            values: PersonalDetailsValues()
        )
        form.setCountry("DE")
        let match = form.firstAccessibilityElement { element in
            element.accessibilityTraits.contains(.button)
                && (element.accessibilityValue ?? "").contains("Germany")
        }
        XCTAssertNotNil(match)
    }

    private static func makeDetailsPage(
        presentation: PersonalDetailsPresentation = .sheet
    ) -> PersonalDetailsViewController {
        let visibility = CustomerDetailsVisibility.resolve(
            fields: ["firstName", "email", "phone", "country", "city", "zipCode", "address"]
        )
        return PersonalDetailsViewController(
            config: PaymentConfig(publicKey: "pk_test_x"),
            visibility: visibility,
            initialValues: PersonalDetailsValues(),
            presentation: presentation
        )
    }

    private static func detailsForm(
        savedCards: [SavedCard],
        progress: PersonalDetailsProgress = PersonalDetailsProgress()
    ) -> PaymentFormView {
        let visibility = CustomerDetailsVisibility.resolve(fields: ["email"])
        let state = SheetState(
            sessionToken: "tok",
            orderInfo: OrderPayloadInfo(
                cardTransactionMode: nil,
                isVerifyCard: false,
                amount: 19.99,
                currency: "EUR",
                externalOrderId: "order-1",
                isRecurring: false
            ),
            savedCards: savedCards,
            applePayAvailable: false,
            customerDetailsVisibility: visibility,
            personalDetails: progress
        )
        return PaymentFormView(
            config: PaymentConfig(
                publicKey: "pk_test_x",
                customerDetails: .init(card: true)
            ),
            state: state
        )
    }

    @MainActor
    func testPersonalDetailsScrollsOnlyWhenThePageOverflows() {
        let fittedWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 2000))
        let fitted = Self.makeDetailsPage()
        fittedWindow.rootViewController = fitted
        fittedWindow.makeKeyAndVisible()
        fitted.view.layoutIfNeeded()
        let fittedScroll = fitted.view.firstScrollView()
        XCTAssertNotNil(fittedScroll)
        XCTAssertEqual(fittedScroll?.showsVerticalScrollIndicator, false)
        XCTAssertEqual(fittedScroll?.showsHorizontalScrollIndicator, false)
        XCTAssertLessThanOrEqual(fittedScroll?.contentSize.height ?? 0, (fittedScroll?.bounds.height ?? 0) + 1)
        XCTAssertEqual(fittedScroll?.isScrollEnabled, false)
        XCTAssertEqual(fittedScroll?.bounces, false)

        let shortWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 220))
        let overflow = Self.makeDetailsPage()
        shortWindow.rootViewController = overflow
        shortWindow.makeKeyAndVisible()
        overflow.view.layoutIfNeeded()
        let overflowScroll = overflow.view.firstScrollView()
        XCTAssertGreaterThan(
            overflowScroll?.contentSize.height ?? 0,
            (overflowScroll?.bounds.height ?? 0) + 1
        )
        XCTAssertEqual(overflowScroll?.isScrollEnabled, true)
        XCTAssertEqual(overflowScroll?.showsVerticalScrollIndicator, false)

        let inlineWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        let inline = Self.makeDetailsPage(presentation: .inline)
        inlineWindow.rootViewController = inline
        inlineWindow.makeKeyAndVisible()
        inline.view.layoutIfNeeded()
        XCTAssertNil(inline.view.firstScrollView())
    }

    @MainActor
    func testEmbeddedElementSwapsInPersonalDetails() {
        let visibility = CustomerDetailsVisibility.resolve(fields: ["email"])
        let state = SheetState(
            sessionToken: "tok",
            orderInfo: OrderPayloadInfo(
                cardTransactionMode: nil,
                isVerifyCard: false,
                amount: 19.99,
                currency: "EUR",
                externalOrderId: "order-1",
                isRecurring: false
            ),
            savedCards: [],
            applePayAvailable: false,
            customerDetailsVisibility: visibility
        )
        let payment = EmbeddedPayment(
            configuration: PaymentConfig(publicKey: "pk_test_x", customerDetails: .init(card: true))
        ) { _ in }
        payment._controller.preview(state)
        let element = PaymentElement(payment: payment) { _ in }
        element.mountPreview()

        let host = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 900))
        window.rootViewController = host
        window.makeKeyAndVisible()
        element.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(element)
        NSLayoutConstraint.activate([
            element.topAnchor.constraint(equalTo: host.view.topAnchor),
            element.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            element.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
        ])
        host.view.layoutIfNeeded()

        let form = element.firstSubview(of: PaymentFormView.self)
        let formHeight = element.intrinsicContentSize.height
        XCTAssertNotNil(form)
        XCTAssertGreaterThan(formHeight, 160)

        var reported = formHeight
        element.onContentSizeChange = { [weak element] in
            reported = element?.intrinsicContentSize.height ?? 0
        }

        element.firstSubview(of: PersonalDetailsEntryRow.self)?.onTap?()
        host.view.layoutIfNeeded()

        let details = host.children.first { $0 is PersonalDetailsViewController } as? PersonalDetailsViewController
        XCTAssertNotNil(details)
        XCTAssertNil(form?.superview)
        XCTAssertEqual(element.intrinsicContentSize.height, details?.contentHeight ?? -1)
        XCTAssertEqual(reported, details?.contentHeight ?? -1)
        XCTAssertTrue(element.containsVisibleText(Strings.text("personalDetails.continue", locale: "en")))

        let back = element.firstButton(accessibilityLabel: Strings.text("personalDetails.back", locale: "en"))
        XCTAssertNotNil(back)
        back?.sendActions(for: .touchUpInside)
        host.view.layoutIfNeeded()

        XCTAssertTrue(host.children.isEmpty)
        XCTAssertEqual(form?.superview, element)
        XCTAssertFalse(element.containsVisibleText(Strings.text("personalDetails.continue", locale: "en")))
        XCTAssertEqual(element.intrinsicContentSize.height, formHeight)
    }

    @MainActor
    func testDetailsRowStaysPutWhenSwitchingToANewCard() {
        let card = SavedCard(id: "card_1", cardNumber: "4242", cardType: "visa", cardExpiryDate: "12/30")
        let visibility = CustomerDetailsVisibility.resolve(fields: ["email"])
        let state = SheetState(
            sessionToken: "tok",
            orderInfo: OrderPayloadInfo(
                cardTransactionMode: nil,
                isVerifyCard: false,
                amount: 19.99,
                currency: "EUR",
                externalOrderId: "order-1",
                isRecurring: false
            ),
            savedCards: [card],
            applePayAvailable: false,
            customerDetailsVisibility: visibility
        )
        let payment = EmbeddedPayment(
            configuration: PaymentConfig(publicKey: "pk_test_x", customerDetails: .init(card: true))
        ) { _ in }
        payment._controller.preview(state)
        let element = PaymentElement(payment: payment) { _ in }
        element.mountPreview()

        let host = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 900))
        window.rootViewController = host
        window.makeKeyAndVisible()
        element.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(element)
        NSLayoutConstraint.activate([
            element.topAnchor.constraint(equalTo: host.view.topAnchor),
            element.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            element.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
        ])
        host.view.layoutIfNeeded()

        let heightLock = element.heightAnchor.constraint(equalToConstant: element.bounds.height)
        heightLock.isActive = true
        host.view.layoutIfNeeded()

        let row = element.firstSubview(of: PersonalDetailsEntryRow.self)
        XCTAssertNotNil(row)
        let before = row?.convert(row?.bounds ?? .zero, to: element) ?? .zero
        XCTAssertGreaterThan(before.height, 1)

        element.firstSubview(of: PaymentMethodContainerView.self)?.onUseOtherCard?()
        host.view.layoutIfNeeded()

        let after = row?.convert(row?.bounds ?? .zero, to: element) ?? .zero
        XCTAssertEqual(after.minY, before.minY, accuracy: 0.5)
        XCTAssertEqual(after.height, before.height, accuracy: 0.5)
        XCTAssertEqual(element.bounds.height, heightLock.constant, accuracy: 0.5)
        let fitting = row?.systemLayoutSizeFitting(
            CGSize(width: max(row?.bounds.width ?? 1, 1), height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height ?? 0
        XCTAssertEqual(after.height, fitting, accuracy: 1)
    }

    @MainActor
    func testInlineCountryPickerOpensAsASheetWithoutResizing() {
        let visibility = CustomerDetailsVisibility.resolve(fields: ["country"])
        let state = SheetState(
            sessionToken: "tok",
            orderInfo: OrderPayloadInfo(
                cardTransactionMode: nil,
                isVerifyCard: false,
                amount: 19.99,
                currency: "EUR",
                externalOrderId: "order-1",
                isRecurring: false
            ),
            savedCards: [],
            applePayAvailable: false,
            customerDetailsVisibility: visibility
        )
        let payment = EmbeddedPayment(
            configuration: PaymentConfig(publicKey: "pk_test_x", customerDetails: .init(card: true))
        ) { _ in }
        payment._controller.preview(state)
        let element = PaymentElement(payment: payment) { _ in }
        element.mountPreview()

        let host = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 900))
        window.rootViewController = host
        window.makeKeyAndVisible()
        element.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(element)
        NSLayoutConstraint.activate([
            element.topAnchor.constraint(equalTo: host.view.topAnchor),
            element.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            element.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
        ])
        host.view.layoutIfNeeded()
        element.firstSubview(of: PersonalDetailsEntryRow.self)?.onTap?()
        host.view.layoutIfNeeded()

        let details = host.children.first { $0 is PersonalDetailsViewController } as? PersonalDetailsViewController
        let height = element.intrinsicContentSize.height
        XCTAssertNotNil(details)
        XCTAssertTrue(details?.view.isDescendant(of: element) == true)
        XCTAssertGreaterThan(height, 160)

        var resized = false
        element.onContentSizeChange = { resized = true }
        let country = Strings.text("personalDetails.country", locale: "en")
        let select = element.firstControl(accessibilityLabel: country)
        XCTAssertNotNil(select)
        select?.sendActions(for: .touchUpInside)

        let list = host.presentedViewController as? SelectionListViewController
        XCTAssertNotNil(list)
        XCTAssertEqual(list?.modalPresentationStyle, .pageSheet)
        XCTAssertEqual(list?.sheetPresentationController?.prefersGrabberVisible, true)
        XCTAssertEqual(list?.sheetPresentationController?.detents, [.large()])
        XCTAssertTrue(details?.view.isDescendant(of: element) == true)
        XCTAssertFalse(details?.view.isHidden == true)
        XCTAssertEqual(element.intrinsicContentSize.height, height)
        XCTAssertFalse(resized)
        XCTAssertTrue(element.containsVisibleText(Strings.text("personalDetails.continue", locale: "en")))
    }

    @MainActor
    func testUpdateAppearanceAndLocaleBeforePrepare() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        embedded.updateAppearance(.init())
        embedded.updateLocale("el-GR")
        embedded.updateStyle(.alwaysDark)
        embedded.updateWalletAppearance(.init(color: .white, radius: 12, type: .pay))
        XCTAssertEqual(embedded._controller.paymentConfig?.options.locale, "el-GR")
        XCTAssertEqual(embedded._controller.paymentConfig?.options.style, .alwaysDark)
        XCTAssertEqual(embedded._controller.paymentConfig?.paymentMethods.applePay.appearance.color, .white)
        XCTAssertFalse(embedded.isInteractionEnabled)
        embedded.confirm()
    }

    @MainActor
    func testConfirmIsNoOpWhileUpdatingOrderFlag() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        XCTAssertFalse(embedded.isInteractionEnabled)
        embedded.confirm()
    }

    @MainActor
    func testCreateOrderLocksImmediatelyAndRestoresStateAfterFailure() async {
        let started = expectation(description: "create order started")
        let gate = EmbeddedOrderGate()
        var resultCount = 0
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in
            resultCount += 1
        }

        let update = Task { @MainActor in
            try await embedded.updateOrder {
                started.fulfill()
                await gate.wait()
                throw EmbeddedOrderError.failed
            }
        }

        await fulfillment(of: [started], timeout: 1)
        XCTAssertTrue(embedded._controller.isUpdatingOrder)
        XCTAssertFalse(embedded.isInteractionEnabled)

        await gate.open()
        do {
            try await update.value
            XCTFail("Expected createOrder to throw")
        } catch {
            XCTAssertTrue(error is EmbeddedOrderError)
        }

        XCTAssertFalse(embedded._controller.isUpdatingOrder)
        XCTAssertEqual(resultCount, 0)
    }

    @MainActor
    func testCreateOrderWithoutEventHandlerKeepsExistingHandler() async {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        var processingEvents: [Bool] = []

        do {
            try await embedded.updateOrder(
                onEvent: { event in
                    if case let .processing(value) = event {
                        processingEvents.append(value)
                    }
                },
                createOrder: { throw EmbeddedOrderError.failed }
            )
            XCTFail("Expected createOrder to throw")
        } catch {
            XCTAssertTrue(error is EmbeddedOrderError)
        }

        do {
            try await embedded.updateOrder {
                throw EmbeddedOrderError.failed
            }
            XCTFail("Expected createOrder to throw")
        } catch {
            XCTAssertTrue(error is EmbeddedOrderError)
        }

        embedded._controller.emit(.processing(true))
        XCTAssertEqual(processingEvents, [true])
    }

    @MainActor
    func testSupersededCreateOrderFailureThrowsCancellation() async {
        let started = expectation(description: "first create order started")
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }

        let first = Task { @MainActor in
            try await embedded.updateOrder {
                started.fulfill()
                try await Task.sleep(nanoseconds: 10_000_000_000)
                return PaymentIntent(
                    orderPayload: OrderPayload("e30="),
                    orderChecksum: OrderChecksum("first")
                )
            }
        }
        await fulfillment(of: [started], timeout: 1)

        do {
            try await embedded.updateOrder {
                throw EmbeddedOrderError.failed
            }
            XCTFail("Expected second createOrder to throw")
        } catch {
            XCTAssertTrue(error is EmbeddedOrderError)
        }

        do {
            try await first.value
            XCTFail("Expected superseded update to be canceled")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    @MainActor
    func testRevealWhileLoaderVisibleHidesCoverAndEmitsReadyOnce() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        element._installFormForTesting(config: PaymentConfig(publicKey: "pk_test_x"), state: Self.sampleState())

        XCTAssertTrue(element.isLoaderVisible)
        element.revealIfNeeded()
        element.revealIfNeeded()

        XCTAssertFalse(element.isLoaderVisible)
        XCTAssertEqual(readyCount, 1)
    }

    @MainActor
    func testRevealWithoutAFormDoesNotEmitReady() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }

        element.revealIfNeeded()

        XCTAssertTrue(element.isLoaderVisible)
        XCTAssertEqual(readyCount, 0)
    }

    @MainActor
    func testFailureStateReplacesLoaderWithLocalizedMessageAndNoReady() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }

        element.showFailure(PaymentError.load("raw server response"))
        element.revealIfNeeded()

        XCTAssertFalse(element.isLoaderVisible)
        XCTAssertTrue(element.isFailureVisible)
        XCTAssertEqual(element.failureMessage, Strings.text("element.loadFailed", locale: "en"))
        XCTAssertEqual(readyCount, 0)
    }

    @MainActor
    func testReadyIsScopedToEachMountedElement() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        var readyCount = 0

        for _ in 0..<2 {
            let element = PaymentElement(payment: embedded) { event in
                if case .ready = event { readyCount += 1 }
            }
            element._installFormForTesting(config: PaymentConfig(publicKey: "pk_test_x"), state: Self.sampleState())
            element.revealIfNeeded()
        }

        XCTAssertEqual(readyCount, 2)
    }

    @MainActor
    func testPrepareRendersDrawsAndEmitsReadyOncePerSurface() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        embedded._controller.testingLoad = { _ in Self.sampleState() }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        let window = Self.host(element)

        try await element.prepare(intent: Self.sampleIntent("a"))

        XCTAssertTrue(element.isFormVisible)
        XCTAssertEqual(readyCount, 1)
        XCTAssertFalse(element.isPayLockedForTesting)

        try await element.updateOrder(intent: Self.sampleIntent("b"))
        XCTAssertEqual(embedded.boundIntent, Self.sampleIntent("b"))
        XCTAssertEqual(readyCount, 1)
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testPrepareOutsideAWindowRevealsOnceMounted() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        embedded._controller.testingLoad = { _ in Self.sampleState() }
        let ready = expectation(description: "ready")
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event {
                readyCount += 1
                ready.fulfill()
            }
        }

        try await element.prepare(intent: Self.sampleIntent("a"))
        XCTAssertEqual(readyCount, 0)

        let window = Self.host(element)
        await fulfillment(of: [ready], timeout: 3)
        XCTAssertTrue(element.isFormVisible)
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testInitialFailureHasNoReadyThenARetryEmitsReady() async throws {
        var results: [PaymentResult] = []
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { results.append($0) }
        var loads = 0
        embedded._controller.testingLoad = { _ in
            loads += 1
            if loads <= 2 { throw PaymentError.load("raw server response") }
            return Self.sampleState()
        }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        let window = Self.host(element)

        for _ in 0..<2 {
            do {
                try await element.prepare(intent: Self.sampleIntent("a"))
                XCTFail("Expected prepare to throw")
            } catch {
                XCTAssertTrue(error is PaymentError)
            }
        }
        XCTAssertTrue(element.isFailureVisible)
        XCTAssertEqual(readyCount, 0)
        XCTAssertEqual(results.count, 1, "`.failed` is reported once per failure streak")

        try await element.prepare(intent: Self.sampleIntent("a"))
        XCTAssertFalse(element.isFailureVisible)
        XCTAssertTrue(element.isFormVisible)
        XCTAssertEqual(readyCount, 1)
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testSupersededFirstPrepareShowsNoFailureAndTheNewerBindRenders() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let gate = EmbeddedOrderGate()
        let firstStarted = expectation(description: "first load started")
        embedded._controller.testingLoad = { intent in
            if intent == Self.sampleIntent("a") {
                firstStarted.fulfill()
                await gate.wait()
                throw PaymentError.load("raw server response")
            }
            return Self.sampleState()
        }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        let window = Self.host(element)

        let first = Task { @MainActor in try await element.prepare(intent: Self.sampleIntent("a")) }
        await fulfillment(of: [firstStarted], timeout: 1)
        try await element.prepare(intent: Self.sampleIntent("b"))
        await gate.open()

        do {
            try await first.value
            XCTFail("Expected the first prepare to be superseded")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertFalse(element.isFailureVisible)
        XCTAssertTrue(element.isFormVisible)
        XCTAssertEqual(readyCount, 1)
        XCTAssertEqual(embedded.boundIntent, Self.sampleIntent("b"))
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testCreateOrderWithoutAFormLocksPayAndRendersOnReturn() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        embedded._controller.testingLoad = { _ in Self.sampleState() }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        let window = Self.host(element)
        let started = expectation(description: "create order started")
        let gate = EmbeddedOrderGate()

        let update = Task { @MainActor in
            try await element.updateOrder {
                started.fulfill()
                await gate.wait()
                return Self.sampleIntent("a")
            }
        }
        await fulfillment(of: [started], timeout: 1)
        XCTAssertTrue(embedded._controller.isUpdatingOrder)
        XCTAssertFalse(embedded.isInteractionEnabled)
        XCTAssertTrue(element.isLoaderVisible)

        await gate.open()
        let bound = try await update.value
        XCTAssertEqual(bound, Self.sampleIntent("a"))
        XCTAssertTrue(element.isFormVisible)
        XCTAssertTrue(embedded.isInteractionEnabled)
        XCTAssertEqual(readyCount, 1)
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testLaterBindFailureLocksPayOnTheStaleOrderAndEmitsUpdateFailed() async throws {
        var results = 0
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in results += 1 }
        embedded._controller.testingLoad = { _ in Self.sampleState() }
        let updateFailed = expectation(description: "updateFailed")
        let element = PaymentElement(payment: embedded) { event in
            if case .updateFailed = event { updateFailed.fulfill() }
        }
        let window = Self.host(element)
        try await element.prepare(intent: Self.sampleIntent("a"))

        embedded._controller.testingLoad = { _ in throw PaymentError.load("raw server response") }
        do {
            try await element.updateOrder(intent: Self.sampleIntent("b"))
            XCTFail("Expected bind to throw")
        } catch {
            XCTAssertTrue(error is PaymentError)
        }
        await fulfillment(of: [updateFailed], timeout: 1)

        XCTAssertEqual(embedded.boundIntent, Self.sampleIntent("a"))
        XCTAssertFalse(embedded.isInteractionEnabled)
        XCTAssertTrue(element.isPayLockedForTesting)
        XCTAssertTrue(element.isFormVisible)
        XCTAssertEqual(results, 0)

        embedded._controller.testingLoad = { _ in Self.sampleState() }
        try await element.updateOrder(intent: Self.sampleIntent("b"))
        XCTAssertTrue(embedded.isInteractionEnabled)
        XCTAssertFalse(element.isPayLockedForTesting)
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testCreateOrderFailureKeepsThePreviousOrderPayable() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        try embedded._controller.testingInstallBound(Self.sampleIntent("a"), state: Self.sampleState())

        do {
            try await embedded.updateOrder { throw EmbeddedOrderError.failed }
            XCTFail("Expected createOrder to throw")
        } catch {
            XCTAssertTrue(error is EmbeddedOrderError)
        }

        XCTAssertEqual(embedded.boundIntent, Self.sampleIntent("a"))
        XCTAssertTrue(embedded.isInteractionEnabled)
    }

    @MainActor
    func testCreateOrderRunsOnTheMainActorAndReturnsTheBoundIntent() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        try embedded._controller.testingInstallBound(Self.sampleIntent("a"), state: Self.sampleState())
        embedded._controller.testingLoad = { _ in Self.sampleState() }
        var ranOnMain = false

        let bound = try await embedded.updateOrder {
            ranOnMain = Thread.isMainThread
            return Self.sampleIntent("b")
        }

        XCTAssertTrue(ranOnMain)
        XCTAssertEqual(bound, Self.sampleIntent("b"))
        XCTAssertEqual(embedded.boundIntent, Self.sampleIntent("b"))
    }

    @MainActor
    func testCancellingTheCallerCancelsCreateOrder() async {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let started = expectation(description: "create order started")
        let cancelled = expectation(description: "create order cancelled")
        let update = Task { @MainActor in
            try await embedded.updateOrder {
                started.fulfill()
                do {
                    try await Task.sleep(nanoseconds: 10_000_000_000)
                } catch {
                    cancelled.fulfill()
                    throw error
                }
                return Self.sampleIntent("never")
            }
        }
        await fulfillment(of: [started], timeout: 1)
        update.cancel()
        await fulfillment(of: [cancelled], timeout: 1)

        do {
            _ = try await update.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertFalse(embedded._controller.isUpdatingOrder)
    }

    @MainActor
    func testOlderBindFinishingLastDoesNotOverwriteTheNewerOrder() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        try embedded._controller.testingInstallBound(Self.sampleIntent("a"), state: Self.sampleState())
        let gate = EmbeddedOrderGate()
        let olderStarted = expectation(description: "older load started")
        embedded._controller.testingLoad = { intent in
            if intent == Self.sampleIntent("b") {
                olderStarted.fulfill()
                await gate.wait()
            }
            return Self.sampleState()
        }

        let older = Task { @MainActor in try await embedded.updateOrder(intent: Self.sampleIntent("b")) }
        await fulfillment(of: [olderStarted], timeout: 1)
        try await embedded.updateOrder(intent: Self.sampleIntent("c"))
        await gate.open()

        do {
            try await older.value
            XCTFail("Expected the older bind to be superseded")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(embedded.boundIntent, Self.sampleIntent("c"))
        XCTAssertTrue(embedded.isInteractionEnabled)
    }

    @MainActor
    func testFailedBindOfASupersededOrderDoesNotLockTheNewerOrder() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        try embedded._controller.testingInstallBound(Self.sampleIntent("a"), state: Self.sampleState())
        let gate = EmbeddedOrderGate()
        let olderStarted = expectation(description: "older load started")
        embedded._controller.testingLoad = { intent in
            if intent == Self.sampleIntent("b") {
                olderStarted.fulfill()
                await gate.wait()
                throw EmbeddedOrderError.failed
            }
            return Self.sampleState()
        }

        let older = Task { @MainActor in try await embedded.updateOrder(intent: Self.sampleIntent("b")) }
        await fulfillment(of: [olderStarted], timeout: 1)
        try await embedded.updateOrder(intent: Self.sampleIntent("c"))
        await gate.open()

        do {
            try await older.value
            XCTFail("Expected the older bind to be superseded")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertFalse(embedded._controller.isStaleOrder)
        XCTAssertTrue(embedded.isInteractionEnabled)
    }

    @MainActor
    func testFailedUpdateDuringFirstDrawRevealsCoverAndEmitsReadyOnce() async {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        element._installFormForTesting(
            config: PaymentConfig(publicKey: "pk_test_x"),
            state: Self.sampleState()
        )
        element.frame = CGRect(x: 0, y: 0, width: 390, height: 600)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UIViewController()
        window.rootViewController = root
        root.view.addSubview(element)
        window.makeKeyAndVisible()
        root.view.layoutIfNeeded()
        element.layoutIfNeeded()

        do {
            try await element.updateOrder {
                throw EmbeddedOrderError.failed
            }
            XCTFail("Expected updateOrder to throw")
        } catch {
            XCTAssertTrue(error is EmbeddedOrderError)
        }

        XCTAssertFalse(element.isLoaderVisible)
        XCTAssertEqual(readyCount, 1)
    }

    @MainActor
    func testSupersededFailureDoesNotUnlockTheNewerUpdate() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        embedded._controller.testingLoad = { _ in Self.sampleState() }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        let window = Self.host(element)
        try await element.prepare(intent: Self.sampleIntent("a"))

        let firstStarted = expectation(description: "first update started")
        let firstGate = EmbeddedOrderGate()
        let first = Task { @MainActor in
            try await element.updateOrder {
                firstStarted.fulfill()
                await firstGate.wait()
                throw EmbeddedOrderError.failed
            }
        }
        await fulfillment(of: [firstStarted], timeout: 1)

        let secondStarted = expectation(description: "second update started")
        let secondGate = EmbeddedOrderGate()
        let second = Task { @MainActor in
            try await element.updateOrder {
                secondStarted.fulfill()
                await secondGate.wait()
                return Self.sampleIntent("c")
            }
        }
        await fulfillment(of: [secondStarted], timeout: 1)

        await firstGate.open()
        do {
            _ = try await first.value
            XCTFail("Expected the first update to be superseded")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertTrue(element.isPayLockedForTesting)

        await secondGate.open()
        let bound = try await second.value
        XCTAssertEqual(bound, Self.sampleIntent("c"))
        XCTAssertFalse(element.isPayLockedForTesting)
        XCTAssertTrue(element.isFormVisible)
        XCTAssertEqual(readyCount, 1)
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testPrepareFailureShowsFailureLabelThroughTheCatchPath() async {
        var results = 0
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_invalid")) { _ in
            results += 1
        }
        let element = PaymentElement(payment: embedded)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UIViewController()
        window.rootViewController = root
        element.frame = CGRect(x: 0, y: 0, width: 390, height: 200)
        root.view.addSubview(element)
        window.makeKeyAndVisible()

        do {
            try await element.prepare(intent: Self.sampleIntent("missing"))
            XCTFail("Expected prepare to throw")
        } catch {
            XCTAssertTrue(error is PaymentError)
        }

        XCTAssertTrue(element.isFailureVisible)
        XCTAssertFalse(element.isLoaderVisible)
        XCTAssertEqual(element.failureMessage, Strings.text("element.loadFailed", locale: "en"))
        XCTAssertEqual(results, 1)
    }

    @MainActor
    func testPaymentInProgressKeepsTheLoader() async {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let bound = Self.sampleIntent("bound")
        try? embedded._controller.testingInstallBound(bound, state: Self.sampleState(), processing: true)
        let element = PaymentElement(payment: embedded)

        do {
            try await element.prepare(intent: Self.sampleIntent("other"))
            XCTFail("Expected payment in progress")
        } catch {
            XCTAssertTrue(error is PaymentError)
        }

        XCTAssertTrue(element.isLoaderVisible)
        XCTAssertFalse(element.isFailureVisible)
    }

    @MainActor
    func testSameIntentDuringPaymentIsNoOp() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let bound = Self.sampleIntent("bound")
        try embedded._controller.testingInstallBound(bound, state: Self.sampleState(), processing: true)
        try await embedded.updateOrder(intent: bound)
    }

    @MainActor
    func testDifferentIntentDuringPaymentThrowsPaymentInProgress() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        try embedded._controller.testingInstallBound(Self.sampleIntent("bound"), state: Self.sampleState(), processing: true)

        do {
            try await embedded.updateOrder(intent: Self.sampleIntent("other"))
            XCTFail("Expected payment in progress")
        } catch let error as PaymentError {
            XCTAssertEqual(error, .paymentInProgress)
        }
        do {
            _ = try await embedded.updateOrder { Self.sampleIntent("other") }
            XCTFail("Expected payment in progress")
        } catch let error as PaymentError {
            XCTAssertEqual(error, .paymentInProgress)
        }
        XCTAssertEqual(embedded.boundIntent, Self.sampleIntent("bound"))
    }

    @MainActor
    func testMerchantCallWithTheBoundIntentSupersedesInFlightCreation() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let bound = Self.sampleIntent("bound")
        try embedded._controller.testingInstallBound(bound, state: Self.sampleState())
        let started = expectation(description: "create order started")
        let first = Task { @MainActor in
            try await embedded.updateOrder {
                started.fulfill()
                try await Task.sleep(nanoseconds: 10_000_000_000)
                return Self.sampleIntent("late")
            }
        }
        await fulfillment(of: [started], timeout: 1)

        try await embedded.updateOrder(intent: bound)

        do {
            _ = try await first.value
            XCTFail("Expected the in-flight creation to be superseded")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(embedded.boundIntent, bound)
        XCTAssertTrue(embedded.isInteractionEnabled)
    }

    @MainActor
    func testSurfaceUpdateDoesNotCancelInFlightMerchantUpdate() async throws {
        for origin in [BindOrigin.surfaceMount, .surfaceUpdate] {
            let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
            let bound = Self.sampleIntent("bound")
            try embedded._controller.testingInstallBound(bound, state: Self.sampleState())
            embedded._controller.testingLoad = { _ in Self.sampleState() }
            let started = expectation(description: "create order started")
            let gate = EmbeddedOrderGate()
            let update = Task { @MainActor in
                try await embedded.updateOrder {
                    started.fulfill()
                    await gate.wait()
                    return Self.sampleIntent("next")
                }
            }
            await fulfillment(of: [started], timeout: 1)

            try await embedded._controller.prepare(intent: bound, origin: origin)
            XCTAssertTrue(embedded._controller.isUpdatingOrder)
            XCTAssertFalse(embedded.isInteractionEnabled)

            await gate.open()
            let next = try await update.value
            XCTAssertEqual(next, Self.sampleIntent("next"))
            XCTAssertEqual(embedded.boundIntent, next)
        }
    }

    @MainActor
    func testSurfaceUpdateBackToBoundIntentClearsStaleLock() async throws {
        let (embedded, element, window) = try await Self.staleElement()
        let coordinator = PaymentElementView.Coordinator()
        coordinator.element = element
        let intent = Self.sampleIntent("a")

        coordinator.bind(intent: intent, key: PaymentElementView.key(for: intent), origin: .surfaceUpdate, to: element)
        await coordinator.prepareTask?.value

        XCTAssertFalse(embedded._controller.isStaleOrder)
        XCTAssertTrue(embedded.isInteractionEnabled)
        XCTAssertFalse(element.isPayLockedForTesting)
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testSurfaceMountWithBoundIntentKeepsStaleLock() async throws {
        let (embedded, element, window) = try await Self.staleElement()
        let coordinator = PaymentElementView.Coordinator()
        coordinator.element = element
        let intent = Self.sampleIntent("a")

        coordinator.bind(intent: intent, key: PaymentElementView.key(for: intent), origin: .surfaceMount, to: element)
        await coordinator.prepareTask?.value

        XCTAssertTrue(embedded._controller.isStaleOrder)
        XCTAssertFalse(embedded.isInteractionEnabled)
        XCTAssertTrue(element.isPayLockedForTesting)
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testAppearanceChangeDuringRevealStillRevealsAndEmitsReadyOnce() async throws {
        try await assertRevealSurvivesRebuild { embedded, _ in
            embedded.updateAppearance(.init())
        }
    }

    @MainActor
    func testBindDuringRevealStillReveals() async throws {
        let embedded = try await assertRevealSurvivesRebuild { embedded, _ in
            try? await embedded.updateOrder(intent: Self.sampleIntent("b"))
        }
        XCTAssertEqual(embedded.boundIntent, Self.sampleIntent("b"))
    }

    @MainActor
    func testTraitChangeDuringRevealStillReveals() async throws {
        try await assertRevealSurvivesRebuild { _, element in
            element.overrideUserInterfaceStyle = element.traitCollection.userInterfaceStyle == .dark ? .light : .dark
            element.layoutIfNeeded()
        }
    }

    /// Mounts an Element whose order offers Apple Pay, rebuilds the form while
    /// the reveal waits on the wallet button, and expects the cover to lift.
    @MainActor
    @discardableResult
    private func assertRevealSurvivesRebuild(
        _ rebuild: @escaping @MainActor (EmbeddedPayment, PaymentElement) async -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> EmbeddedPayment {
        var config = PaymentConfig(publicKey: "pk_test_x")
        config.paymentMethods.applePay.enabled = false
        let embedded = EmbeddedPayment(configuration: config) { _ in }
        embedded._controller.testingLoad = { _ in Self.applePayState() }
        var readyCount = 0
        let element = PaymentElement(payment: embedded) { event in
            if case .ready = event { readyCount += 1 }
        }
        let window = Self.host(element)
        let rebuilt = expectation(description: "rebuilt during reveal")
        var buttonBefore: UIView?
        var buttonAfter: UIView?
        element.testingOnRevealWaitStarted = {
            Task { @MainActor in
                buttonBefore = element.walletButtonForTesting
                await rebuild(embedded, element)
                buttonAfter = element.walletButtonForTesting
                rebuilt.fulfill()
            }
        }

        try await element.prepare(intent: Self.sampleIntent("a"))
        await fulfillment(of: [rebuilt], timeout: 1)
        try await Self.waitUntil { element.isFormVisible }

        XCTAssertNotNil(buttonBefore, file: file, line: line)
        XCTAssertFalse(buttonBefore === buttonAfter, "the wallet button was rebuilt", file: file, line: line)
        XCTAssertTrue(element.isFormVisible, file: file, line: line)
        XCTAssertEqual(readyCount, 1, file: file, line: line)
        withExtendedLifetime(window) {}
        return embedded
    }

    /// Element bound to A whose bind of B failed: Pay is locked on A.
    @MainActor
    private static func staleElement() async throws -> (EmbeddedPayment, PaymentElement, UIWindow) {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        embedded._controller.testingLoad = { intent in
            if intent == Self.sampleIntent("b") { throw PaymentError.load("raw server response") }
            return Self.sampleState()
        }
        let element = PaymentElement(payment: embedded)
        let window = Self.host(element)
        try await element.prepare(intent: Self.sampleIntent("a"))
        do {
            try await element.updateOrder(intent: Self.sampleIntent("b"))
            XCTFail("Expected bind to throw")
        } catch {}
        XCTAssertTrue(embedded._controller.isStaleOrder)
        XCTAssertTrue(element.isPayLockedForTesting)
        return (embedded, element, window)
    }

    @MainActor
    func testProcessingEventsAreNotDroppedByASupersededUpdate() async {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let delivered = expectation(description: "processing delivered")
        delivered.expectedFulfillmentCount = 2
        let element = PaymentElement(payment: embedded) { event in
            if case .processing = event { delivered.fulfill() }
        }
        let started = expectation(description: "create order started")
        let update = Task { @MainActor in
            try await element.updateOrder {
                started.fulfill()
                try await Task.sleep(nanoseconds: 10_000_000_000)
                return Self.sampleIntent("never")
            }
        }
        await fulfillment(of: [started], timeout: 1)
        update.cancel()
        _ = try? await update.value

        embedded._controller.emit(.processing(true))
        embedded._controller.emit(.processing(false))
        await fulfillment(of: [delivered], timeout: 1)
    }

    @MainActor
    func testSwiftUIDoesNotRetryAFailedBindOnReRender() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let element = PaymentElement(payment: embedded)
        let coordinator = PaymentElementView.Coordinator()
        coordinator.element = element
        let intent = Self.sampleIntent("a")
        let key = PaymentElementView.key(for: intent)
        coordinator.lastOrderKey = key

        coordinator.handle(PaymentError.load("raw"), intent: intent, key: key)

        XCTAssertNil(coordinator.pendingIntent)
        XCTAssertEqual(coordinator.lastOrderKey, key)
    }

    @MainActor
    func testSwiftUIHostRetriesThePendingOrderAfterTheChargeEnds() async throws {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let bound = Self.sampleIntent("bound")
        let next = Self.sampleIntent("next")
        try embedded._controller.testingInstallBound(bound, state: Self.sampleState(), processing: true)
        embedded._controller.testingLoad = { _ in Self.sampleState() }

        let host = UIHostingController(rootView: PaymentElementView(payment: embedded, intent: next))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        try await Self.waitUntil { Self.findElement(in: host.view) != nil }
        await Task.yield()
        XCTAssertEqual(embedded.boundIntent, bound)

        try embedded._controller.testingInstallBound(bound, state: Self.sampleState(), processing: false)
        try await Self.waitUntil {
            embedded._controller.emit(.processing(false))
            return embedded.boundIntent == next
        }
        withExtendedLifetime(window) {}
    }

    @MainActor
    func testLaterBindFailureDoesNotDeliverResult() async throws {
        var results = 0
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in
            results += 1
        }
        try embedded._controller.testingInstallBound(Self.sampleIntent("bound"), state: Self.sampleState())
        embedded._controller.testingFailNextBind(PaymentError.load("raw server response"))

        do {
            try await embedded.updateOrder(intent: Self.sampleIntent("next"))
            XCTFail("Expected bind to throw")
        } catch {
            XCTAssertTrue(error is PaymentError)
        }
        XCTAssertEqual(results, 0)
    }

    @MainActor
    func testSwiftUIRetriesThePendingIntent() {
        let embedded = EmbeddedPayment(configuration: PaymentConfig(publicKey: "pk_test_x")) { _ in }
        let element = PaymentElement(payment: embedded)
        let coordinator = PaymentElementView.Coordinator()
        coordinator.element = element
        let pending = Self.sampleIntent("pending")
        coordinator.pendingIntent = pending

        coordinator.retryPendingOrder()

        XCTAssertNil(coordinator.pendingIntent)
        XCTAssertEqual(
            coordinator.lastOrderKey,
            "\(pending.orderPayload):\(pending.orderChecksum)"
        )
        coordinator.prepareTask?.cancel()
    }

    func testEmbeddedContentInsetsAreZero() {
        let insets = PaymentFormView.ContentInsets.embedded
        XCTAssertEqual(insets.horizontal, 0)
        XCTAssertEqual(insets.top, 0)
        XCTAssertEqual(insets.bottom, 0)
        XCTAssertNotEqual(insets, .sheet)
    }

    private static func sampleState() -> SheetState {
        SheetState(
            sessionToken: "tok",
            orderInfo: OrderPayloadInfo(
                cardTransactionMode: nil,
                isVerifyCard: false,
                amount: 19.99,
                currency: "EUR",
                externalOrderId: "order-1",
                isRecurring: false
            ),
            savedCards: [],
            applePayAvailable: false
        )
    }

    @MainActor
    private static func host(_ element: PaymentElement) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UIViewController()
        window.rootViewController = root
        element.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        root.view.addSubview(element)
        window.makeKeyAndVisible()
        root.view.layoutIfNeeded()
        return window
    }

    @MainActor
    private static func waitUntil(
        timeout: TimeInterval = 3,
        _ condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("Condition not met within \(timeout) seconds")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @MainActor
    private static func findElement(in view: UIView) -> PaymentElement? {
        if let element = view as? PaymentElement { return element }
        for subview in view.subviews {
            if let element = findElement(in: subview) { return element }
        }
        return nil
    }

    private static func applePayState() -> SheetState {
        SheetState(
            sessionToken: "tok",
            orderInfo: OrderPayloadInfo(
                cardTransactionMode: nil,
                isVerifyCard: false,
                amount: 19.99,
                currency: "EUR",
                externalOrderId: "order-1",
                isRecurring: false
            ),
            savedCards: [],
            applePayAvailable: true,
            applePayReady: true
        )
    }

    private static func sampleIntent(_ suffix: String) -> PaymentIntent {
        PaymentIntent(
            orderPayload: OrderPayload("payload-\(suffix)"),
            orderChecksum: OrderChecksum("checksum-\(suffix)")
        )
    }
}

private extension UIView {
    func firstScrollView() -> UIScrollView? {
        if let scroll = self as? UIScrollView { return scroll }
        for subview in subviews {
            if let found = subview.firstScrollView() { return found }
        }
        return nil
    }

    func firstMultilineLabel() -> UILabel? {
        if let label = self as? UILabel, label.numberOfLines > 1 { return label }
        for subview in subviews {
            if let found = subview.firstMultilineLabel() { return found }
        }
        return nil
    }

    func firstTextField(withText text: String) -> UITextField? {
        if let field = self as? UITextField, field.text == text { return field }
        for subview in subviews {
            if let found = subview.firstTextField(withText: text) { return found }
        }
        return nil
    }

    func containsVisibleText(_ text: String) -> Bool {
        if let label = self as? UILabel, !label.isHidden, label.text == text { return true }
        for subview in subviews where !subview.isHidden {
            if subview.containsVisibleText(text) { return true }
        }
        return false
    }

    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        if let match = self as? T { return match }
        for subview in subviews {
            if let found = subview.firstSubview(of: type) { return found }
        }
        return nil
    }

    func setTextField(accessibilityLabel: String, text: String) {
        func walk(_ view: UIView) -> UITextField? {
            if let field = view as? UITextField, field.accessibilityLabel == accessibilityLabel { return field }
            for subview in view.subviews {
                if let found = walk(subview) { return found }
            }
            return nil
        }
        walk(self)?.text = text
    }

    func firstAccessibilityElement(where matches: (UIView) -> Bool) -> UIView? {
        if isAccessibilityElement, matches(self) { return self }
        for subview in subviews {
            if let found = subview.firstAccessibilityElement(where: matches) { return found }
        }
        return nil
    }

    func firstControl(accessibilityLabel: String) -> UIControl? {
        if let control = self as? UIControl, control.accessibilityLabel == accessibilityLabel { return control }
        for subview in subviews {
            if let found = subview.firstControl(accessibilityLabel: accessibilityLabel) { return found }
        }
        return nil
    }

    func firstButton(accessibilityLabel: String) -> UIButton? {
        if let button = self as? UIButton, button.accessibilityLabel == accessibilityLabel { return button }
        for subview in subviews {
            if let found = subview.firstButton(accessibilityLabel: accessibilityLabel) { return found }
        }
        return nil
    }

    func firstTextField() -> UITextField? {
        if let field = self as? UITextField { return field }
        for subview in subviews {
            if let found = subview.firstTextField() { return found }
        }
        return nil
    }
}
