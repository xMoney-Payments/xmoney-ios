import XCTest
@testable import XMoneyCore

final class CardValidationDisplayTests: XCTestCase {
    private struct Case {
        let mode: PaymentConfig.ValidationMode
        let fieldBlurred: Bool
        let submitAttempted: Bool
        let show: Bool
        let refreshOnChange: Bool
    }

    func testDisplayAndRefreshTruthTable() {
        let cases: [Case] = [
            // onChange: always show, always live
            Case(mode: .onChange, fieldBlurred: false, submitAttempted: false, show: true, refreshOnChange: true),
            Case(mode: .onChange, fieldBlurred: true, submitAttempted: false, show: true, refreshOnChange: true),
            Case(mode: .onChange, fieldBlurred: false, submitAttempted: true, show: true, refreshOnChange: true),
            Case(mode: .onChange, fieldBlurred: true, submitAttempted: true, show: true, refreshOnChange: true),

            // onSubmit: hidden until Pay, then live
            Case(mode: .onSubmit, fieldBlurred: false, submitAttempted: false, show: false, refreshOnChange: false),
            Case(mode: .onSubmit, fieldBlurred: true, submitAttempted: false, show: false, refreshOnChange: false),
            Case(mode: .onSubmit, fieldBlurred: false, submitAttempted: true, show: true, refreshOnChange: true),
            Case(mode: .onSubmit, fieldBlurred: true, submitAttempted: true, show: true, refreshOnChange: true),

            // onBlur: show after this field blurs; frozen until next blur (or Pay)
            Case(mode: .onBlur, fieldBlurred: false, submitAttempted: false, show: false, refreshOnChange: false),
            Case(mode: .onBlur, fieldBlurred: true, submitAttempted: false, show: true, refreshOnChange: false),
            Case(mode: .onBlur, fieldBlurred: false, submitAttempted: true, show: true, refreshOnChange: true),
            Case(mode: .onBlur, fieldBlurred: true, submitAttempted: true, show: true, refreshOnChange: true),

            // onTouched: show after this field blurs, then live
            Case(mode: .onTouched, fieldBlurred: false, submitAttempted: false, show: false, refreshOnChange: false),
            Case(mode: .onTouched, fieldBlurred: true, submitAttempted: false, show: true, refreshOnChange: true),
            Case(mode: .onTouched, fieldBlurred: false, submitAttempted: true, show: true, refreshOnChange: true),
            Case(mode: .onTouched, fieldBlurred: true, submitAttempted: true, show: true, refreshOnChange: true),
        ]

        for item in cases {
            let show = CardValidationDisplay.shouldShowError(
                mode: item.mode,
                fieldBlurred: item.fieldBlurred,
                submitAttempted: item.submitAttempted
            )
            let refresh = CardValidationDisplay.shouldRefreshDisplayedErrorOnChange(
                mode: item.mode,
                fieldBlurred: item.fieldBlurred,
                submitAttempted: item.submitAttempted
            )
            XCTAssertEqual(
                show,
                item.show,
                "shouldShowError \(item.mode.rawValue) blurred=\(item.fieldBlurred) submit=\(item.submitAttempted)"
            )
            XCTAssertEqual(
                refresh,
                item.refreshOnChange,
                "shouldRefreshDisplayedErrorOnChange \(item.mode.rawValue) blurred=\(item.fieldBlurred) submit=\(item.submitAttempted)"
            )
        }
    }

    func testCardConfigDefaultIsOnTouched() {
        XCTAssertEqual(PaymentConfig.CardConfig().validationMode, .onTouched)
    }
}
