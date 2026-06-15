import Foundation

struct Book: Identifiable, Hashable {
    let id: Int
    let abbr: String
    let name: String
    let testament: String
    let aliases: String
    let sort: Int
}

struct Verse: Identifiable, Hashable {
    let id: Int
    let bookId: Int
    let chapter: Int
    let verse: Int
    let text: String
    var bookName: String = ""
    var bookAbbr: String = ""

    var reference: String { "\(bookName) \(chapter):\(verse)" }
}
