import SwiftUI

@main
struct ExampleApp: App {
    @StateObject private var theme = ExampleThemeState()

    var body: some Scene {
        WindowGroup {
            Group {
                if #available(iOS 16.0, *) {
                    NavigationStack {
                        MenuScreen()
                    }
                } else {
                    NavigationView {
                        MenuScreen()
                    }
                    .navigationViewStyle(.stack)
                }
            }
            .modifier(ExampleTheme(theme: theme))
            .onAppear { ExampleRoobert.registerIfNeeded() }
        }
    }
}
