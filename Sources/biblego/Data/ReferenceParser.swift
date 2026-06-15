import Foundation

struct ParsedReference {
    let book: Book
    let chapter: Int
    let verseStart: Int?
    let verseEnd: Int?
}

/// Parses Korean Bible references like "요 3:16", "요한복음 3장 16절",
/// "창1:1-3", "시 23", "삼상3:1". Falls back to nil when no book/number is found.
final class ReferenceParser {
    private let tokens: [(token: String, book: Book)]

    /// Maps full-width ASCII variants (e.g. '：', '３') and the ideographic space to
    /// their plain ASCII equivalents, so references typed with a Korean IME parse.
    private static func normalize(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            switch u.value {
            case 0xFF01...0xFF5E: out.append(Unicode.Scalar(u.value - 0xFEE0)!)
            case 0x3000: out.append(" ")
            default: out.append(u)
            }
        }
        return String(out)
    }

    init(books: [Book]) {
        var t: [(String, Book)] = []
        for b in books {
            var forms = [b.abbr, b.name]
            forms += b.aliases.split(separator: " ").map(String.init)
            for f in Set(forms) where !f.isEmpty {
                t.append((f.lowercased(), b))
            }
        }
        // Longest token first so "요한복음" wins over "요", "삼상" over partials, etc.
        // Tie-break by book order (id) so prefix matches resolve deterministically.
        tokens = t.sorted { ($0.0.count, $1.1.id) > ($1.0.count, $0.1.id) }
    }

    func parse(_ input: String) -> ParsedReference? {
        let s = Self.normalize(input).trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, let firstDigit = s.firstIndex(where: { $0.isNumber }) else { return nil }

        let bookPart = String(s[s.startIndex..<firstDigit])
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        guard !bookPart.isEmpty, let book = matchBook(bookPart) else { return nil }

        let numberPart = String(s[firstDigit...])
        guard let (ch, vs, ve) = parseNumbers(numberPart) else { return nil }
        return ParsedReference(book: book, chapter: ch, verseStart: vs, verseEnd: ve)
    }

    private func matchBook(_ part: String) -> Book? {
        if let exact = tokens.first(where: { $0.token == part }) { return exact.book }
        if let prefix = tokens.first(where: { $0.token.hasPrefix(part) }) { return prefix.book }
        return nil
    }

    /// Pulls chapter / verse / range-end out of the number part. Any non-digit
    /// (':', '：', '.', '장', '절', whitespace, '-', '~', …) acts as a separator, so
    /// the parse is robust to whatever colon/separator a Korean IME produces.
    private func parseNumbers(_ part: String) -> (Int, Int?, Int?)? {
        let nums = part.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard let chapter = nums.first else { return nil }
        return (chapter, nums.count > 1 ? nums[1] : nil, nums.count > 2 ? nums[2] : nil)
    }
}
