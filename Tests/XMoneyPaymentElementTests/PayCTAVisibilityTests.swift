import XCTest
@testable import XMoneyPaymentElement
@testable import XMoneyCore
import UIKit

final class PayCTAVisibilityTests: XCTestCase {
    @MainActor
    func testSheetPayCTAIsOpaqueWithTitle() {
        let form = PaymentFormView(
            config: PaymentConfig(publicKey: "pk_test"),
            state: Self.sampleState(),
            contentInsets: .sheet
        )
        form.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        form.layoutIfNeeded()

        guard let pay = Self.findPay(in: form) else {
            XCTFail("Sheet PaymentFormView must include xmoney.pay")
            return
        }
        XCTAssertFalse(pay.isHidden)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        pay.fillColor?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertGreaterThan(a, 0.5, "Pay fill must be opaque")
        XCTAssertFalse(pay.titleLabel.text?.isEmpty ?? true, "Pay must have a title")
    }

    @MainActor
    func testSheetIgnoresSubmitButtonVisibleFalse() {
        let config = PaymentConfig(
            publicKey: "pk_test",
            card: .init(submitButton: .init(visible: false))
        )
        let form = PaymentFormView(
            config: config,
            state: Self.sampleState(),
            contentInsets: .sheet
        )
        form.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        form.layoutIfNeeded()

        guard let pay = Self.findPay(in: form) else {
            XCTFail("Sheet must still include xmoney.pay when visible is false")
            return
        }
        XCTAssertFalse(pay.isHidden, "Sheet ignores submitButton.visible")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        pay.fillColor?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertGreaterThan(a, 0.5, "Pay fill must paint even when visible is false")
        XCTAssertFalse(pay.titleLabel.text?.isEmpty ?? true)
    }

    @MainActor
    func testHugePillRadiusStillRendersFillAndTitle() {
        let config = PaymentConfig(
            publicKey: "pk_test",
            options: .init(
                appearance: .init(
                    primaryButton: .init(
                        colorsLight: .init(background: "#7C4DFF", text: "#FFFFFF"),
                        borderRadius: 9999
                    )
                )
            )
        )
        let form = PaymentFormView(
            config: config,
            state: Self.sampleState(),
            contentInsets: .sheet
        )
        form.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        form.layoutIfNeeded()

        guard let pay = Self.findPay(in: form) else {
            XCTFail("missing xmoney.pay")
            return
        }
        XCTAssertFalse(pay.isHidden)
        XCTAssertFalse(pay.titleLabel.text?.isEmpty ?? true)
        XCTAssertGreaterThan(pay.bounds.width, 100)
        XCTAssertEqual(pay.bounds.height, 52, accuracy: 0.5)

        let renderer = UIGraphicsImageRenderer(bounds: pay.bounds)
        let image = renderer.image { ctx in
            pay.layer.render(in: ctx.cgContext)
        }
        let pixel = Self.centerPixel(of: image)
        XCTAssertGreaterThan(pixel.a, 0.5, "center pixel must be painted")
        XCTAssertGreaterThan(pixel.b, 0.5, "fill should be xMoney purple (blue channel)")
        XCTAssertLessThan(pixel.g, 0.5, "fill should not be white")
    }

    @MainActor
    func testEmbeddedHidesPayWhenSubmitButtonNotVisible() {
        let config = PaymentConfig(
            publicKey: "pk_test",
            card: .init(submitButton: .init(visible: false))
        )
        let form = PaymentFormView(
            config: config,
            state: Self.sampleState(),
            contentInsets: .embedded
        )
        form.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        form.layoutIfNeeded()

        guard let pay = Self.findPay(in: form) else {
            XCTFail("Embedded PaymentFormView still owns xmoney.pay when hidden")
            return
        }
        XCTAssertTrue(pay.isHidden)
    }

    @MainActor
    func testUpdatingOrderKeepsPayTitleAndDisablesButton() {
        let form = PaymentFormView(
            config: PaymentConfig(publicKey: "pk_test"),
            state: Self.sampleState(),
            contentInsets: .embedded
        )
        form.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        form.layoutIfNeeded()

        guard let pay = Self.findPay(in: form) else {
            XCTFail("missing xmoney.pay")
            return
        }
        let idleTitle = pay.accessibilityLabel ?? pay.titleLabel.text ?? ""
        XCTAssertTrue(idleTitle.contains("Pay"), "idle title should be Pay, got \(idleTitle)")
        XCTAssertFalse(idleTitle.contains("Processing"))
        XCTAssertTrue(pay.isEnabled)

        form.setUpdatingOrder(true)
        let updatingTitle = pay.accessibilityLabel ?? pay.titleLabel.text ?? ""
        XCTAssertEqual(updatingTitle, idleTitle, "updateOrder must keep the current Pay title")
        XCTAssertFalse(updatingTitle.contains("Processing"))
        XCTAssertFalse(pay.isEnabled)

        form.setUpdatingOrder(false)
        XCTAssertTrue(pay.isEnabled)
        XCTAssertEqual(pay.accessibilityLabel, idleTitle)
    }

    @MainActor
    func testProcessingShowsProcessingTitle() {
        let form = PaymentFormView(
            config: PaymentConfig(publicKey: "pk_test"),
            state: Self.sampleState(),
            contentInsets: .embedded
        )
        form.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        form.layoutIfNeeded()

        guard let pay = Self.findPay(in: form) else {
            XCTFail("missing xmoney.pay")
            return
        }
        form.setProcessing(true)
        XCTAssertEqual(pay.accessibilityLabel, "Processing...")
        XCTAssertFalse(pay.isEnabled)

        form.setProcessing(false)
        let title = pay.accessibilityLabel ?? pay.titleLabel.text ?? ""
        XCTAssertTrue(title.contains("Pay"), "after charge, title returns to Pay, got \(title)")
        XCTAssertFalse(title.contains("Processing"))
    }

    @MainActor
    func testUpdatingOrderThenNewStateRefreshesAmount() {
        let form = PaymentFormView(
            config: PaymentConfig(publicKey: "pk_test"),
            state: Self.sampleState(amount: 19.99),
            contentInsets: .embedded
        )
        form.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        form.layoutIfNeeded()

        guard let pay = Self.findPay(in: form) else {
            XCTFail("missing xmoney.pay")
            return
        }
        let original = pay.accessibilityLabel ?? pay.titleLabel.text ?? ""
        form.setUpdatingOrder(true)
        XCTAssertEqual(pay.accessibilityLabel, original)

        form.update(state: Self.sampleState(amount: 24.99))
        form.setUpdatingOrder(false)
        let next = pay.accessibilityLabel ?? pay.titleLabel.text ?? ""
        XCTAssertNotEqual(next, original)
        XCTAssertFalse(next.contains("Processing"))
        XCTAssertTrue(next.contains("Pay"))
        XCTAssertTrue(pay.isEnabled)
    }

    private static func sampleState(amount: Double = 19.99) -> SheetState {
        SheetState(
            sessionToken: "tok",
            orderInfo: OrderPayloadInfo(
                cardTransactionMode: nil,
                isVerifyCard: false,
                amount: amount,
                currency: "EUR",
                externalOrderId: "order-1",
                isRecurring: false
            ),
            savedCards: [],
            applePayAvailable: false
        )
    }

    private static func centerPixel(of image: UIImage) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        guard let cg = image.cgImage else { return (0, 0, 0, 0) }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return (0, 0, 0, 0) }
        ctx.translateBy(x: -CGFloat(cg.width / 2), y: -CGFloat(cg.height / 2))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        return (
            CGFloat(pixel[0]) / 255,
            CGFloat(pixel[1]) / 255,
            CGFloat(pixel[2]) / 255,
            CGFloat(pixel[3]) / 255
        )
    }

    private static func findPay(in root: UIView) -> PayCTAButton? {
        if let pay = root as? PayCTAButton { return pay }
        for child in root.subviews {
            if let found = findPay(in: child) { return found }
        }
        return nil
    }
}
