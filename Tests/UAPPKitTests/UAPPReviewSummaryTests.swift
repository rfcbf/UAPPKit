import SwiftUI
import Testing
@testable import UAPPKit

@Test("Resumo das avaliações usa o do servidor quando ele vem na página")
@MainActor
func reviewSummaryPrefersServerValues() async {
    let client = makeClient(recorder: RequestRecorder()) { _ in
        response(
            #"{"reviews":[{"id":"1","rating":5}],"nextCursor":"next","#
                + #""summary":{"count":40,"average":4.5,"distribution":{"5":30,"4":10}}}"#
        )
    }
    let model = UAPPReviewsModel(client: client)
    await model.loadIfNeeded()

    #expect(model.summary == UAPPReviewSummary(count: 40, average: 4.5, distribution: ["5": 30, "4": 10]))
    #expect(model.summary?.share(of: 5) == 0.75)
    #expect(model.summary?.share(of: 1) == 0)
}

@Test("Resumo das avaliações é calculado só quando todas as páginas foram carregadas")
@MainActor
func reviewSummaryIsComputedWhenListIsComplete() async {
    let client = makeClient(recorder: RequestRecorder()) { request in
        if queryValue("cursor", in: request) == "next" {
            return response(#"{"reviews":[{"id":"2","rating":2},{"id":"3","rating":9}],"nextCursor":null}"#)
        }
        return response(#"{"reviews":[{"id":"1","rating":5}],"nextCursor":"next"}"#)
    }
    let model = UAPPReviewsModel(client: client)
    await model.loadIfNeeded()
    #expect(model.summary == nil)

    await model.loadMore()
    let summary = model.summary
    #expect(summary?.count == 3)
    #expect(summary?.distribution == ["5": 2, "2": 1])
    #expect(summary?.average == 16.0 / 3)
}

@Test("Resumo vazio não tem média nem participação")
func reviewSummaryHandlesEmptyLists() {
    let summary = UAPPReviewSummary(reviews: [])
    #expect(summary.count == 0 && summary.average == 0)
    #expect(summary.share(of: 5) == 0)
}

@Test("Cartão de resumo mostra estrelas cheias, meias e vazias")
@MainActor
func reviewSummaryCardRenders() async {
    #expect(UAPPReviewSummaryCard.starSymbol(1, average: 4.5) == "star.fill")
    #expect(UAPPReviewSummaryCard.starSymbol(5, average: 4.5) == "star.leadinghalf.filled")
    #expect(UAPPReviewSummaryCard.starSymbol(5, average: 3.9) == "star")
    await render(UAPPReviewSummaryCard(
        summary: UAPPReviewSummary(count: 12, average: 4.3, distribution: ["5": 8, "4": 2, "1": 2]),
        palette: UAPPTheme.system.resolved(for: .light)
    ))

    let reviews = [
        UAPPReview(id: "1", rating: 5, title: "Ótimo", body: nil, reviewerName: nil, reviewedAt: nil),
        UAPPReview(id: "2", rating: 3, title: nil, body: "Bom", reviewerName: nil, reviewedAt: nil)
    ]
    let client = makeClient(recorder: RequestRecorder()) { _ in response(#"{"reviews":[]}"#) }
    await render(UAPPReviewsScreen(client: client, testingReviews: reviews, isLoading: false))
}

@Test("Ícone de rede social usa a marca do pacote ou o símbolo de link")
@MainActor
func socialNetworkIconResolvesAssets() async {
    for network in ["youtube", "X", "instagram", "tiktok", "LinkedIn", "facebook"] {
        #expect(UAPPSocialNetworkIcon.assetName(for: network) != nil)
        await render(UAPPSocialNetworkIcon(network))
    }
    #expect(UAPPSocialNetworkIcon.assetName(for: "mastodon") == nil)
    await render(UAPPSocialNetworkIcon("mastodon"))
}

@Test("Biografia do desenvolvedor aplica a formatação Markdown")
@MainActor
func developerBioRendersMarkdown() async {
    let formatted = uappChangelogMarkdown("**Aurora** cria apps\n- simples")
    #expect(String(formatted.characters) == "Aurora cria apps\n• simples")
    await render(UAPPAboutBio(
        text: "**Aurora** cria apps",
        defaultLanguageIdentifier: "pt-BR",
        translations: [:],
        targetIdentifier: "pt-BR"
    ))
}
