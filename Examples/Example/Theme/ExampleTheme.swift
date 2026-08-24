import SwiftUI
import UIKit

@MainActor
final class ExampleThemeState: ObservableObject {
    @Published var isDark: Bool {
        didSet { UserDefaults.standard.set(isDark, forKey: Self.key) }
    }

    private static let key = "example.dark"

    init() {
        if UserDefaults.standard.object(forKey: Self.key) != nil {
            isDark = UserDefaults.standard.bool(forKey: Self.key)
        } else {
            isDark = UITraitCollection.current.userInterfaceStyle == .dark
        }
    }

    func toggle() {
        isDark.toggle()
    }
}

struct ExampleSemanticColors {
    var success: Color
    var successSoft: Color
    var dangerSoft: Color
    var hairline: Color
}

private struct SemanticsKey: EnvironmentKey {
    static let defaultValue = ExampleSemanticColors(
        success: ExampleColors.success,
        successSoft: ExampleColors.successSoftLight,
        dangerSoft: ExampleColors.dangerSoftLight,
        hairline: ExampleColors.lightHairline
    )
}

private struct BrandAccentKey: EnvironmentKey {
    static let defaultValue = ExampleColors.purple
}

private struct BrandOnAccentKey: EnvironmentKey {
    static let defaultValue = Color.white
}

private struct BrandAccentTextKey: EnvironmentKey {
    static let defaultValue = ExampleColors.purple
}

extension EnvironmentValues {
    var exampleSemantics: ExampleSemanticColors {
        get { self[SemanticsKey.self] }
        set { self[SemanticsKey.self] = newValue }
    }

    var brandAccent: Color {
        get { self[BrandAccentKey.self] }
        set { self[BrandAccentKey.self] = newValue }
    }

    var brandOnAccent: Color {
        get { self[BrandOnAccentKey.self] }
        set { self[BrandOnAccentKey.self] = newValue }
    }

    var brandAccentText: Color {
        get { self[BrandAccentTextKey.self] }
        set { self[BrandAccentTextKey.self] = newValue }
    }
}

struct ExampleTheme: ViewModifier {
    @ObservedObject var theme: ExampleThemeState

    func body(content: Content) -> some View {
        let dark = theme.isDark
        let semantics = ExampleSemanticColors(
            success: ExampleColors.success,
            successSoft: dark ? ExampleColors.successSoftDark : ExampleColors.successSoftLight,
            dangerSoft: dark ? ExampleColors.dangerSoftDark : ExampleColors.dangerSoftLight,
            hairline: dark ? ExampleColors.darkHairline : ExampleColors.lightHairline
        )
        content
            .environmentObject(theme)
            .environment(\.exampleSemantics, semantics)
            .preferredColorScheme(dark ? .dark : .light)
            .background((dark ? ExampleColors.darkBg : ExampleColors.lightBg).ignoresSafeArea())
    }
}
