import XCTest
@testable import XMoneyCore

final class StringsCatalogTests: XCTestCase {
    private let languages = ["en", "el", "ro", "bg", "hu", "pl"]

    func testLanguagePrefixAndRegionTagResolveTheSameCatalog() {
        XCTAssertEqual(
            Strings.text("sheet.title", locale: "pl"),
            Strings.text("sheet.title", locale: "pl-PL")
        )
        XCTAssertEqual(
            Strings.text("sheet.title", locale: "bg"),
            Strings.text("sheet.title", locale: "bg-BG")
        )
        XCTAssertEqual(
            Strings.text("button.pay", locale: "hu", args: ["amount": "€1.00"]),
            Strings.text("button.pay", locale: "hu-HU", args: ["amount": "€1.00"])
        )
    }

    func testUnknownLanguageFallsBackToEnglish() {
        XCTAssertEqual(Strings.text("sheet.title", locale: "xx-XX"), "Payment")
        XCTAssertEqual(Strings.text("sheet.title", locale: "not-a-locale"), "Payment")
    }

    func testUseOtherCardMatchesAndroid() {
        XCTAssertEqual(Strings.text("sheet.useOtherCard", locale: "en"), "Use other card")
        XCTAssertEqual(Strings.text("sheet.useAnotherCard", locale: "en"), "Use another card")
    }

    func testEveryLanguageHasTheSameKeysAsEnglish() {
        let english = Strings.catalogKeys(for: "en")
        XCTAssertFalse(english.isEmpty)
        for language in languages where language != "en" {
            XCTAssertEqual(
                Strings.catalogKeys(for: language),
                english,
                "catalog \(language) is missing or has extra keys vs en"
            )
        }
    }
}
