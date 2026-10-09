#if canImport(SwiftUI)
import SwiftUI

@MainActor
final class UAPPReviewsModel: ObservableObject {
    let translationCache = UAPPReviewTranslationCache()
    @Published private(set) var reviews: [UAPPReview]
    @Published private(set) var isLoading: Bool
    @Published private(set) var hasError: Bool
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMoreError = false
    @Published private(set) var nextCursor: String?
    /// Resumo informado pelo servidor na primeira página.
    @Published private(set) var serverSummary: UAPPReviewSummary?
    private let client: UAPPClient
    let pageSize: Int
    private var didLoad: Bool

    init(client: UAPPClient, reviews: [UAPPReview] = [], isLoading: Bool = true, hasError: Bool = false, pageSize: Int = 20) {
        self.client = client
        self.pageSize = min(max(pageSize, 1), 50)
        self.reviews = reviews
        self.isLoading = isLoading
        self.hasError = hasError
        didLoad = !isLoading
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await load()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await client.reviewsPage(limit: pageSize)
            reviews = unique(page.reviews)
            nextCursor = page.nextCursor
            serverSummary = page.summary
            hasError = false
            hasMoreError = false
        } catch {
            hasError = true
        }
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await client.reviewsPage(limit: pageSize, cursor: cursor)
            reviews = unique(reviews + page.reviews)
            // Um cursor repetido não pode criar um loop de requisições.
            nextCursor = page.nextCursor == cursor ? nil : page.nextCursor
            hasMoreError = false
        } catch {
            hasMoreError = true
        }
    }

    /// Resumo das notas: o do servidor ou, com todas as avaliações já carregadas, o calculado aqui.
    /// Com páginas ainda por carregar e sem resumo do servidor, não há total confiável para mostrar.
    var summary: UAPPReviewSummary? {
        if let serverSummary, serverSummary.count > 0 {
            return serverSummary
        }
        guard nextCursor == nil, !reviews.isEmpty else { return nil }
        return UAPPReviewSummary(reviews: reviews)
    }

    private func unique(_ items: [UAPPReview]) -> [UAPPReview] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }
}
#endif
