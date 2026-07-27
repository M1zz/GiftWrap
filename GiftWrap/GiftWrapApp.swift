import SwiftUI

@main
@MainActor
struct GiftWrapApp: App {
    @StateObject private var ledger = GiftLedger()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ledger)
                .frame(minWidth: 1140, minHeight: 760)
        }
        .defaultSize(width: 1240, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
