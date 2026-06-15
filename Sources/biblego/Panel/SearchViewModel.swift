import Combine
import Foundation

struct SearchResult: Identifiable {
    let id: String
    let reference: String
    let preview: String
    let insertText: String
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [SearchResult] = []
    @Published var selected = 0

    let context: FocusContext
    var onClose: () -> Void = {}
    var onConfirm: (SearchResult) -> Void = { _ in }

    private let store: BibleStore?
    private let parser: ReferenceParser?
    private var bag = Set<AnyCancellable>()

    init(context: FocusContext) {
        self.context = context
        self.store = BibleStore.shared
        self.parser = BibleStore.shared.map { ReferenceParser(books: $0.books) }

        $query
            .removeDuplicates()
            .debounce(for: .milliseconds(110), scheduler: RunLoop.main)
            .sink { [weak self] q in self?.run(q) }
            .store(in: &bag)
    }

    // MARK: - Search

    private func run(_ raw: String) {
        guard let store else { results = []; return }
        let q = raw.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; selected = 0; return }

        // Always list verses one per row so the user picks an individual 구절.
        var out: [SearchResult] = []
        if let ref = parser?.parse(q) {
            out = store.verses(bookId: ref.book.id, chapter: ref.chapter,
                               verseStart: ref.verseStart, verseEnd: ref.verseEnd)
                .map { singleResult($0) }
        }
        if out.isEmpty {
            out = store.search(q).map { singleResult($0) }
        }
        results = out
        selected = 0
    }

    private func singleResult(_ v: Verse) -> SearchResult {
        let ref = v.reference
        let insert = AppSettings.includeReference ? "\(v.text) (\(ref))" : v.text
        return SearchResult(id: "v\(v.id)", reference: ref, preview: v.text, insertText: insert)
    }

    // MARK: - Navigation

    func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selected = (selected + delta + results.count) % results.count
    }

    func confirm() {
        guard results.indices.contains(selected) else { onClose(); return }
        onConfirm(results[selected])
    }

    func close() { onClose() }
}
