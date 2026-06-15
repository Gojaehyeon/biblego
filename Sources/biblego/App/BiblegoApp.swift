import SwiftUI

@main
struct BiblegoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("성경", systemImage: "book.closed.fill") {
            MenuContent()
        }

        Settings {
            SettingsView()
        }
    }
}
