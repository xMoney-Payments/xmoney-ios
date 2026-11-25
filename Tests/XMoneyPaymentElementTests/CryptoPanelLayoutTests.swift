import UIKit
import XCTest
@testable import XMoneyCore
@testable import XMoneyPaymentElement

/// Asserts the crypto and card panels against the Figma frames:
/// card form sits 16pt under its row, the crypto notice sits 8pt below the tint,
/// and the card chip shadow is light-mode only.
@MainActor
final class CryptoPanelLayoutTests: XCTestCase {
    func testCardSelectedMatchesFrame06() {
        let form = makeForm(savedCards: [], style: .light)
        layout(form)
        let gap = verticalGap(from: control(in: form, prefix: "Pay with card"), to: label(in: form, text: "Card details"))
        XCTAssertEqual(gap, 16, accuracy: 1)
        XCTAssertEqual(fieldInset(in: form, placeholder: "Cardholder name"), 12, accuracy: 0.5)
        let cardTile = brandTile(in: control(in: form, prefix: "Pay with card"))
        XCTAssertEqual(cardTile.layer.shadowOpacity, 0.04, accuracy: 0.001)
        XCTAssertEqual(cardTile.layer.shadowOffset, CGSize(width: 0, height: 1))
        XCTAssertEqual(cardTile.layer.shadowRadius, 1)
        XCTAssertFalse(cardTile.clipsToBounds)
        let cryptoTile = brandTile(in: control(in: form, prefix: "Pay with crypto"))
        XCTAssertEqual(cryptoTile.layer.shadowOpacity, 0)
    }

    func testCryptoSelectedNoticeSitsBelowTint() {
        let form = makeForm(savedCards: [], style: .light)
        layout(form)
        control(in: form, prefix: "Pay with crypto").sendActions(for: .touchUpInside)
        resize(form)

        let notice = label(in: form, containing: "redirected").superview!
        let stack = notice.superview as? UIStackView
        XCTAssertEqual(stack?.spacing, 8)
        XCTAssertEqual(stack?.arrangedSubviews.count, 2)
        let block = stack!.arrangedSubviews[0]
        XCTAssertFalse(notice.isDescendant(of: block))
        XCTAssertEqual(notice.frame.minY - block.frame.maxY, 8, accuracy: 0.5)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        block.backgroundColor?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        XCTAssertEqual(red, 0xF7 / 255, accuracy: 0.01)
        XCTAssertEqual(green, 0xF6 / 255, accuracy: 0.01)
        XCTAssertEqual(blue, 0xFF / 255, accuracy: 0.01)
        XCTAssertNil(notice.backgroundColor)
        let pay = payButton(in: form)
        let title = pay.accessibilityLabel ?? pay.titleLabel.text ?? ""
        XCTAssertTrue(title.contains("Continue"), title)
        let cardRow = control(in: form, prefix: "Pay with card")
        XCTAssertFalse(cardRow.accessibilityTraits.contains(.selected))
    }

    func testSavedCardsCryptoIdleMatchesFrame01() {
        let form = makeForm(savedCards: sampleCards(), style: .light)
        layout(form)
        XCTAssertNotNil(label(in: form, text: "Saved cards"))
        XCTAssertNil(optionalLabel(in: form, text: "Card details"))
        XCTAssertFalse(control(in: form, prefix: "Pay with crypto").accessibilityTraits.contains(.selected))
    }

    func testSavedCardsCryptoSelectedCollapsesToPayWithCard() {
        let cards = sampleCards()
        let form = makeForm(savedCards: cards, style: .light)
        layout(form)
        control(in: form, prefix: "Pay with crypto").sendActions(for: .touchUpInside)
        resize(form)
        assertCollapsedToPayWithCard(form, cards: cards)

        control(in: form, prefix: "Pay with card").sendActions(for: .touchUpInside)
        resize(form)
        XCTAssertTrue(isVisible(label(in: form, text: "Saved cards"), in: form))
        XCTAssertNil(optionalControl(in: form, prefix: "Pay with card"))
        XCTAssertTrue(isRadioSelected(in: control(in: form, prefix: displayName(cards[0]))))
        XCTAssertFalse(isRadioSelected(in: control(in: form, prefix: displayName(cards[1]))))
        XCTAssertFalse(control(in: form, prefix: "Pay with crypto").accessibilityTraits.contains(.selected))
    }

    func testCryptoFromUseAnotherCardCollapsesToPayWithCard() {
        let cards = sampleCards()
        let form = makeForm(savedCards: cards, style: .light)
        layout(form)
        guard let useAnother = ancestorControl(of: label(in: form, text: "Use another card")) else {
            return XCTFail("missing Use another card control")
        }
        useAnother.sendActions(for: .touchUpInside)
        resize(form)
        XCTAssertNotNil(optionalLabel(in: form, text: "Card details"))

        control(in: form, prefix: "Pay with crypto").sendActions(for: .touchUpInside)
        resize(form)
        assertCollapsedToPayWithCard(form, cards: cards)
    }

    func testDarkModeDropsCardChipShadowAndKeepsNoticeOutsideTint() {
        let form = makeForm(savedCards: [], style: .dark)
        layout(form)
        control(in: form, prefix: "Pay with crypto").sendActions(for: .touchUpInside)
        resize(form)
        XCTAssertEqual(brandTile(in: control(in: form, prefix: "Pay with card")).layer.shadowOpacity, 0)
        let notice = label(in: form, containing: "redirected").superview!
        let block = (notice.superview as! UIStackView).arrangedSubviews[0]
        XCTAssertFalse(notice.isDescendant(of: block))
    }

    private func makeForm(savedCards: [SavedCard], style: PaymentConfig.ColorSchemePreference) -> PaymentFormView {
        let state = SheetState(
            sessionToken: "tok",
            orderInfo: OrderPayloadInfo(
                cardTransactionMode: nil,
                isVerifyCard: false,
                amount: 240,
                currency: "EUR",
                externalOrderId: "order-1",
                isRecurring: false
            ),
            savedCards: savedCards,
            applePayAvailable: false
        )
        return PaymentFormView(
            config: PaymentConfig(
                publicKey: "pk_test",
                card: .init(savedCards: .init(enabled: true, optInVisible: true)),
                paymentMethods: .init(crypto: .init(enabled: true)),
                options: .init(locale: "en", appearance: .init(colorScheme: style))
            ),
            state: state,
            contentInsets: .sheet
        )
    }

    private func sampleCards() -> [SavedCard] {
        [
            SavedCard(id: "1", cardNumber: "5454545454541548", cardType: "mastercard", cardExpiryDate: "12/26", bankName: "Revolut"),
            SavedCard(id: "2", cardNumber: "4111111111113827", cardType: "visa", cardExpiryDate: "08/29", bankName: "BCR"),
            SavedCard(id: "3", cardNumber: "5454545454545599", cardType: "mastercard", cardExpiryDate: "12/34", bankName: "Revolut"),
        ]
    }

    private func layout(_ form: PaymentFormView) {
        resize(form)
    }

    private func resize(_ form: PaymentFormView) {
        let width: CGFloat = 390
        let height = form.preferredHeight(forWidth: width)
        form.frame = CGRect(x: 0, y: 0, width: width, height: height)
        form.layoutIfNeeded()
    }

    private func assertCollapsedToPayWithCard(_ form: PaymentFormView, cards: [SavedCard], file: StaticString = #filePath, line: UInt = #line) {
        if let header = optionalLabel(in: form, text: "Saved cards") {
            XCTAssertFalse(isVisible(header, in: form), "Saved cards header still visible", file: file, line: line)
        }
        if let edit = optionalLabel(in: form, text: "Edit") {
            XCTAssertFalse(isVisible(edit, in: form), "Edit still visible", file: file, line: line)
        }
        for card in cards {
            XCTAssertNil(optionalControl(in: form, prefix: displayName(card)), "saved row \(card.id) still shown", file: file, line: line)
        }
        XCTAssertNil(optionalLabel(in: form, text: "Card details"), file: file, line: line)
        let payWithCard = control(in: form, prefix: "Pay with card")
        XCTAssertTrue(isVisible(payWithCard, in: form), file: file, line: line)
        XCTAssertFalse(payWithCard.accessibilityTraits.contains(.selected), file: file, line: line)
        XCTAssertFalse(isRadioSelected(in: payWithCard), file: file, line: line)
        XCTAssertGreaterThan(payWithCard.bounds.height, 0, file: file, line: line)
        XCTAssertTrue(control(in: form, prefix: "Pay with crypto").accessibilityTraits.contains(.selected), file: file, line: line)
    }

    private func displayName(_ card: SavedCard) -> String {
        SavedCardFormatting.savedCardDisplayName(card)
    }

    private func isVisible(_ view: UIView, in root: UIView) -> Bool {
        var current: UIView? = view
        while let node = current, node !== root {
            if node.isHidden || node.alpha < 0.01 { return false }
            current = node.superview
        }
        return current === root
    }

    private func isRadioSelected(in root: UIView) -> Bool {
        guard let radio = radios(in: root).first else {
            XCTFail("missing radio")
            return false
        }
        let primary = CheckoutTheme.resolve(config: PaymentConfig(publicKey: "pk"), isDark: false).primary
        return radio.selectionDotIsVisible && radio.selectionDotColor == primary
    }

    private func radios(in view: UIView) -> [RadioIndicator] {
        var found: [RadioIndicator] = []
        if let radio = view as? RadioIndicator { found.append(radio) }
        view.subviews.forEach { found.append(contentsOf: radios(in: $0)) }
        return found
    }

    private func ancestorControl(of view: UIView) -> UIControl? {
        var current = view.superview
        while let node = current {
            if let control = node as? UIControl { return control }
            current = node.superview
        }
        return nil
    }

    private func control(in root: UIView, prefix: String) -> UIControl {
        guard let match = optionalControl(in: root, prefix: prefix) else {
            XCTFail("missing control \(prefix)")
            return UIControl()
        }
        return match
    }

    private func optionalControl(in root: UIView, prefix: String) -> UIControl? {
        controls(in: root).first { ($0.accessibilityLabel ?? "").hasPrefix(prefix) }
    }

    private func controls(in view: UIView) -> [UIControl] {
        var found: [UIControl] = []
        if let control = view as? UIControl { found.append(control) }
        view.subviews.forEach { found.append(contentsOf: controls(in: $0)) }
        return found
    }

    private func fieldInset(in root: UIView, placeholder: String) -> CGFloat {
        guard let field = textFields(in: root).first(where: {
            $0.placeholder == placeholder || $0.attributedPlaceholder?.string == placeholder
        }) else {
            XCTFail("missing field \(placeholder)")
            return -1
        }
        let leading = field.superview?.constraints.first {
            $0.firstAttribute == .leading && ($0.firstItem as? UIView) === field
        }
        return leading?.constant ?? -1
    }

    private func textFields(in view: UIView) -> [UITextField] {
        var found: [UITextField] = []
        if let field = view as? UITextField { found.append(field) }
        view.subviews.forEach { found.append(contentsOf: textFields(in: $0)) }
        return found
    }

    private func label(in root: UIView, text: String) -> UILabel {
        guard let match = optionalLabel(in: root, text: text) else {
            XCTFail("missing label \(text)")
            return UILabel()
        }
        return match
    }

    private func label(in root: UIView, containing text: String) -> UILabel {
        guard let match = labels(in: root).first(where: { $0.text?.contains(text) == true || ($0.attributedText?.string.contains(text) == true) }) else {
            XCTFail("missing label containing \(text)")
            return UILabel()
        }
        return match
    }

    private func optionalLabel(in root: UIView, text: String) -> UILabel? {
        labels(in: root).first { $0.text == text || $0.attributedText?.string == text }
    }

    private func labels(in view: UIView) -> [UILabel] {
        var found: [UILabel] = []
        if let label = view as? UILabel { found.append(label) }
        view.subviews.forEach { found.append(contentsOf: labels(in: $0)) }
        return found
    }

    private func brandTile(in root: UIView) -> BrandTileView {
        guard let tile = tiles(in: root).first else {
            XCTFail("missing brand tile")
            return BrandTileView(theme: CheckoutTheme.resolve(config: PaymentConfig(publicKey: "pk"), isDark: false))
        }
        return tile
    }

    private func tiles(in view: UIView) -> [BrandTileView] {
        var found: [BrandTileView] = []
        if let tile = view as? BrandTileView { found.append(tile) }
        view.subviews.forEach { found.append(contentsOf: tiles(in: $0)) }
        return found
    }

    private func payButton(in root: UIView) -> PayCTAButton {
        if let pay = root as? PayCTAButton { return pay }
        for child in root.subviews {
            if let found = optionalPay(in: child) { return found }
        }
        XCTFail("missing pay button")
        return PayCTAButton(frame: .zero)
    }

    private func optionalPay(in view: UIView) -> PayCTAButton? {
        if let pay = view as? PayCTAButton { return pay }
        for child in view.subviews {
            if let found = optionalPay(in: child) { return found }
        }
        return nil
    }

    private func verticalGap(from top: UIView, to bottom: UIView) -> CGFloat {
        let topFrame = top.convert(top.bounds, to: top.window ?? top)
        let bottomFrame = bottom.convert(bottom.bounds, to: top.window ?? top)
        return bottomFrame.minY - topFrame.maxY
    }
}
