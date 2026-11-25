import Foundation

public extension PaymentConfig.SRGBColor {
    /// Opaque mix of `self` over `base` by `weight` (0 = base, 1 = self).
    public func mixed(over base: PaymentConfig.SRGBColor, weight: Double) -> PaymentConfig.SRGBColor {
        let t = min(max(weight, 0), 1)
        return PaymentConfig.SRGBColor(
            red: red * t + base.red * (1 - t),
            green: green * t + base.green * (1 - t),
            blue: blue * t + base.blue * (1 - t),
            alpha: 1
        )
    }

    public func withAlpha(_ alpha: Double) -> PaymentConfig.SRGBColor {
        var copy = self
        copy.alpha = alpha
        return copy
    }

    /// Composite this color over an opaque base.
    public func composited(over base: PaymentConfig.SRGBColor) -> PaymentConfig.SRGBColor {
        let a = min(max(alpha, 0), 1)
        return PaymentConfig.SRGBColor(
            red: red * a + base.red * (1 - a),
            green: green * a + base.green * (1 - a),
            blue: blue * a + base.blue * (1 - a),
            alpha: 1
        )
    }

    public var relativeLuminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    public func contrast(against other: PaymentConfig.SRGBColor) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        let lighter = max(a, b)
        let darker = min(a, b)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Contrast after this color is painted over `base`. Alpha is part of the result.
    public func contrast(
        against surface: PaymentConfig.SRGBColor,
        compositedOver base: PaymentConfig.SRGBColor
    ) -> Double {
        composited(over: base).contrast(against: surface)
    }

    public var isAchromatic: Bool {
        let maxC = max(red, green, blue)
        let minC = min(red, green, blue)
        return maxC - minC < 0.04
    }

    /// Move lightness in OKLCH until `contrast` against `surface` is reached, keeping hue.
    /// Stops at the smallest lightness change that clears `target`. Chroma is reduced per
    /// sample so one out-of-gamut lightness does not dull the rest of the search.
    /// When the target is unreachable, returns ink or paper, whichever contrasts more.
    public func withContrast(atLeast target: Double, against surface: PaymentConfig.SRGBColor) -> PaymentConfig.SRGBColor {
        if contrast(against: surface) >= target { return self }
        let oklch = OKLCH(self)
        let towardWhite = PaymentConfig.SRGBColor.white.contrast(against: surface)
            >= PaymentConfig.SRGBColor.black.contrast(against: surface)
        var low = towardWhite ? oklch.l : 0
        var high = towardWhite ? 1 : oklch.l
        var passing: PaymentConfig.SRGBColor?
        var passingDistance = Double.greatestFiniteMagnitude
        func sample(at lightness: Double) -> PaymentConfig.SRGBColor? {
            var attempt = oklch.c
            for _ in 0..<16 {
                if let color = OKLCH(l: lightness, c: attempt, h: oklch.h).srgb() {
                    return color
                }
                if attempt <= 0.0001 { break }
                attempt *= 0.85
            }
            return OKLCH(l: lightness, c: 0, h: oklch.h).srgb()
        }
        for _ in 0..<24 {
            let mid = (low + high) / 2
            guard let color = sample(at: mid) else { break }
            if color.contrast(against: surface) >= target {
                let distance = abs(mid - oklch.l)
                if distance < passingDistance {
                    passing = color
                    passingDistance = distance
                }
                if towardWhite { high = mid } else { low = mid }
            } else if towardWhite {
                low = mid
            } else {
                high = mid
            }
        }
        if let passing { return passing }
        let ink = PaymentConfig.SRGBColor.ink
        let paper = PaymentConfig.SRGBColor.paper
        let fallback = ink.contrast(against: surface) >= paper.contrast(against: surface) ? ink : paper
        AppearanceLog.warn("contrast \(target):1 is unreachable on this surface; using \(fallback == ink ? "ink" : "paper")")
        return fallback
    }
}

private struct OKLCH {
    var l: Double
    var c: Double
    var h: Double

    init(_ color: PaymentConfig.SRGBColor) {
        let lab = OKLab(color)
        c = hypot(lab.a, lab.b)
        h = atan2(lab.b, lab.a)
        l = lab.l
    }

    init(l: Double, c: Double, h: Double) {
        self.l = l
        self.c = c
        self.h = h
    }

    func srgb() -> PaymentConfig.SRGBColor? {
        let lab = OKLab(l: l, a: c * cos(h), b: c * sin(h))
        return lab.srgb()
    }
}

private struct OKLab {
    var l: Double
    var a: Double
    var b: Double

    init(l: Double, a: Double, b: Double) {
        self.l = l
        self.a = a
        self.b = b
    }

    init(_ color: PaymentConfig.SRGBColor) {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let r = linear(color.red)
        let g = linear(color.green)
        let bLin = linear(color.blue)
        let lmsL = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * bLin)
        let lmsM = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * bLin)
        let lmsS = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * bLin)
        l = 0.2104542553 * lmsL + 0.7936177850 * lmsM - 0.0040720468 * lmsS
        a = 1.9779984951 * lmsL - 2.4285922050 * lmsM + 0.4505937099 * lmsS
        b = 0.0259040371 * lmsL + 0.7827717662 * lmsM - 0.8086757660 * lmsS
    }

    func srgb() -> PaymentConfig.SRGBColor? {
        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b
        let lmsL = l_ * l_ * l_
        let lmsM = m_ * m_ * m_
        let lmsS = s_ * s_ * s_
        let r = +4.0767416621 * lmsL - 3.3077115913 * lmsM + 0.2309699292 * lmsS
        let g = -1.2684380046 * lmsL + 2.6097574011 * lmsM - 0.3413193965 * lmsS
        let bLin = -0.0041960863 * lmsL - 0.7034186147 * lmsM + 1.7076147010 * lmsS
        func encode(_ channel: Double) -> Double? {
            let clipped = min(max(channel, 0), 1)
            if abs(channel - clipped) > 0.002 { return nil }
            let encoded = clipped <= 0.0031308
                ? 12.92 * clipped
                : 1.055 * pow(clipped, 1 / 2.4) - 0.055
            if encoded < -0.0001 || encoded > 1.0001 { return nil }
            return min(max(encoded, 0), 1)
        }
        guard let red = encode(r), let green = encode(g), let blue = encode(bLin) else { return nil }
        return PaymentConfig.SRGBColor(red: red, green: green, blue: blue)
    }
}
