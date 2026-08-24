import SwiftUI

enum ExampleColors {
    static let purple = Color(red: 0x7C / 255, green: 0x4D / 255, blue: 0xFF / 255)
    static let purpleHover = Color(red: 0x6D / 255, green: 0x3F / 255, blue: 0xFF / 255)
    static let purpleElectric = Color(red: 0x9F / 255, green: 0x55 / 255, blue: 0xFF / 255)

    static let lime = Color(red: 0xDC / 255, green: 0xFC / 255, blue: 0x97 / 255)
    static let limeDark = Color(red: 0x3C / 255, green: 0x57 / 255, blue: 0x08 / 255)

    static let lightBg = Color(red: 0xF4 / 255, green: 0xF3 / 255, blue: 0xFB / 255)
    static let lightCard = Color.white
    static let lightText = Color(red: 0x16 / 255, green: 0x14 / 255, blue: 0x1A / 255)
    static let lightMuted = Color(red: 0x16 / 255, green: 0x14 / 255, blue: 0x1A / 255).opacity(0.5)
    static let lightHairline = Color(red: 0x16 / 255, green: 0x14 / 255, blue: 0x1A / 255).opacity(0.06)

    static let darkBg = Color(red: 0x09 / 255, green: 0x09 / 255, blue: 0x0B / 255)
    static let darkCard = Color(red: 0x18 / 255, green: 0x18 / 255, blue: 0x1B / 255)
    static let darkElevated = Color(red: 0x1F / 255, green: 0x1F / 255, blue: 0x23 / 255)
    static let darkText = Color(red: 0xFA / 255, green: 0xFA / 255, blue: 0xFA / 255)
    static let darkMuted = Color(red: 0xA1 / 255, green: 0xA1 / 255, blue: 0xAA / 255)
    static let darkHairline = Color.white.opacity(0.12)

    static let error = Color(red: 1, green: 0x47 / 255, blue: 0x57 / 255)
    static let success = Color(red: 0x05 / 255, green: 0x96 / 255, blue: 0x69 / 255)
    static let successSoftLight = Color(red: 0xD1 / 255, green: 0xFA / 255, blue: 0xE5 / 255).opacity(0.6)
    static let successSoftDark = Color(red: 0x10 / 255, green: 0xB9 / 255, blue: 0x81 / 255).opacity(0.15)
    static let dangerSoftLight = Color(red: 0xFE / 255, green: 0xE2 / 255, blue: 0xE2 / 255).opacity(0.6)
    static let dangerSoftDark = Color(red: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255).opacity(0.15)
}

enum ExampleRadii {
    static let pill: CGFloat = 9999
    static let card: CGFloat = 24
    static let inner: CGFloat = 16
    static let small: CGFloat = 8
}
