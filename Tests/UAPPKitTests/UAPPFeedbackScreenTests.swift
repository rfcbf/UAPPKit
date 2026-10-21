import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@Test("modos de tela expõem títulos corretos")
func feedbackScreenModesHaveTitles() {
    #expect(UAPPScreenMode.feedback.titleKey == "screen.feedback")
    #expect(UAPPScreenMode.roadmap.titleKey == "screen.roadmap")
    #expect(UAPPScreenMode.changelog.titleKey == "screen.changelog")
}

@Test("UAPPFeedbackScreen constrói os três modos")
@MainActor
func feedbackScreenBuildsModes() async {
    let client = makeClient { _ in response(#"{"ok":true,"items":[]}"#) }
    await renderInNavigationStack(UAPPFeedbackScreen(client: client, mode: .feedback))
    await renderInNavigationStack(UAPPFeedbackScreen(client: client, mode: .roadmap))
    await renderInNavigationStack(UAPPFeedbackScreen(client: client, mode: .changelog))
}

@Test("UAPPFeedbackScreen constrói estados e conteúdos carregados")
@MainActor
func feedbackScreenBuildsLoadedStates() async {
    let client = makeClient { _ in response(#"{"ok":true,"items":[]}"#) }
    let item = UAPPFeedbackItem(
        id: "item",
        title: "Modo escuro",
        body: "Descrição",
        voteCount: 4,
        likeCount: 2,
        commentCount: 1,
        category: .feature,
        priority: 5
    )
    let roadmap = UAPPRoadmapColumn(
        status: .init(id: "todo", key: "todo", name: "A fazer", position: 1),
        items: [item]
    )
    let changelog = UAPPChangelogEntry(
        title: "Versão 1.0",
        slug: "1-0",
        bodyMarkdown: "**Novidades**",
        version: "1.0",
        build: "10",
        platform: .ios,
        sections: [.init(category: .new, bodyMarkdown: "Item novo", position: 1)],
        releasedAt: "2026-09-24"
    )

    await renderInNavigationStack(UAPPFeedbackScreen(
        client: client,
        mode: .feedback,
        testingIsLoading: false,
        feedback: [item]
    ))
    await renderInNavigationStack(UAPPRoadmapScreen(
        client: client,
        testingIsLoading: false,
        columns: [roadmap]
    ))
    await renderInNavigationStack(UAPPFeedbackScreen(
        client: client,
        mode: .changelog,
        testingIsLoading: false,
        changelog: [changelog],
        changelogNextCursor: "previous",
        changelogLoadMoreError: "Falha ao carregar"
    ))
    await renderInNavigationStack(UAPPFeedbackScreen(
        client: client,
        mode: .feedback,
        testingIsLoading: false,
        errorMessage: "Conteúdo indisponível",
        errorMascotState: .unavailable
    ))
    await renderInNavigationStack(UAPPFeedbackScreen(
        client: client,
        mode: .changelog,
        testingIsLoading: false
    ))
}

@Test("UAPPFeedbackScreen trata erros HTTP e de transporte")
@MainActor
func feedbackScreenRendersErrorStates() async {
    let forbiddenClient = makeClient { _ in
        throw UAPPKitError.http(status: 403, message: "Bloqueado")
    }
    let transportClient = makeClient { _ in
        throw UAPPKitError.transport("offline")
    }

    await renderInNavigationStack(UAPPFeedbackScreen(client: forbiddenClient, mode: .feedback))
    await renderInNavigationStack(UAPPFeedbackScreen(client: transportClient, mode: .roadmap))
}

@Test("UAPPSubmitFeedbackScreen renderiza o formulário localizado")
@MainActor
func submitFeedbackScreenRendersForm() async {
    let client = makeClient { _ in response(#"{"id":"feedback"}"#) }
    await render(UAPPSubmitFeedbackScreen(client: client, onComplete: {}))
}

@Test("UAPPFeedbackComposerScreen abre o compositor com o rascunho informado")
@MainActor
func feedbackComposerScreenRendersPrefilledDraft() async {
    let client = makeClient { _ in response(#"{"id":"feedback"}"#) }
    let draft = UAPPFeedbackDraft(title: "Falha ao importar", details: "Parou no terceiro mês.", category: .bug)

    #expect(UAPPFeedbackDraft() == UAPPFeedbackDraft(title: "", details: "", category: .feature))
    #expect(draft.category == .bug)
    await render(UAPPFeedbackComposerScreen(client: client, draft: draft, onComplete: {}))
    await render(UAPPSubmitFeedbackScreen(client: client, draft: draft, onComplete: {}))
}

@Test("compositor de feedback tem símbolo e título distintos para cada tipo")
func submitFeedbackCategoriesHaveDistinctPresentation() {
    let categories = UAPPFeedbackCategory.allCases
    #expect(Set(categories.map(\.composerSymbol)).count == categories.count)
    #expect(categories.map(\.composerTitleKey) == [
        "category.bug", "category.feature", "category.improvement", "category.question"
    ])
}

@Test("textos do compositor de feedback estão traduzidos", arguments: UAPPLanguage.supported)
func submitFeedbackComposerStringsAreTranslated(language: UAPPLanguage) {
    let keys = [
        "feedback.compose.intro", "feedback.compose.title_placeholder", "feedback.compose.title_hint",
        "feedback.compose.description_placeholder", "feedback.compose.attachments",
        "feedback.compose.attachments_hint", "feedback.compose.optional"
    ]
    for key in keys {
        #expect(uappLocalized(key, languageIdentifier: language.identifier) != key)
    }
}

@Test("Feedback e Roadmap renderizam busca sem resultados")
@MainActor
func feedbackAndRoadmapRenderSearchResults() async {
    let client = makeClient { _ in response(#"{"items":[]}"#) }
    let item = UAPPFeedbackItem(id: "1", title: "Notificações", body: nil, voteCount: 0, likeCount: 0, commentCount: 0)
    let column = UAPPRoadmapColumn(status: .init(id: "1", key: "planned", name: "Planejado", position: 0), items: [item])
    for query in ["notificacoes", "ausente"] {
        await renderInNavigationStack(UAPPFeedbackScreen(
            client: client, mode: .feedback, testingIsLoading: false, feedback: [item], testingQuery: query
        ))
        await renderInNavigationStack(UAPPRoadmapScreen(
            client: client, testingIsLoading: false, columns: [column], testingQuery: query
        ))
    }
}

#if canImport(UIKit) || canImport(AppKit)
@Test("UAPPFeedbackScreen renderiza feedback, roadmap e changelog")
@MainActor
func feedbackScreenRendersLoadedContentInHost() async {
    let client = makeClient { _ in response(#"{"ok":true,"items":[]}"#) }
    let item = UAPPFeedbackItem(
        id: "item",
        title: "Modo escuro",
        body: "Descrição",
        voteCount: 4,
        likeCount: 2,
        commentCount: 1
    )
    let column = UAPPRoadmapColumn(
        status: .init(id: "todo", key: "todo", name: "A fazer", position: 1),
        items: [item]
    )
    let entry = UAPPChangelogEntry(
        title: "Versão 1.0",
        slug: "1-0",
        bodyMarkdown: "**Novidades**",
        version: "1.0",
        build: "10",
        platform: .ios,
        sections: [.init(category: .new, bodyMarkdown: "Item novo", position: 1)],
        releasedAt: "2026-09-24"
    )

    await renderInNavigationStack(UAPPFeedbackScreen(
        client: client,
        mode: .feedback,
        testingIsLoading: false,
        feedback: [item]
    ))
    await renderInNavigationStack(UAPPRoadmapScreen(
        client: client,
        testingIsLoading: false,
        columns: [column]
    ))
    await renderInNavigationStack(UAPPFeedbackScreen(
        client: client,
        mode: .changelog,
        testingIsLoading: false,
        changelog: [entry],
        changelogNextCursor: "previous",
        changelogLoadMoreError: "Falha"
    ))
}
#endif
