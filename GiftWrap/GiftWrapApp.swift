import SwiftUI

@main
@MainActor
struct GiftWrapApp: App {
    @StateObject private var ledger = GiftLedger()
    @ObservedObject private var loc = Localization.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ledger)
                .frame(minWidth: 1140, minHeight: 760)
        }
        .defaultSize(width: 1240, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) { }

            // In the menu bar rather than buried in the form: the interface language is
            // an app-wide setting, and it's where anyone who opened the app in a language
            // they don't read would go looking.
            CommandMenu(loc.s(T.languageMenu)) {
                Picker(loc.s(T.languageMenu), selection: $loc.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.inline)
            }
        }
    }
}
