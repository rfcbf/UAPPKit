import SwiftUI
import Testing
@testable import UAPPKit

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
    await render(UAPPFeedbackScreen(client: client, mode: .feedback))
    await render(UAPPFeedbackScreen(client: client, mode: .roadmap))
    await render(UAPPFeedbackScreen(client: client, mode: .changelog))
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

    await render(UAPPFeedbackScreen(
        client: client,
        mode: .feedback,
        testingIsLoading: false,
        feedback: [item]
    ))
    await render(UAPPFeedbackScreen(
        client: client,
        mode: .roadmap,
        testingIsLoading: false,
        roadmap: [roadmap]
    ))
    await render(UAPPFeedbackScreen(
        client: client,
        mode: .changelog,
        testingIsLoading: false,
        changelog: [changelog],
        changelogNextCursor: "previous",
        changelogLoadMoreError: "Falha ao carregar"
    ))
    await render(UAPPFeedbackScreen(
        client: client,
        mode: .feedback,
        testingIsLoading: false,
        errorMessage: "Conteúdo indisponível",
        errorMascotState: .unavailable
    ))
    await render(UAPPFeedbackScreen(
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

    await render(UAPPFeedbackScreen(client: forbiddenClient, mode: .feedback))
    await render(UAPPFeedbackScreen(client: transportClient, mode: .roadmap))
}

@Test("UAPPSubmitFeedbackScreen renderiza o formulário localizado")
@MainActor
func submitFeedbackScreenRendersForm() async {
    let client = makeClient { _ in response(#"{"id":"feedback"}"#) }
    await render(UAPPSubmitFeedbackScreen(client: client, onComplete: {}))
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

    await render(UAPPFeedbackScreen(
        client: client,
        mode: .feedback,
        testingIsLoading: false,
        feedback: [item]
    ))
    await render(UAPPFeedbackScreen(
        client: client,
        mode: .roadmap,
        testingIsLoading: false,
        roadmap: [column]
    ))
    await render(UAPPFeedbackScreen(
        client: client,
        mode: .changelog,
        testingIsLoading: false,
        changelog: [entry],
        changelogNextCursor: "previous",
        changelogLoadMoreError: "Falha"
    ))
}
#endif
