import AppKit
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Warm up the database (copy + FTS build on first run).
        _ = BibleStore.shared

        KeyboardShortcuts.onKeyUp(for: .openSearch) {
            SearchPanel.shared.toggle()
        }

        // Prompt for Accessibility on first launch (needed for caret reads + paste).
        if !Permissions.accessibilityTrusted(prompt: false) {
            Permissions.accessibilityTrusted(prompt: true)
        }
    }
}
