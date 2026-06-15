import AppKit
import SwiftUI

/// Borderless, non-activating panel that can still become key so its search
/// field receives keystrokes (including Korean IME) without forcing a full app
/// activation that would disrupt the underlying app.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class SearchPanel: NSObject, NSWindowDelegate {
    static let shared = SearchPanel()

    private var panel: KeyablePanel?
    private var anchorTopLeft: NSPoint = .zero

    func toggle() { panel == nil ? show() : hide() }

    func show() {
        if panel != nil { hide() }

        let context = AXCaret.capture()
        let model = SearchViewModel(context: context)
        model.onClose = { [weak self] in self?.hide() }
        model.onConfirm = { [weak self] result in
            self?.hide()
            TextInserter.insert(result.insertText, context: context, mode: AppSettings.insertMode)
        }

        let hosting = NSHostingController(rootView: SearchView(model: model))
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        self.panel = panel
        position(panel, near: context.caretRect)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    // Re-anchor the top-left corner when SwiftUI content resizes (results load),
    // so the panel grows downward from the caret instead of drifting.
    func windowDidResize(_ notification: Notification) {
        guard let panel else { return }
        if panel.frame.origin.x != anchorTopLeft.x ||
            (panel.frame.origin.y + panel.frame.height) != anchorTopLeft.y {
            panel.setFrameTopLeftPoint(anchorTopLeft)
        }
    }

    // Auto-dismiss when focus leaves the panel (e.g. the user clicks elsewhere).
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func position(_ panel: NSPanel, near caret: CGRect?) {
        let size = panel.frame.size
        let screen = screenContaining(point: caret?.origin) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let gap: CGFloat = 6

        var topLeft: NSPoint
        if let caret {
            topLeft = NSPoint(x: caret.minX, y: caret.minY - gap)
            // If there isn't room below the caret, flip above it.
            if topLeft.y - size.height < visible.minY {
                topLeft.y = caret.maxY + size.height + gap
            }
        } else {
            topLeft = NSPoint(x: visible.midX - size.width / 2, y: visible.midY + size.height / 2)
        }

        // Clamp horizontally and vertically into the visible frame.
        topLeft.x = min(max(topLeft.x, visible.minX + 4), visible.maxX - size.width - 4)
        topLeft.y = min(max(topLeft.y, visible.minY + size.height + 4), visible.maxY - 4)

        anchorTopLeft = topLeft
        panel.setFrameTopLeftPoint(topLeft)
    }

    private func screenContaining(point: CGPoint?) -> NSScreen? {
        guard let point else { return nil }
        return NSScreen.screens.first { $0.frame.contains(point) }
    }
}
