import Foundation
import GRDB

/// Owns the SQLite database (copied to Application Support on first run) and
/// provides reference lookup + full-text search over the 개역개정 (NKRV) text.
final class BibleStore {
    static let shared: BibleStore? = {
        do {
            return try BibleStore()
        } catch {
            NSLog("[biblego] BibleStore init failed: \(error)")
            return nil
        }
    }()

    let dbQueue: DatabaseQueue
    private(set) var books: [Book] = []
    private(set) var booksById: [Int: Book] = [:]
    private(set) var ftsAvailable = false

    enum StoreError: Error { case missingResource }

    init() throws {
        let fm = FileManager.default
        let support = try fm
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("biblego", isDirectory: true)
        try fm.createDirectory(at: support, withIntermediateDirectories: true)
        let dest = support.appendingPathComponent("bible.sqlite")

        if !fm.fileExists(atPath: dest.path) {
            guard let bundled = Bundle.module.url(forResource: "bible", withExtension: "sqlite") else {
                throw StoreError.missingResource
            }
            try fm.copyItem(at: bundled, to: dest)
        }

        dbQueue = try DatabaseQueue(path: dest.path)
        try loadBooks()
        ensureFTS()
    }

    private func loadBooks() throws {
        books = try dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT id, abbr, name, testament, aliases, sort FROM books ORDER BY sort")
                .map {
                    Book(id: $0["id"], abbr: $0["abbr"], name: $0["name"],
                         testament: $0["testament"], aliases: $0["aliases"], sort: $0["sort"])
                }
        }
        booksById = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
    }

    /// Builds the FTS5 (trigram) index in the writable copy on first launch so
    /// the tokenizer always matches the runtime SQLite. Falls back to LIKE search
    /// if the trigram tokenizer is unavailable.
    private func ensureFTS() {
        do {
            try dbQueue.write { db in
                let exists = try Bool.fetchOne(
                    db, sql: "SELECT 1 FROM sqlite_master WHERE type='table' AND name='verses_fts'"
                ) ?? false
                if !exists {
                    try db.execute(sql: """
                        CREATE VIRTUAL TABLE verses_fts USING fts5(
                            text, content='verses', content_rowid='id', tokenize='trigram'
                        )
                        """)
                    try db.execute(sql: "INSERT INTO verses_fts(rowid, text) SELECT id, text FROM verses")
                }
            }
            ftsAvailable = true
        } catch {
            NSLog("[biblego] FTS unavailable, using LIKE fallback: \(error)")
            ftsAvailable = false
        }
    }

    // MARK: - Queries

    func verses(bookId: Int, chapter: Int, verseStart: Int?, verseEnd: Int?) -> [Verse] {
        (try? dbQueue.read { db -> [Verse] in
            var sql = "SELECT id, book_id, chapter, verse, text FROM verses WHERE book_id = ? AND chapter = ?"
            var args: [DatabaseValueConvertible] = [bookId, chapter]
            if let vs = verseStart {
                let ve = verseEnd ?? vs
                sql += " AND verse BETWEEN ? AND ?"
                args.append(min(vs, ve))
                args.append(max(vs, ve))
            }
            sql += " ORDER BY verse LIMIT 300"
            return try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args)).map(self.verse(from:))
        }) ?? []
    }

    func search(_ text: String, limit: Int = 40) -> [Verse] {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }
        return (try? dbQueue.read { db -> [Verse] in
            if self.ftsAvailable && q.count >= 3 {
                let match = "\"" + q.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                let sql = """
                    SELECT v.id, v.book_id, v.chapter, v.verse, v.text
                    FROM verses_fts f JOIN verses v ON v.id = f.rowid
                    WHERE verses_fts MATCH ? ORDER BY rank LIMIT ?
                    """
                return try Row.fetchAll(db, sql: sql, arguments: [match, limit]).map(self.verse(from:))
            } else {
                let like = "%" + q + "%"
                let sql = "SELECT id, book_id, chapter, verse, text FROM verses WHERE text LIKE ? LIMIT ?"
                return try Row.fetchAll(db, sql: sql, arguments: [like, limit]).map(self.verse(from:))
            }
        }) ?? []
    }

    private func verse(from row: Row) -> Verse {
        let bid: Int = row["book_id"]
        let b = booksById[bid]
        return Verse(id: row["id"], bookId: bid, chapter: row["chapter"], verse: row["verse"],
                     text: row["text"], bookName: b?.name ?? "", bookAbbr: b?.abbr ?? "")
    }
}
