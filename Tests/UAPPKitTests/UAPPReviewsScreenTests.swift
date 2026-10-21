import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@Test("Reviews mostra skeleton enquanto aguarda tradução")
@MainActor
func reviewsRendersTranslationSkeleton() async {
    let model = UAPPReviewTextModel(original: "Original text")
    await model.translate { _ in
        #expect(model.isTranslating)
        await render(UAPPReviewTranslationContent(text: model.original, targetIdentifier: "en", model: model))
        return "Translated text"
    }
    #expect(!model.isTranslating)
    #expect(model.displayText == "Translated text")
}

@Test("Reviews mantém loading no rodapé durante próxima página e retry", arguments: [false, true])
@MainActor
func reviewsRendersLoadingFooter(retry: Bool) async {
    let gate = RequestGate()
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { request in
        guard queryValue("cursor", in: request) != nil else {
            return response(#"{"reviews":[{"id":"1","rating":5}],"nextCursor":"next"}"#)
        }
        if retry, recorder.requests.count == 2 {
            throw TestError.expected
        }
        await gate.suspend()
        return response(#"{"reviews":[{"id":"2","rating":4}],"nextCursor":null}"#)
    }
    let model = UAPPReviewsModel(client: client)
    await model.loadIfNeeded()
    if retry {
        await model.loadMore()
        #expect(model.hasMoreError)
    }
    let task = Task { await model.loadMore() }
    await gate.waitUntilStarted()
    #expect(model.isLoadingMore)
    #expect(model.reviews.count == 1)
    await render(UAPPReviewsScreen(model: model))
    await gate.resume()
    await task.value
    #expect(!model.isLoadingMore)
    #expect(!model.hasMoreError)
    #expect(model.reviews.count == 2)
}

@Test("UAPPReviewsScreen constrói a view inicial")
@MainActor
func reviewsScreenBuildsInitialView() async {
    let client = makeClient { _ in response(#"{"ok":true,"reviews":[]}"#) }
    await render(UAPPReviewsScreen(client: client, pageSize: 20))
}

@Test("UAPPReviewsScreen constrói estados vazio, erro e conteúdo carregado")
@MainActor
func reviewsScreenBuildsAllStates() async {
    let client = makeClient { _ in response(#"{"ok":true,"reviews":[]}"#) }
    let review = UAPPReview(
        id: "review",
        rating: 4,
        title: "Ótimo",
        body: "Muito bom",
        reviewerName: "Ana",
        reviewedAt: Date()
    )

    await render(UAPPReviewsScreen(client: client, testingReviews: [], isLoading: false))
    await render(UAPPReviewsScreen(client: client, testingReviews: [], isLoading: false, hasError: true))
    let reviewWithResponse = UAPPReview(
        id: "response-review",
        rating: 2,
        title: "Avaliação com resposta",
        body: "Este é um texto mais longo para verificar a altura variável da avaliação.",
        reviewerName: "João",
        reviewedAt: nil,
        responseBody: "Obrigado pela avaliação!"
    )
    await render(UAPPReviewsScreen(client: client, testingReviews: [reviewWithResponse, review], isLoading: false))
}

#if canImport(UIKit) || canImport(AppKit)
@Test("Reviews renderiza próxima página e mantém retry visível após erro")
@MainActor
func reviewsScreenRendersPaginationStates() async {
    let client = makeClient { request in
        if queryValue("cursor", in: request) != nil {
            throw TestError.expected
        }
        return response(#"{"reviews":[{"id":"1","rating":5}],"nextCursor":"next"}"#)
    }
    let model = UAPPReviewsModel(client: client)
    await model.loadIfNeeded()
    await render(UAPPReviewsScreen(model: model))
    await model.loadMore()
    #expect(model.hasMoreError)
    await render(UAPPReviewsScreen(model: model))
    #expect(model.reviews.count == 1)
}

@Test("Review mostra original e aviso quando tradução falha")
@MainActor
func reviewScreenRendersTranslationFailure() async {
    let original = "Este aplicativo é muito útil e fácil de usar todos os dias."
    let model = UAPPReviewTextModel(original: original)
    await model.translate { _ in throw TestError.expected }
    await render(UAPPReviewTranslationContent(text: original, targetIdentifier: "pt-BR", model: model))
    #expect(model.hasError)
    #expect(model.displayText == original)
}

@Test("Card de review renderiza resposta expandida e dados opcionais")
@MainActor
func reviewCardRendersResponse() async {
    let palette = UAPPTheme().resolved(for: .light)
    let review = UAPPReview(id: "response", rating: 5, title: "Ótimo aplicativo", body: "Este aplicativo é muito bom e fácil de usar.", reviewerName: "Ana", reviewedAt: Date(), responseBody: "Obrigado por compartilhar sua avaliação do aplicativo!")
    await render(UAPPReviewCard(review: review, targetIdentifier: "pt-BR", palette: palette, showsResponse: true))
    await render(UAPPReviewCard(review: review, targetIdentifier: "pt-BR", palette: palette))
    let minimal = UAPPReview(id: "minimal", rating: 1, title: nil, body: nil, reviewerName: nil, reviewedAt: nil, responseBody: " ")
    await render(UAPPReviewCard(review: minimal, targetIdentifier: "pt-BR", palette: palette))
}

@Test("UAPPReviewsScreen renderiza avaliações no host SwiftUI")
@MainActor
func reviewsScreenRendersLoadedContentInHost() async {
    let client = makeClient { _ in response(#"{"ok":true,"reviews":[]}"#) }
    let review = UAPPReview(
        id: "review",
        rating: 4,
        title: "Ótimo",
        body: "Muito bom",
        reviewerName: "Ana",
        reviewedAt: Date()
    )
    await render(UAPPReviewsScreen(client: client, testingReviews: [review], isLoading: false))
}
#endif
