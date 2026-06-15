import AppKit
import ApplicationServices

enum Permissions {
    /// Whether this process is trusted for the Accessibility API. Pass `prompt: true`
    /// to show the system prompt that deep-links into Privacy settings.
    @discardableResult
    static func accessibilityTrusted(prompt: Bool) -> Bool {
        // Constant value of kAXTrustedCheckOptionPrompt; used as a literal to avoid
        // Unmanaged<CFString> import differences across SDKs.
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
