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
                if raw != nil { AppearanceLog.warn("unknown colorScheme '\(raw!)', using automatic") }
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
        public static let ink = SRGBColor(red: 0x16 / 255, green: 0x14 / 255, blue: 0x1A / 255)
        public static let paper = SRGBColor(red: 0xFA / 255, green: 0xFA / 255, blue: 0xFA / 255)

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

        static func from(_ value: Any?) -> AppearanceOverrides {
            guard let dict = appearanceDictionary(value) else { return .init() }
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

    /// Merchant theme. An empty value is the built-in xMoney light and dark themes.
    public struct Appearance: Equatable, Sendable {
        public var colorScheme: ColorSchemePreference
        public var brandColor: ThemeColor?
        public var accentColor: ThemeColor?
        public var backgroundColor: ThemeColor?
        public var neutralTint: ThemeColor?
        public var overrides: AppearanceOverrides
        public var corners: Corners
        public var pillButtons: Bool
        public var fontFamily: String?

        public init(
            colorScheme: ColorSchemePreference = .automatic,
            brandColor: ThemeColor? = nil,
            accentColor: ThemeColor? = nil,
            backgroundColor: ThemeColor? = nil,
            neutralTint: ThemeColor? = nil,
            overrides: AppearanceOverrides = .init(),
            corners: Corners = .default,
            pillButtons: Bool = true,
            fontFamily: String? = nil
        ) {
            self.colorScheme = colorScheme
            self.brandColor = brandColor
            self.accentColor = accentColor
            self.backgroundColor = backgroundColor
            self.neutralTint = neutralTint
            self.overrides = overrides
            self.corners = corners
            self.pillButtons = pillButtons
            self.fontFamily = fontFamily
        }

        public static func from(_ dict: [String: Any]?) -> Appearance {
            guard let dict else { return Appearance() }
            let known: Set<String> = [
                "colorScheme", "brandColor", "accentColor", "backgroundColor", "neutralTint",
                "overrides", "corners", "pillButtons", "fontFamily",
            ]
            for key in dict.keys where !known.contains(key) {
                AppearanceLog.warn("unknown appearance key '\(key)'")
            }
            let pill = dict["pillButtons"] as? Bool ?? true
            return Appearance(
                colorScheme: ColorSchemePreference.from(dict["colorScheme"] as? String),
                brandColor: ThemeColor.from(dict["brandColor"]),
                accentColor: ThemeColor.from(dict["accentColor"]),
                backgroundColor: ThemeColor.from(dict["backgroundColor"]),
                neutralTint: ThemeColor.from(dict["neutralTint"]),
                overrides: AppearanceOverrides.from(dict["overrides"]),
                corners: Corners.from(dict["corners"]),
                pillButtons: pill,
                fontFamily: (dict["fontFamily"] as? String)?.nilIfEmpty
            )
        }
    }
}

public enum AppearanceLog {
    private static var seen = Set<String>()

    public static func warn(_ message: String) {
        #if DEBUG
        if seen.insert(message).inserted {
            print("[xMoney appearance] \(message)")
        }
        #endif
    }

    public static func resetForTests() {
        seen.removeAll()
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
