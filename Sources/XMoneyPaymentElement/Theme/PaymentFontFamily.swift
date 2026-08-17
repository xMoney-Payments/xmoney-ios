import CoreText
import UIKit

package enum PaymentFontFamily {
    private static var didRegister = false
    private static let lock = NSLock()

    private static let faces: [(file: String, postScript: String)] = [
        ("roobert_regular", "RoobertPRO-Regular"),
        ("roobert_medium", "RoobertPRO-Medium"),
        ("roobert_semibold", "RoobertPRO-SemiBold"),
        ("roobert_bold", "RoobertPRO-Bold"),
    ]

    package static func registerIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !didRegister else { return }
        didRegister = true

        for face in faces {
            guard let url = fontURL(named: face.file) else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    package static func regular(size: CGFloat) -> UIFont {
        font(named: "RoobertPRO-Regular", size: size, weight: .regular)
    }

    package static func medium(size: CGFloat) -> UIFont {
        font(named: "RoobertPRO-Medium", size: size, weight: .medium)
    }

    package static func semibold(size: CGFloat) -> UIFont {
        font(named: "RoobertPRO-SemiBold", size: size, weight: .semibold)
    }

    package static func bold(size: CGFloat) -> UIFont {
        font(named: "RoobertPRO-Bold", size: size, weight: .bold)
    }

    package static func font(weight: UIFont.Weight, size: CGFloat) -> UIFont {
        switch weight {
        case .bold, .heavy, .black:
            return bold(size: size)
        case .semibold:
            return semibold(size: size)
        case .medium:
            return medium(size: size)
        default:
            return regular(size: size)
        }
    }

    package static var isAvailable: Bool {
        registerIfNeeded()
        return UIFont(name: "RoobertPRO-Regular", size: 12) != nil
    }

    private static func font(named: String, size: CGFloat, weight: UIFont.Weight) -> UIFont {
        registerIfNeeded()
        return UIFont(name: named, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }

    private static func fontURL(named: String) -> URL? {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = EmbeddedAssets.bundle
        #endif
        if let url = bundle.url(forResource: named, withExtension: "otf", subdirectory: "Fonts") {
            return url
        }
        return bundle.url(forResource: named, withExtension: "otf")
    }
}
