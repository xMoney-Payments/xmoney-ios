import XCTest
@testable import XMoneyCore

final class ThemeColorMathTests: XCTestCase {
    func testYellowOnCreamStopsNearTheContrastFloor() {
        let yellow = PaymentConfig.SRGBColor(hex: "#FACC15")!
        let cream = PaymentConfig.SRGBColor(hex: "#F7F6FF")!
        let adjusted = yellow.withContrast(atLeast: 4.5, against: cream)
        let ratio = adjusted.contrast(against: cream)
        XCTAssertGreaterThanOrEqual(ratio, 4.5)
        XCTAssertLessThan(ratio, 5.2)
    }

    func testUnreachableTargetFallsBackToInkOrPaper() {
        let gray = PaymentConfig.SRGBColor(hex: "#777777")!
        let adjusted = gray.withContrast(atLeast: 7, against: gray)
        let ink = PaymentConfig.SRGBColor.ink.contrast(against: gray)
        let paper = PaymentConfig.SRGBColor.paper.contrast(against: gray)
        let expected = ink >= paper ? PaymentConfig.SRGBColor.ink : PaymentConfig.SRGBColor.paper
        XCTAssertEqual(adjusted.red, expected.red, accuracy: 0.001)
        XCTAssertEqual(adjusted.green, expected.green, accuracy: 0.001)
        XCTAssertEqual(adjusted.blue, expected.blue, accuracy: 0.001)
    }

    func testTranslucentContrastUsesThePaintedColor() {
        let veil = PaymentConfig.SRGBColor.white.withAlpha(0.2)
        let painted = veil.contrast(against: .black, compositedOver: .black)
        let opaque = PaymentConfig.SRGBColor.white.contrast(against: .black)
        XCTAssertGreaterThan(painted, 1)
        XCTAssertLessThan(painted, opaque)
        XCTAssertEqual(painted, veil.composited(over: .black).contrast(against: .black), accuracy: 0.001)
    }
}
