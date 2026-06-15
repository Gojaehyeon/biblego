import AppKit
import ApplicationServices

/// Snapshot of where the user was typing when the hotkey fired:
/// the previously-frontmost app, its focused accessibility element, and the
/// caret rectangle in Cocoa (bottom-left origin) screen coordinates.
struct FocusContext {
    let app: NSRunningApplication?
    let element: AXUIElement?
    let caretRect: CGRect?
}
