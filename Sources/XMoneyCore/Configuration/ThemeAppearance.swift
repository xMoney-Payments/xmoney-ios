import Foundation

extension PaymentConfig {
    /// Host color scheme. `.automatic` follows the system setting.
    public enum ColorSchemePreference: String, Equatable, Sendable {
        case automatic
        case light
        case dark

        public static func from(_ raw: String?) -> ColorSchemePreference {
            switch raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "light", "alwayslight": return .light
            case "dark", "alwaysdark": return .dark
            case "auto", "automatic": return .automatic
            default:
                if let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    AppearanceLog.warn("unknown colorScheme '\(raw)', using automatic")
                }
                return .automatic
            }
        }
    }

    /// sRGB color, channels 0...1.
    public struct SRGBColor: Equatable, Sendable {
        public var red: Double
        public var green: Double
        public var blue: Double
        public var alpha: Double

        public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        public static let white = SRGBColor(red: 1, green: 1, blue: 1)
        public static let black = SRGBColor(red: 0, green: 0, blue: 0)
        package static let ink = SRGBColor(red: 0x16 / 255, green: 0x14 / 255, blue: 0x1A / 255)
        package static let paper = SRGBColor(red: 0xFA / 255, green: 0xFA / 255, blue: 0xFA / 255)

        public var hex: String {
            func byte(_ channel: Double) -> Int {
                Int((min(max(channel, 0), 1) * 255).rounded())
            }
            return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
        }
    }

    /// One color, or a light/dark pair, stored as resolved sRGB.
    public struct ThemeColor: Equatable, Sendable {
        public var light: SRGBColor
        public var dark: SRGBColor

        public init(light: SRGBColor, dark: SRGBColor) {
            self.light = light
            self.dark = dark
        }

        public init(_ color: SRGBColor) {
            self.init(light: color, dark: color)
        }

        public init?(hex: String) {
            guard let color = SRGBColor(hex: hex) else { return nil }
            self.init(color)
        }

        public init?(light: String, dark: String) {
            guard let light = SRGBColor(hex: light), let dark = SRGBColor(hex: dark) else { return nil }
            self.init(light: light, dark: dark)
        }

        public func resolved(isDark: Bool) -> SRGBColor {
            isDark ? dark : light
        }

        static func from(_ value: Any?) -> ThemeColor? {
            if let hex = value as? String {
                if let color = ThemeColor(hex: hex) { return color }
                AppearanceLog.warn("invalid color '\(hex)'")
                return nil
            }
            guard let dict = value as? [String: Any] ?? (value as? NSDictionary).map({ dict in
                var result: [String: Any] = [:]
                dict.enumerateKeysAndObjects { key, object, _ in
                    if let key = key as? String { result[key] = object }
                }
                return result
            }) else { return nil }
            let light = dict["light"] as? String
            let dark = dict["dark"] as? String
            if let light, let dark, let color = ThemeColor(light: light, dark: dark) { return color }
            if light != nil || dark != nil {
                AppearanceLog.warn("invalid light/dark color pair")
            }
            return nil
        }
    }

    public enum Corners: Equatable, Sendable {
        case sharp
        case `default`
        case rounded
        case custom(Double)

        /// Scale position 0...24 used to interpolate the radius tokens.
        public var scale: Double {
            switch self {
            case .sharp: return 0
            case .default: return 16
            case .rounded: return 24
            case .custom(let value): return min(max(value, 0), 24)
            }
        }

        public static func from(_ value: Any?) -> Corners {
            if let name = value as? String {
                switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "sharp": return .sharp
                case "default": return .default
                case "rounded": return .rounded
                default:
                    AppearanceLog.warn("unknown corners '\(name)', using default")
                    return .default
                }
            }
            if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
                let raw = number.doubleValue
                if raw < 0 || raw > 24 {
                    AppearanceLog.warn("corners \(raw) is outside 0...24 and was clamped")
                }
                return .custom(min(max(raw, 0), 24))
            }
            if value != nil { AppearanceLog.warn("corners must be sharp, default, rounded, or a number") }
            return .default
        }
    }

    /// Exact semantic colors. Each one replaces only the role it names.
    public struct AppearanceOverrides: Equatable, Sendable {
        public var onBrandColor: ThemeColor?
        public var textColor: ThemeColor?
        public var linkColor: ThemeColor?
        public var borderColor: ThemeColor?
        public var componentColor: ThemeColor?
        public var selectedColor: ThemeColor?
        public var secondaryButtonColor: ThemeColor?

        public init(
            onBrandColor: ThemeColor? = nil,
            textColor: ThemeColor? = nil,
            linkColor: ThemeColor? = nil,
            borderColor: ThemeColor? = nil,
            componentColor: ThemeColor? = nil,
            selectedColor: ThemeColor? = nil,
            secondaryButtonColor: ThemeColor? = nil
        ) {
            self.onBrandColor = onBrandColor
            self.textColor = textColor
            self.linkColor = linkColor
            self.borderColor = borderColor
            self.componentColor = componentColor
            self.selectedColor = selectedColor
            self.secondaryButtonColor = secondaryButtonColor
        }

        package static let dictionaryKeys: Set<String> = [
            "onBrandColor", "textColor", "linkColor", "borderColor",
            "componentColor", "selectedColor", "secondaryButtonColor",
        ]

        static func from(_ value: Any?) -> AppearanceOverrides {
            guard let dict = appearanceDictionary(value) else { return .init() }
            warnUnknown(dict, known: dictionaryKeys, group: "overrides")
            return AppearanceOverrides(
                onBrandColor: ThemeColor.from(dict["onBrandColor"]),
                textColor: ThemeColor.from(dict["textColor"]),
                linkColor: ThemeColor.from(dict["linkColor"]),
                borderColor: ThemeColor.from(dict["borderColor"]),
                componentColor: ThemeColor.from(dict["componentColor"]),
                selectedColor: ThemeColor.from(dict["selectedColor"]),
                secondaryButtonColor: ThemeColor.from(dict["secondaryButtonColor"])
            )
        }
    }

    /// Type family. Later weights and a heading face are fields here.
    public struct Typography: Equatable, Sendable {
        public var fontFamily: String?

        public init(fontFamily: String? = nil) {
            self.fontFamily = fontFamily
        }

        package static let dictionaryKeys: Set<String> = ["fontFamily"]

        static func from(_ value: Any?) -> Typography {
            guard let dict = appearanceDictionary(value) else { return .init() }
            warnUnknown(dict, known: dictionaryKeys, group: "typography")
            return Typography(fontFamily: (dict["fontFamily"] as? String)?.nilIfEmpty)
        }
    }

    /// Strokes. `width` is the idle field stroke, in points, clamped to 0...4.
    public struct Borders: Equatable, Sendable {
        public var width: Double

        public init(width: Double = 1) {
            self.width = Self.clamped(width, warn: false)
        }

        package static let dictionaryKeys: Set<String> = ["width"]

        static func from(_ value: Any?) -> Borders {
            guard let dict = appearanceDictionary(value) else { return .init() }
            warnUnknown(dict, known: dictionaryKeys, group: "borders")
            return Borders(width: width(from: dict["width"]))
        }

        /// Numbers only. Booleans are rejected. Missing or invalid values stay at 1.
        static func width(from value: Any?) -> Double {
            guard let value else { return 1 }
            if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
                return clamped(number.doubleValue, warn: true)
            }
            AppearanceLog.warn("borders.width must be a number")
            return 1
        }

        private static func clamped(_ raw: Double, warn: Bool) -> Double {
            if warn, raw < 0 || raw > 4 {
                AppearanceLog.warn("borders.width \(raw) is outside 0...4 and was clamped")
            }
            return min(max(raw, 0), 4)
        }
    }

    /// Control geometry. The sheet corner is not part of this group.
    public struct Shape: Equatable, Sendable {
        public var corners: Corners
        public var pillButtons: Bool

        public init(corners: Corners = .default, pillButtons: Bool = true) {
            self.corners = corners
            self.pillButtons = pillButtons
        }

        package static let dictionaryKeys: Set<String> = ["corners", "pillButtons"]

        static func from(_ value: Any?) -> Shape {
            guard let dict = appearanceDictionary(value) else { return .init() }
            warnUnknown(dict, known: dictionaryKeys, group: "shape")
            return Shape(
                corners: Corners.from(dict["corners"]),
                pillButtons: dict["pillButtons"] as? Bool ?? true
            )
        }
    }

    /// Merchant theme. An empty value is the built-in xMoney light and dark themes.
    public struct Appearance: Equatable, Sendable {
        public var colorScheme: ColorSchemePreference
        public var brandColor: ThemeColor?
        public var accentColor: ThemeColor?
        public var backgroundColor: ThemeColor?
        public var neutralTint: ThemeColor?
        public var overrides: AppearanceOverrides
        public var typography: Typography
        public var borders: Borders
        public var shape: Shape

        public init(
            colorScheme: ColorSchemePreference = .automatic,
            brandColor: ThemeColor? = nil,
            accentColor: ThemeColor? = nil,
            backgroundColor: ThemeColor? = nil,
            neutralTint: ThemeColor? = nil,
            overrides: AppearanceOverrides = .init(),
            typography: Typography = .init(),
            borders: Borders = .init(),
            shape: Shape = .init()
        ) {
            self.colorScheme = colorScheme
            self.brandColor = brandColor
            self.accentColor = accentColor
            self.backgroundColor = backgroundColor
            self.neutralTint = neutralTint
            self.overrides = overrides
            self.typography = typography
            self.borders = borders
            self.shape = shape
        }

        package static let dictionaryKeys: Set<String> = [
            "colorScheme", "brandColor", "accentColor", "backgroundColor", "neutralTint",
            "overrides", "typography", "borders", "shape",
        ]

        public static func from(_ dict: [String: Any]?) -> Appearance {
            guard let dict else { return Appearance() }
            warnUnknown(dict, known: dictionaryKeys, group: "appearance")
            return Appearance(
                colorScheme: ColorSchemePreference.from(dict["colorScheme"] as? String),
                brandColor: ThemeColor.from(dict["brandColor"]),
                accentColor: ThemeColor.from(dict["accentColor"]),
                backgroundColor: ThemeColor.from(dict["backgroundColor"]),
                neutralTint: ThemeColor.from(dict["neutralTint"]),
                overrides: AppearanceOverrides.from(dict["overrides"]),
                typography: Typography.from(dict["typography"]),
                borders: Borders.from(dict["borders"]),
                shape: Shape.from(dict["shape"])
            )
        }
    }
}

package enum AppearanceLog {
    private static let lock = NSLock()
    private static var seen = Set<String>()

    package static func warn(_ message: String) {
        #if DEBUG
        lock.lock()
        let inserted = seen.insert(message).inserted
        lock.unlock()
        if inserted {
            print("[xMoney appearance] \(message)")
        }
        #endif
    }

    package static func resetForTests() {
        lock.lock()
        seen.removeAll()
        lock.unlock()
    }
}

public extension PaymentConfig.SRGBColor {
    public init?(hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard let value = UInt64(raw, radix: 16) else { return nil }
        switch raw.count {
        case 6:
            self.init(
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255,
                alpha: 1
            )
        case 8:
            self.init(
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255,
                alpha: Double((value >> 24) & 0xFF) / 255
            )
        default:
            return nil
        }
    }
}

private func warnUnknown(_ dict: [String: Any], known: Set<String>, group: String) {
    for key in dict.keys where !known.contains(key) {
        AppearanceLog.warn("unknown \(group) key '\(key)'")
    }
}

private func appearanceDictionary(_ value: Any?) -> [String: Any]? {
    if let dict = value as? [String: Any] { return dict }
    guard let dict = value as? NSDictionary else { return nil }
    var result: [String: Any] = [:]
    dict.enumerateKeysAndObjects { key, object, _ in
        if let key = key as? String { result[key] = object }
    }
    return result
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
