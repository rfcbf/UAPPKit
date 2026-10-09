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
    /// Resumo calculado em uma leitura à parte, quando a lista tem mais de uma página.
    @Published private(set) var computedSummary: UAPPReviewSummary?
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

    /// Maior página aceita pela API, usada para ler todas as notas de uma vez.
    static let summaryPageSize = 50

    /// Sem resumo do servidor e com mais páginas por vir, lê as notas em uma página grande.
    /// Só vale quando essa página traz todas as avaliações; acima disso o total não é confiável.
    /// A tela chama depois da primeira página; não altera a lista nem a paginação.
    func loadSummaryIfNeeded() async {
        guard computedSummary == nil, (serverSummary?.count ?? 0) == 0, nextCursor != nil,
              pageSize < Self.summaryPageSize
        else {
            return
        }
        guard let page = try? await client.reviewsPage(limit: Self.summaryPageSize) else { return }
        if let summary = page.summary, summary.count > 0 {
            serverSummary = summary
        } else if page.nextCursor == nil, !page.reviews.isEmpty {
            computedSummary = UAPPReviewSummary(reviews: unique(page.reviews))
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

    /// Resumo das notas: o do servidor ou o calculado com todas as avaliações do aplicativo.
    /// Com mais avaliações do que cabe em uma página grande e sem resumo do servidor, não há total
    /// confiável para mostrar.
    var summary: UAPPReviewSummary? {
        if let serverSummary, serverSummary.count > 0 {
            return serverSummary
        }
        guard nextCursor == nil, !reviews.isEmpty else { return computedSummary }
        return UAPPReviewSummary(reviews: reviews)
    }

    private func unique(_ items: [UAPPReview]) -> [UAPPReview] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }
}
#endif
