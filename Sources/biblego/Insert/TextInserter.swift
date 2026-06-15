import AppKit
import ApplicationServices
import CoreGraphics

enum InsertMode: String {
    case paste      // clipboard + synthesized ⌘V (works almost everywhere)
    case axDirect   // set kAXSelectedText directly (cleaner, fewer apps support it)
}

enum TextInserter {
    /// Inserts text into the previously-focused app. Reactivates that app first,
    /// then either sets the AX value directly or pastes via a synthesized ⌘V.
    static func insert(_ text: String, context: FocusContext, mode: InsertMode) {
        context.app?.activate()

        let doInsert = {
            if mode == .axDirect, let element = context.element, axInsert(text, into: element) {
                return
            }
            pasteInsert(text)
        }

        // Give the target app a moment to come back to the foreground.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: doInsert)
    }

    // MARK: - AX direct insert

    private static func axInsert(_ text: String, into element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success
    }

    // MARK: - Clipboard paste

    private static func pasteInsert(_ text: String) {
        let pasteboard = NSPasteboard.general
        let saved = savePasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        postCommandV()

        // Restore the user's original clipboard after the paste has been consumed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            restorePasteboard(pasteboard, saved)
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // kVK_ANSI_V
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private static func savePasteboard(_ pb: NSPasteboard) -> [[String: Data]] {
        (pb.pasteboardItems ?? []).map { item in
            var dict: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dict[type.rawValue] = data }
            }
            return dict
        }
    }

    private static func restorePasteboard(_ pb: NSPasteboard, _ saved: [[String: Data]]) {
        pb.clearContents()
        let items: [NSPasteboardItem] = saved.compactMap { dict in
            guard !dict.isEmpty else { return nil }
            let item = NSPasteboardItem()
            for (key, value) in dict {
                item.setData(value, forType: NSPasteboard.PasteboardType(key))
            }
            return item
        }
        if !items.isEmpty { pb.writeObjects(items) }
    }
}
