import AppKit
import ApplicationServices

enum AXCaret {
    /// Captures the current focus context: frontmost app + focused text element +
    /// caret screen rect. Degrades gracefully through a fallback chain.
    static func capture() -> FocusContext {
        let app = NSWorkspace.shared.frontmostApplication
        guard let element = focusedElement(app: app) else {
            return FocusContext(app: app, element: nil, caretRect: nil)
        }
        // Prefer the exact caret rect; fall back to the focused element's frame for
        // apps (e.g. Notion) that don't report caret bounds.
        let rect = caretScreenRect(of: element) ?? elementFrame(element)
        return FocusContext(app: app, element: element, caretRect: rect)
    }

    /// The focused text element: try the system-wide focus first, then fall back
    /// to the frontmost app's own AXFocusedUIElement (some apps only answer there).
    private static func focusedElement(app: NSRunningApplication?) -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var ref: CFTypeRef?
        if AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &ref) == .success,
           let ref { return (ref as! AXUIElement) }

        if let pid = app?.processIdentifier {
            let appEl = AXUIElementCreateApplication(pid)
            var aref: CFTypeRef?
            if AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &aref) == .success,
               let aref { return (aref as! AXUIElement) }
        }
        return nil
    }

    /// caret rect via kAXSelectedTextRange -> kAXBoundsForRange (top-left origin) -> Cocoa.
    private static func caretScreenRect(of element: AXUIElement) -> CGRect? {
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeValue = rangeRef, CFGetTypeID(rangeValue) == AXValueGetTypeID()
        else { return nil }

        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else { return nil }
        // Use a zero-length range at the caret to get its bounds.
        var caret = CFRange(location: range.location, length: 0)
        guard let caretValue = AXValueCreate(.cfRange, &caret) else { return nil }

        var boundsRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXBoundsForRangeParameterizedAttribute as CFString, caretValue, &boundsRef
        ) == .success, let boundsValue = boundsRef, CFGetTypeID(boundsValue) == AXValueGetTypeID()
        else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect) else { return nil }
        // A real caret has a positive line height; apps that don't support caret
        // bounds (e.g. Notion) hand back a degenerate rect — reject it so we fall
        // through to the focused element's frame instead of jumping to (0,0).
        if rect.isNull || rect.height <= 0 || (rect.origin.x == 0 && rect.origin.y == 0) {
            return nil
        }
        return axToCocoa(rect)
    }

    /// Fallback: the focused element's own frame (top-left origin) -> Cocoa.
    private static func elementFrame(_ element: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let p = posRef, let s = sizeRef
        else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &origin),
              AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return axToCocoa(CGRect(origin: origin, size: size))
    }

    /// Converts a top-left-origin screen rect (Accessibility / CoreGraphics) into
    /// Cocoa's bottom-left-origin screen coordinates.
    private static func axToCocoa(_ r: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height
            ?? r.maxY
        return CGRect(x: r.origin.x, y: primaryHeight - r.origin.y - r.size.height,
                      width: r.size.width, height: r.size.height)
    }
}
