import Foundation

/// Thin typed accessors over UserDefaults shared by the UI and the inserter.
enum AppSettings {
    static let insertModeKey = "insertMode"
    static let includeReferenceKey = "includeReference"

    private static var defaults: UserDefaults { .standard }

    static var insertMode: InsertMode {
        InsertMode(rawValue: defaults.string(forKey: insertModeKey) ?? "") ?? .paste
    }

    static var includeReference: Bool {
        defaults.bool(forKey: includeReferenceKey) // defaults to false
    }
}
