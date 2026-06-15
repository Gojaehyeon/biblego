import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global hotkey that opens the verse search panel. Default: ⌥B.
    static let openSearch = Self("openSearch", default: .init(.b, modifiers: [.option]))
}
