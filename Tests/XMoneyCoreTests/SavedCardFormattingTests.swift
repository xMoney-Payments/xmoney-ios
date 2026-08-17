import XCTest
@testable import XMoneyCore

final class SavedCardFormattingTests: XCTestCase {
    func testSavedCardsSummarySubtitleJoinsDistinctIssuers() {
        let cards = [
            SavedCard(id: "1", cardNumber: "•••• 1111", cardType: "visa", cardExpiryDate: "12/26", issuerName: "ING", cardBrand: "visa"),
            SavedCard(id: "2", cardNumber: "•••• 5599", cardType: "mastercard", cardExpiryDate: "12/34", issuerName: "Revolut", cardBrand: "mastercard"),
            SavedCard(id: "3", cardNumber: "•••• 7043", cardType: "visa", cardExpiryDate: "08/29", issuerName: "BCR", cardBrand: "visa"),
        ]
        XCTAssertEqual(SavedCardFormatting.savedCardsSummarySubtitle(cards), "ING, Revolut, BCR")
    }

    func testSavedCardDisplayNameFormatsIssuerAndMaskedNumber() {
        let card = SavedCard(id: "1", cardNumber: "411111******1111", cardType: "visa", cardExpiryDate: "12/26", issuerName: "ING", cardBrand: "visa")
        XCTAssertEqual(SavedCardFormatting.savedCardDisplayName(card), "ING •••• 1111")
    }

    func testSavedCardMetaIncludesBrandAndExpiry() {
        let card = SavedCard(id: "1", cardNumber: "•••• 1111", cardType: "visa", cardExpiryDate: "12/26", issuerName: "ING", cardBrand: "visa")
        XCTAssertEqual(SavedCardFormatting.savedCardMeta(card, locale: "en-US"), "Visa · 12/26")
    }

    func testSavedCardMetaIncludesDefaultLabel() {
        let card = SavedCard(
            id: "1",
            cardNumber: "•••• 1111",
            cardType: "visa",
            cardExpiryDate: "12/26",
            isDefault: true,
            issuerName: "ING",
            cardBrand: "visa"
        )
        XCTAssertEqual(SavedCardFormatting.savedCardMeta(card, locale: "en-US"), "Visa · 12/26 · Default")
    }

    func testSavedCardBrandForIconUsesNetworkBrandNotIssuer() {
        let card = SavedCard(id: "1", cardNumber: "•••• 1111", cardType: "visa", cardExpiryDate: "12/26", issuerName: "ING", cardBrand: "visa")
        XCTAssertEqual(SavedCardFormatting.savedCardBrandForIcon(card), "visa")
    }

    func testRemoveCardCopyKeys() {
        XCTAssertEqual(Strings.text("sheet.edit", locale: "en-US"), "Edit")
        XCTAssertEqual(Strings.text("sheet.done", locale: "en-US"), "Done")
        XCTAssertEqual(Strings.text("sheet.remove", locale: "en-US"), "Remove")
        XCTAssertEqual(Strings.text("sheet.keepIt", locale: "en-US"), "Keep it")
        XCTAssertEqual(
            Strings.text("sheet.removeCardConfirm", locale: "en-US"),
            "Are you sure you want to remove this card?"
        )
    }
}
