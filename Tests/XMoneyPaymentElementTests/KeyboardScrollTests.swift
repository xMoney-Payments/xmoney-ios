import XCTest
@testable import XMoneyPaymentElement

final class KeyboardScrollTests: XCTestCase {
    func testOffsetMovesAFieldThatSitsUnderTheKeyboard() {
        let target = KeyboardScroll.targetOffset(
            fieldRect: CGRect(x: 16, y: 700, width: 300, height: 44),
            bounds: CGRect(x: 0, y: 0, width: 390, height: 800),
            contentSize: CGSize(width: 390, height: 1600),
            contentOffset: .zero,
            keyboardFrame: CGRect(x: 0, y: 500, width: 390, height: 300)
        )
        XCTAssertEqual(target, CGPoint(x: 0, y: 268))
    }

    func testOffsetLeavesAnAlreadyVisibleFieldAlone() {
        let target = KeyboardScroll.targetOffset(
            fieldRect: CGRect(x: 16, y: 100, width: 300, height: 44),
            bounds: CGRect(x: 0, y: 0, width: 390, height: 800),
            contentSize: CGSize(width: 390, height: 1600),
            contentOffset: .zero,
            keyboardFrame: CGRect(x: 0, y: 700, width: 390, height: 300)
        )
        XCTAssertNil(target)
    }

    func testOffsetClampsToTheContent() {
        let target = KeyboardScroll.targetOffset(
            fieldRect: CGRect(x: 16, y: 700, width: 300, height: 44),
            bounds: CGRect(x: 0, y: 0, width: 390, height: 800),
            contentSize: CGSize(width: 390, height: 800),
            contentOffset: .zero,
            keyboardFrame: CGRect(x: 0, y: 500, width: 390, height: 300)
        )
        XCTAssertNil(target)
    }

    func testOffsetRevealsARowBelowTheVisibleBottom() {
        let target = KeyboardScroll.targetOffset(
            fieldRect: CGRect(x: 16, y: 900, width: 300, height: 64),
            bounds: CGRect(x: 0, y: 0, width: 390, height: 700),
            contentSize: CGSize(width: 390, height: 1600),
            contentOffset: .zero,
            keyboardFrame: CGRect(x: 0, y: 700, width: 390, height: 0),
            padding: 16
        )
        XCTAssertEqual(target, CGPoint(x: 0, y: 280))
    }

    func testOffsetRevealsAFieldAboveTheVisibleTop() {
        let target = KeyboardScroll.targetOffset(
            fieldRect: CGRect(x: 16, y: 180, width: 300, height: 44),
            bounds: CGRect(x: 0, y: 200, width: 390, height: 400),
            contentSize: CGSize(width: 390, height: 2000),
            contentOffset: CGPoint(x: 0, y: 200),
            keyboardFrame: CGRect(x: 0, y: 600, width: 390, height: 200)
        )
        XCTAssertEqual(target, CGPoint(x: 0, y: 156))
    }
}
