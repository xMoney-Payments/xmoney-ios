import Foundation

package enum ThreeDSRedirectDecision: Equatable {
    /// HTTPS stays in Safari so the ACS cookie session continues.
    case stayInBrowser
    /// Cleartext or a system scheme. Do not launch it.
    case reject
    /// A non-system scheme, typically a bank app.
    case openExternally
}

package enum ThreeDSRedirectPolicy {
    /// System handlers and cleartext. Custom bank schemes are not in this set:
    /// the gateway does not send an allowlist, and `canOpenURL` hides schemes
    /// the host app did not declare.
    private static let blockedSchemes: Set<String> = [
        "http",
        "javascript",
        "data",
        "file",
        "blob",
        "about",
        "tel",
        "sms",
        "mailto",
        "facetime",
        "facetime-audio",
        "maps",
        "itms",
        "itms-apps",
        "shortcuts",
    ]

    package static func decide(_ url: URL) -> ThreeDSRedirectDecision {
        guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else {
            return .reject
        }
        if scheme == "https" {
            return .stayInBrowser
        }
        if blockedSchemes.contains(scheme) {
            return .reject
        }
        return .openExternally
    }
}
