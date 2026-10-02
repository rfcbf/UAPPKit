import SwiftUI
import Testing
@testable import UAPPKit

private let roadmapItem = UAPPFeedbackItem(
    id: "item", title: "Modo escuro", body: "Descrição",
    voteCount: 4, likeCount: 0, commentCount: 1, category: .feature, statusId: "planned"
)

private let roadmapColumns = [
    UAPPRoadmapColumn(
        status: .init(id: "planned", key: "planned", name: "Planejado", position: 0),
        items: [roadmapItem]
    ),
    UAPPRoadmapColumn(
        status: .init(id: "done", key: "done", name: "Concluído", position: 1),
        items: []
    )
]

@Test("UAPPRoadmapScreen constrói carregamento e conteúdo")
@MainActor
func roadmapScreenBuildsStates() async {
    let client = makeClient { _ in response(#"{"statuses":[],"items":[]}"#) }
    await renderInNavigationStack(UAPPRoadmapScreen(client: client))
    await renderInNavigationStack(UAPPRoadmapScreen(client: client, testingIsLoading: true))
    await renderInNavigationStack(UAPPRoadmapScreen(client: client, testingIsLoading: false, columns: roadmapColumns))
    await renderInNavigationStack(UAPPRoadmapScreen(client: client, testingIsLoading: false, columns: []))
}

@Test("UAPPRoadmapScreen renderiza busca por item, por status e sem resultados")
@MainActor
func roadmapScreenRendersSearch() async {
    let client = makeClient { _ in response(#"{"statuses":[],"items":[]}"#) }
    for query in ["modo", "concluido", "ausente"] {
        await renderInNavigationStack(UAPPRoadmapScreen(
            client: client, testingIsLoading: false, columns: roadmapColumns, testingQuery: query
        ))
    }
}

@Test("UAPPRoadmapScreen renderiza erros")
@MainActor
func roadmapScreenRendersErrors() async {
    let forbidden = makeClient { _ in throw UAPPKitError.http(status: 403, message: "Bloqueado") }
    let offline = makeClient { _ in throw UAPPKitError.transport("offline") }
    await renderInNavigationStack(UAPPRoadmapScreen(client: forbidden))
    await renderInNavigationStack(UAPPRoadmapScreen(client: offline))
    await renderInNavigationStack(UAPPRoadmapScreen(
        client: offline, testingIsLoading: false,
        errorMessage: "unavailable.load_error", errorMascotState: .connectionError
    ))
}

@Test("modo roadmap do UAPPFeedbackScreen continua disponível")
@MainActor
func feedbackScreenRoadmapModeDelegates() async {
    let client = makeClient { _ in response(#"{"statuses":[],"items":[]}"#) }
    await renderInNavigationStack(UAPPFeedbackScreen(client: client, mode: .roadmap))
}

@Test("falha de carga diferencia projeto indisponível, erro inicial e atualização silenciosa")
func feedbackLoadFailureClassification() {
    let forbidden = UAPPFeedbackLoadFailure.make(
        for: UAPPKitError.http(status: 403, message: nil), silently: true, hasContent: true
    )
    #expect(forbidden == .init(messageKey: "unavailable.content", mascotState: .unavailable, clearsContent: true))

    let initial = UAPPFeedbackLoadFailure.make(
        for: UAPPKitError.transport("offline"), silently: false, hasContent: true
    )
    #expect(initial == .init(messageKey: "unavailable.load_error", mascotState: .connectionError, clearsContent: false))

    let silentWithoutContent = UAPPFeedbackLoadFailure.make(
        for: UAPPKitError.transport("offline"), silently: true, hasContent: false
    )
    #expect(silentWithoutContent?.messageKey == "unavailable.load_error")

    #expect(UAPPFeedbackLoadFailure.make(
        for: UAPPKitError.transport("offline"), silently: true, hasContent: true
    ) == nil)
}
