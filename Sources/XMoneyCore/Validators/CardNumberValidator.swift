import Foundation

final class CardNumberValidator {
    private let reverseBinMap: [(range: ClosedRange<Int>, brand: String)] = [
        (622126...622925, "unionpay"),
        (624000...626999, "unionpay"),
        (628200...628899, "unionpay"),
        (2200...2204, "mir"),
        (2221...2720, "mastercard"),
        (3095...3095, "diners"),
        (3528...3589, "jcb"),
        (5019...5019, "dankort"),
        (6011...6011, "discover"),
        (300...305, "diners"),
        (644...649, "discover"),
        (34...34, "amex"),
        (36...36, "diners"),
        (37...37, "amex"),
        (38...39, "diners"),
        (50...50, "maestro"),
        (51...55, "mastercard"),
        (56...58, "maestro"),
        (65...65, "discover"),
        (4...4, "visa"),
        (6...6, "maestro"),
    ]

    private let cardLength: [String: [Int]] = [
        "amex": [15],
        "diners": [14],
        "discover": [16, 19],
        "jcb": [15, 16],
        "maestro": [12, 13, 14, 15, 16, 17, 18, 19],
        "mastercard": [16],
        "unionpay": [16, 17, 18, 19],
        "visa": [13, 16, 19],
        "dankort": [16],
        "mir": [16],
    ]

    init() {}

    func detect(_ pan: String) -> String? {
        for entry in reverseBinMap {
            let length = String(entry.range.lowerBound).count
            guard pan.count >= length,
                  let value = Int(pan.prefix(length)) else { continue }
            if entry.range.contains(value) {
                return entry.brand
            }
        }
        return nil
    }

    func validateLength(_ pan: String, brand: String? = nil) -> Bool {
        let resolved = brand ?? detect(pan)
        guard let resolved, let lengths = cardLength[resolved] else { return false }
        return lengths.contains(pan.count)
    }

    func maxLength(_ pan: String) -> Int {
        guard let brand = detect(pan), let lengths = cardLength[brand] else { return 19 }
        return lengths.max() ?? 19
    }

    func minLength(_ pan: String) -> Int {
        guard let brand = detect(pan), let lengths = cardLength[brand] else { return 0 }
        return lengths.min() ?? 0
    }

    func checkLuhn(_ pan: String) -> Bool {
        var sum = 0
        var shouldDouble = false
        for char in pan.reversed() {
            guard var digit = char.wholeNumberValue else { return false }
            if shouldDouble {
                digit *= 2
                if digit > 9 { digit -= 9 }
            }
            sum += digit
            shouldDouble.toggle()
        }
        return sum % 10 == 0
    }
}
