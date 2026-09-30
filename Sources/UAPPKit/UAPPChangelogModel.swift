#if canImport(SwiftUI)
import SwiftUI

@MainActor
final class UAPPChangelogModel: ObservableObject {
    @Published private(set) var entries: [UAPPChangelogEntry]
    @Published private(set) var nextCursor: String?
    @Published private(set) var isLoadingMore: Bool
    @Published private(set) var loadMoreError: String?
    private let client: UAPPClient
    let pageSize: Int
    private var isLoading = false
    private var loadedCursors: Set<String> = []

    init(
        client: UAPPClient,
        entries: [UAPPChangelogEntry] = [],
        nextCursor: String? = nil,
        isLoadingMore: Bool = false,
        loadMoreError: String? = nil,
        pageSize: Int = 10
    ) {
        self.client = client
        self.pageSize = min(max(pageSize, 1), 50)
        self.entries = entries
        self.nextCursor = nextCursor
        self.isLoadingMore = isLoadingMore
        self.loadMoreError = loadMoreError
    }

    func load() async throws {
        guard !isLoading, !isLoadingMore else { return }
        isLoading = true
        defer { isLoading = false }
        let page = try await client.changelogPage(limit: pageSize)
        entries = unique(page.entries)
        nextCursor = page.nextCursor
        loadedCursors = []
        loadMoreError = nil
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        loadMoreError = nil
        defer { isLoadingMore = false }
        do {
            let page = try await client.changelogPage(limit: pageSize, cursor: cursor)
            entries = unique(entries + page.entries)
            loadedCursors.insert(cursor)
            nextCursor = page.nextCursor.flatMap { loadedCursors.contains($0) ? nil : $0 }
        } catch {
            loadMoreError = (error as? LocalizedError)?.errorDescription
                ?? uappLocalized("changelog.load_error")
        }
    }

    private func unique(_ entries: [UAPPChangelogEntry]) -> [UAPPChangelogEntry] {
        var seen: Set<String> = []
        return entries.filter { seen.insert($0.slug).inserted }
    }
}
#endif
