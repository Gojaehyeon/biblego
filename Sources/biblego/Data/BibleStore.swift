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

    /// Keyword search over verse text. The query is split on whitespace and every
    /// term must appear (substring AND), so "여호와 목자" finds 시 23:1 even though
    /// the words aren't adjacent. Verses that contain the whole query verbatim are
    /// ranked first, then results follow canonical (창→계) book/chapter/verse order.
    func search(_ text: String, limit: Int = 40) -> [Verse] {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }
        let terms = q.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return [] }

        return (try? dbQueue.read { db -> [Verse] in
            var clauses: [String] = []
            var args: [DatabaseValueConvertible] = []
            // Boost verses containing the exact query (with its spaces) as a run.
            args.append("%" + Self.escapeLike(q) + "%")
            for term in terms {
                clauses.append(#"text LIKE ? ESCAPE '\'"#)
                args.append("%" + Self.escapeLike(term) + "%")
            }
            args.append(limit)
            let sql = """
                SELECT id, book_id, chapter, verse, text,
                       (text LIKE ? ESCAPE '\\') AS exact
                FROM verses
                WHERE \(clauses.joined(separator: " AND "))
                ORDER BY exact DESC, book_id, chapter, verse
                LIMIT ?
                """
            return try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args)).map(self.verse(from:))
        }) ?? []
    }

    /// Escapes LIKE metacharacters so user input is matched literally (ESCAPE '\').
    private static func escapeLike(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    private func verse(from row: Row) -> Verse {
        let bid: Int = row["book_id"]
        let b = booksById[bid]
        return Verse(id: row["id"], bookId: bid, chapter: row["chapter"], verse: row["verse"],
                     text: row["text"], bookName: b?.name ?? "", bookAbbr: b?.abbr ?? "")
    }
}
