import UIKit
import XCTest
@testable import XMoneyCore
@testable import XMoneyPaymentElement

/// Country picker against Figma 4055:13904, the personal details chevron, and the Embedded footer gap.
@MainActor
final class PickerAndChromeLayoutTests: XCTestCase {
    func testPickerMatchesFigma() throws {
        let theme = CheckoutTheme.resolve(config: PaymentConfig(publicKey: "pk"), isDark: false)
        let list = SelectionListViewController(
            title: "Country",
            options: ["Portugal", "Austria", "Belgium"].map { SelectionListOption(id: $0, title: $0) },
            selectedID: "Portugal",
            theme: theme,
            locale: "en"
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = list
        window.makeKeyAndVisible()
        list.view.layoutIfNeeded()

        let close = try XCTUnwrap(find(CircleCloseButton.self, in: list.view).first)
        let closeFrame = close.convert(close.bounds, to: list.view)
        XCTAssertEqual(closeFrame.minX, 6, accuracy: 0.5)
        XCTAssertEqual(closeFrame.width, 44)

        let title = try XCTUnwrap(find(UILabel.self, in: list.view).first { $0.attributedText?.string == "Country" })
        let titleFont = title.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(titleFont?.pointSize ?? 0, 21 * theme.fontScale, accuracy: 0.01)
        let titleFrame = title.convert(title.bounds, to: list.view)
        XCTAssertEqual(titleFrame.midY, closeFrame.midY, accuracy: 0.5)
        XCTAssertEqual(titleFrame.minX, closeFrame.maxX + 12, accuracy: 0.5)

        let field = try XCTUnwrap(find(UITextField.self, in: list.view).first)
        let box = try XCTUnwrap(field.superview)
        let boxFrame = box.convert(box.bounds, to: list.view)
        XCTAssertEqual(boxFrame.minX, 16, accuracy: 0.5)
        XCTAssertEqual(boxFrame.maxX, 390 - 16, accuracy: 0.5)
        XCTAssertEqual(boxFrame.minY, closeFrame.maxY + 16, accuracy: 0.5)
        XCTAssertEqual(box.bounds.height, 48, accuracy: 0.5)
        XCTAssertEqual(box.layer.cornerRadius, 16)
        XCTAssertEqual(box.layer.borderWidth, 1)

        let table = try XCTUnwrap(find(UITableView.self, in: list.view).first)
        XCTAssertEqual(table.separatorStyle, .none)
        table.layoutIfNeeded()
        let first = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)))
        let second = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 1, section: 0)))
        XCTAssertTrue(first.accessibilityTraits.contains(.selected))
        XCTAssertFalse(second.accessibilityTraits.contains(.selected))
        XCTAssertEqual(first.accessoryType, .none)
        let firstRow = try XCTUnwrap(first.contentView.subviews.first)
        let secondRow = try XCTUnwrap(second.contentView.subviews.first)
        XCTAssertEqual(firstRow.bounds.height, 48, accuracy: 0.5)
        XCTAssertEqual(firstRow.layer.cornerRadius, 12)
        XCTAssertEqual(firstRow.backgroundColor, theme.componentBackground)
        XCTAssertEqual(secondRow.backgroundColor, .clear)
        let gap = secondRow.convert(secondRow.bounds, to: table).minY - firstRow.convert(firstRow.bounds, to: table).maxY
        XCTAssertEqual(gap, 12, accuracy: 0.5)
        let radios = find(RadioIndicator.self, in: firstRow)
        let radio = try XCTUnwrap(radios.first)
        XCTAssertEqual(radio.backgroundColor, .clear)
        XCTAssertTrue(radio.selectionDotIsVisible)
        XCTAssertEqual(radio.selectionDotColor, theme.primary)
        XCTAssertEqual(radio.selectionDotSide, 14)

        var picked: String?
        list.onSelect = { picked = $0 }
        list.tableView(table, didSelectRowAt: IndexPath(row: 2, section: 0))
        XCTAssertEqual(picked, "Belgium")
    }

    func testPersonalDetailsChevronIsNotStretched() throws {
        let theme = CheckoutTheme.resolve(config: PaymentConfig(publicKey: "pk"), isDark: false)
        let row = PersonalDetailsEntryRow(theme: theme, locale: "en")
        row.frame = CGRect(x: 0, y: 0, width: 358, height: 80)
        row.layoutIfNeeded()
        let chevron = try XCTUnwrap(find(UIImageView.self, in: row).first { $0.transform != .identity })
        XCTAssertEqual(chevron.bounds.size, CGSize(width: 13, height: 8))
        XCTAssertEqual(chevron.contentMode, .scaleAspectFit)
        XCTAssertEqual(chevron.superview?.bounds.size, CGSize(width: 16, height: 16))
        XCTAssertEqual(chevron.frame.width, 8, accuracy: 0.5)
        XCTAssertEqual(chevron.frame.height, 13, accuracy: 0.5)
    }

    func testEmbeddedPayButtonSits12BelowContent() throws {
        let form = PaymentFormView(
            config: PaymentConfig(publicKey: "pk_test"),
            state: SheetState(
                sessionToken: "tok",
                orderInfo: OrderPayloadInfo(
                    cardTransactionMode: nil,
                    isVerifyCard: false,
                    amount: 240,
                    currency: "EUR",
                    externalOrderId: "order-1",
                    isRecurring: false
                ),
                savedCards: [],
                applePayAvailable: false
            ),
            contentInsets: .embedded
        )
        form.frame = CGRect(x: 0, y: 0, width: 390, height: form.preferredHeight(forWidth: 390))
        form.layoutIfNeeded()
        let pay = try XCTUnwrap(find(PayCTAButton.self, in: form).first)
        let footerInner = try XCTUnwrap(pay.superview)
        let footerWrap = try XCTUnwrap(footerInner.superview)
        XCTAssertEqual(footerInner.frame.minY, 12, accuracy: 0.5)
        let contentWrap = try XCTUnwrap((footerWrap.superview as? UIStackView)?.arrangedSubviews.first)
        XCTAssertEqual(footerWrap.frame.minY - contentWrap.frame.maxY, 0, accuracy: 0.5)
    }

    private func find<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        var found: [T] = []
        if let match = view as? T { found.append(match) }
        view.subviews.forEach { found.append(contentsOf: find(type, in: $0)) }
        return found
    }
}
