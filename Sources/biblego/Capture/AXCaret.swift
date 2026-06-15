import AppKit
import ApplicationServices

enum AXCaret {
    /// Captures the current focus context: frontmost app + focused text element +
    /// caret screen rect. Degrades gracefully through a fallback chain.
    static func capture() -> FocusContext {
        let app = NSWorkspace.shared.frontmostApplication
        let system = AXUIElementCreateSystemWide()

        var focused: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused)
        guard err == .success, let ref = focused else {
            return FocusContext(app: app, element: nil, caretRect: mouseFallbackRect())
        }
        let element = ref as! AXUIElement
        let rect = caretScreenRect(of: element) ?? elementFrame(element) ?? mouseFallbackRect()
        return FocusContext(app: app, element: element, caretRect: rect)
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
        if rect.isNull || (rect.origin.x == 0 && rect.origin.y == 0) { return nil }
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

    private static func mouseFallbackRect() -> CGRect {
        let p = NSEvent.mouseLocation // already Cocoa (bottom-left) coords
        return CGRect(x: p.x, y: p.y - 22, width: 1, height: 22)
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
