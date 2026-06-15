import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global hotkey that opens the verse search panel. Default: ⌥Space.
    static let openSearch = Self("openSearch", default: .init(.space, modifiers: [.option]))
}
