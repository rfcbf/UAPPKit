import Foundation
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

private let searchItems = [
    UAPPFeedbackItem(id: "1", title: "Notificações", body: "Lembretes semanais", voteCount: 0, likeCount: 0, commentCount: 0),
    UAPPFeedbackItem(id: "2", title: "Tema escuro", body: nil, voteCount: 0, likeCount: 0, commentCount: 0)
]

@Test("filtros de feedback combinam busca, categoria e status")
func feedbackFiltersCombineSelections() {
    let items = [
        UAPPFeedbackItem(
            id: "1",
            title: "Tema escuro",
            body: nil,
            voteCount: 40,
            likeCount: 4,
            commentCount: 2,
            category: .feature,
            statusId: "planned"
        ),
        UAPPFeedbackItem(
            id: "2",
            title: "Erro no tema",
            body: nil,
            voteCount: 1,
            likeCount: 9,
            commentCount: 1,
            category: .bug,
            statusId: "planned"
        ),
        UAPPFeedbackItem(id: "3", title: "Tema automático", body: nil, voteCount: 90, likeCount: 1, commentCount: 0)
    ]
    #expect(UAPPFeedbackSearch.presentedItems(
        items,
        matching: "tema",
        category: .feature,
        statusId: "planned",
        sort: .votes
    ).map(\.id) == ["1"])
    #expect(UAPPFeedbackSearch.presentedItems(
        items,
        matching: "",
        category: nil,
        statusId: "unknown",
        sort: .newest
    ).isEmpty)
    #expect(UAPPFeedbackSearch.presentedItems(
        items,
        matching: "",
        category: nil,
        statusId: nil,
        sort: .votes
    ).map(\.id) == ["3", "1", "2"])
}

@Test("ordenação usa datas, votos e comentários com desempate determinístico")
func feedbackSortHandlesDatesAndTies() {
    let items = [
        UAPPFeedbackItem(
            id: "b",
            title: "B",
            body: nil,
            voteCount: 80,
            likeCount: 8,
            commentCount: 1,
            createdAt: Date(timeIntervalSince1970: 1)
        ),
        UAPPFeedbackItem(
            id: "a",
            title: "A",
            body: nil,
            voteCount: 80,
            likeCount: 8,
            commentCount: 3,
            createdAt: Date(timeIntervalSince1970: 2)
        ),
        UAPPFeedbackItem(id: "c", title: "C", body: nil, voteCount: 90, likeCount: 9, commentCount: 0)
    ]
    #expect(UAPPFeedbackSearch.presentedItems(
        items,
        matching: "",
        category: nil,
        statusId: nil,
        sort: .newest
    ).map(\.id) == ["a", "b", "c"])
    #expect(UAPPFeedbackSearch.presentedItems(
        items,
        matching: "",
        category: nil,
        statusId: nil,
        sort: .votes
    ).map(\.id) == ["c", "a", "b"])
    #expect(UAPPFeedbackSearch.presentedItems(
        items,
        matching: "",
        category: nil,
        statusId: nil,
        sort: .comments
    ).map(\.id) == ["a", "b", "c"])
    #expect(UAPPFeedbackSearch.presentedItems(
        Array(searchItems.reversed()),
        matching: "",
        category: nil,
        statusId: nil,
        sort: .newest
    ).map(\.id) == ["1", "2"])
}

@Test("busca de feedback normaliza espaços, caixa e acentos")
func feedbackSearchMatchesTitleAndBody() {
    #expect(UAPPFeedbackSearch.items(searchItems, matching: " NOTIFICACOES ").map(\.id) == ["1"])
    #expect(UAPPFeedbackSearch.items(searchItems, matching: "semanais").map(\.id) == ["1"])
    #expect(UAPPFeedbackSearch.items(searchItems, matching: "escuro").map(\.id) == ["2"])
    #expect(UAPPFeedbackSearch.items(searchItems, matching: "ausente").isEmpty)
    #expect(UAPPFeedbackSearch.items(searchItems, matching: " \n ") == searchItems)
}

@Test("busca do roadmap preserva status e filtra itens")
func roadmapSearchPreservesColumns() {
    let column = UAPPRoadmapColumn(status: .init(id: "1", key: "planned", name: "Planejado", position: 0), items: searchItems)
    let empty = UAPPRoadmapColumn(status: .init(id: "2", key: "done", name: "Concluído", position: 1), items: [])
    let columns = [column, empty]
    #expect(UAPPFeedbackSearch.columns(columns, matching: " ") == columns)
    #expect(UAPPFeedbackSearch.columns(columns, matching: "planejado") == [column])
    #expect(UAPPFeedbackSearch.columns(columns, matching: "CONCLUIDO") == [empty])
    let result = UAPPFeedbackSearch.columns(columns, matching: "escuro")
    #expect(result.first?.status == column.status)
    #expect(result.first?.items.map(\.id) == ["2"])
    #expect(UAPPFeedbackSearch.columns(columns, matching: "ausente").isEmpty)
}
