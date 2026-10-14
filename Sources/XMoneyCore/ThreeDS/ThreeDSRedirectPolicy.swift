import Foundation

package enum ThreeDSRedirectDecision: Equatable {
    /// HTTPS stays in Safari so the ACS cookie session continues.
    case stayInBrowser
    /// Cleartext or a system scheme. Do not launch it.
    case reject
    /// A non-system scheme, typically a bank app. The shopper confirms before it opens.
    case openExternally
}

package enum ThreeDSRedirectPolicy {
    /// System handlers, App Store and enterprise install, Settings, and cleartext.
    /// Custom bank schemes are not in this set: the gateway does not send an allowlist,
    /// and `canOpenURL` hides schemes the host app did not declare.
    private static let blockedSchemes: Set<String> = [
        "http",
        "javascript",
        "data",
        "file",
        "blob",
        "about",
        "tel",
        "telprompt",
        "sms",
        "mailto",
        "facetime",
        "facetime-audio",
        "facetime-prompt",
        "maps",
        "itms",
        "itmss",
        "itms-apps",
        "itms-appss",
        "itms-services",
        "itms-beta",
        "itms-books",
        "ibooks",
        "prefs",
        "app-prefs",
        "shoebox",
        "wallet",
        "music",
        "videos",
        "shortcuts",
        "workflow",
    ]

    private static let blockedSchemePrefixes = ["x-apple-"]

    package static func decide(_ url: URL) -> ThreeDSRedirectDecision {
        guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else {
            return .reject
        }
        if scheme == "https" {
            return .stayInBrowser
        }
        if blockedSchemes.contains(scheme)
            || blockedSchemePrefixes.contains(where: { scheme.hasPrefix($0) }) {
            return .reject
        }
        return .openExternally
    }
}
