import SwiftUI
import Testing
@testable import UAPPKit

@Test("feedback decodifica as etiquetas aplicadas com e sem cor")
func feedbackItemDecodesTags() throws {
    let item = try JSONDecoder().decode(UAPPFeedbackItem.self, from: json("""
    {"id":"1","title":"Ideia","body":null,"vote_count":0,"like_count":0,
     "public_comment_count":0,"priority":3,"viewer_voted":false,"viewer_liked":false,
     "tags":[{"id":"t1","name":"Relatórios","color":"#2F80ED"},
             {"id":"t2","name":"Exportação","color":null},
             {"id":"t3","name":"Sem campo de cor"}]}
    """))
    #expect(item.priority == 3)
    #expect(item.tags == [
        UAPPFeedbackTag(id: "t1", name: "Relatórios", color: "#2F80ED"),
        UAPPFeedbackTag(id: "t2", name: "Exportação"),
        UAPPFeedbackTag(id: "t3", name: "Sem campo de cor")
    ])
    #expect(item.tags.map(\.id) == ["t1", "t2", "t3"])
    let encoded = try JSONEncoder().encode(item)
    #expect(try JSONDecoder().decode(UAPPFeedbackItem.self, from: encoded) == item)
}

@Test("servidor antigo sem etiquetas resulta em lista vazia")
func feedbackItemWithoutTagsDecodesEmptyList() throws {
    let missing = try JSONDecoder().decode(UAPPFeedbackItem.self, from: json("""
    {"id":"1","title":"Ideia","vote_count":0,"like_count":0,"public_comment_count":0,
     "priority":0,"viewer_voted":false,"viewer_liked":false}
    """))
    let null = try JSONDecoder().decode(UAPPFeedbackItem.self, from: json("""
    {"id":"1","title":"Ideia","vote_count":0,"like_count":0,"public_comment_count":0,
     "priority":0,"viewer_voted":false,"viewer_liked":false,"tags":null}
    """))
    #expect(missing.tags.isEmpty)
    #expect(null.tags.isEmpty)
    #expect(missing == UAPPFeedbackItem(id: "1", title: "Ideia", body: nil, voteCount: 0, likeCount: 0, commentCount: 0))
}

@Test("etiqueta inválida ou campo obrigatório ausente falham na decodificação")
func feedbackItemRejectsInvalidTags() {
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(UAPPFeedbackItem.self, from: json("""
        {"id":"1","title":"Ideia","vote_count":0,"like_count":0,"public_comment_count":0,
         "priority":0,"viewer_voted":false,"viewer_liked":false,"tags":[{"id":"t1"}]}
        """))
    }
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(UAPPFeedbackItem.self, from: json("""
        {"id":"1","title":"Ideia","vote_count":0,"like_count":0,"public_comment_count":0,
         "viewer_voted":false,"viewer_liked":false}
        """))
    }
}

@Test("votar preserva prioridade e etiquetas do card")
func feedbackVotePreservesTags() {
    let tags = [UAPPFeedbackTag(id: "t1", name: "Relatórios", color: "#2F80ED")]
    let item = UAPPFeedbackItem(
        id: "1", title: "Ideia", body: nil, voteCount: 1, likeCount: 0, commentCount: 0,
        priority: 4, tags: tags
    )
    #expect(item.settingVote(enabled: true).tags == tags)
    #expect(item.settingVote(enabled: true).priority == 4)
    #expect(item.settingLike(enabled: true).tags == tags)
}

@Test("roadmap e lista de feedback carregam as etiquetas do servidor")
func clientCarriesTags() async throws {
    let client = makeClient { request in
        if request.url?.absoluteString.contains("roadmap") == true {
            return response("""
            {"statuses":[{"id":"planned","key":"planned","name":"Planejado","position":1}],
             "items":[{"id":"1","title":"Ideia","body":null,"status_id":"planned",
              "vote_count":0,"like_count":0,"public_comment_count":0,"priority":2,
              "viewer_voted":false,"viewer_liked":false,
              "tags":[{"id":"t1","name":"Relatórios","color":"#2F80ED"}]},
              {"id":"2","title":"Antigo","body":null,"status_id":"planned",
              "vote_count":0,"like_count":0,"public_comment_count":0,"priority":0,
              "viewer_voted":false,"viewer_liked":false}]}
            """)
        }
        return response("""
        {"items":[{"id":"1","title":"Ideia","vote_count":0,"like_count":0,
          "public_comment_count":0,"priority":2,"viewer_voted":false,"viewer_liked":false,
          "tags":[{"id":"t1","name":"Relatórios"}]}],"nextCursor":null}
        """)
    }
    let roadmapItems = try #require(try await client.roadmap().first?.items)
    #expect(roadmapItems.first?.tags == [UAPPFeedbackTag(id: "t1", name: "Relatórios", color: "#2F80ED")])
    #expect(roadmapItems.first?.priority == 2)
    #expect(roadmapItems.last?.tags.isEmpty == true)
    let page = try await client.feedbackPage()
    #expect(page.items.first?.tags == [UAPPFeedbackTag(id: "t1", name: "Relatórios")])
}

@Test("cor da etiqueta aceita hexadecimal longo, curto e com espaços")
func feedbackTagParsesHexColors() throws {
    let blue = try #require(UAPPFeedbackTag.rgbComponents(hex: "#2F80ED"))
    #expect(abs(blue.red - 47.0 / 255) < 0.0001)
    #expect(abs(blue.green - 128.0 / 255) < 0.0001)
    #expect(abs(blue.blue - 237.0 / 255) < 0.0001)

    let lowercase = try #require(UAPPFeedbackTag.rgbComponents(hex: " 2f80ed\n"))
    #expect(lowercase.red == blue.red && lowercase.green == blue.green && lowercase.blue == blue.blue)

    let short = try #require(UAPPFeedbackTag.rgbComponents(hex: "#F0A"))
    #expect(short.red == 1 && short.green == 0 && abs(short.blue - 170.0 / 255) < 0.0001)

    let black = try #require(UAPPFeedbackTag.rgbComponents(hex: "#000000"))
    #expect(black.red == 0 && black.green == 0 && black.blue == 0)
}

@Test("cor ausente ou inválida usa a cor neutra do tema")
@MainActor
func feedbackTagRejectsInvalidColors() {
    for value in [nil, "", "#", "azul", "#12345", "#1234567", "#GGGGGG", "+2F80ED", "#2F 0ED", "0x2F80"] {
        #expect(UAPPFeedbackTag.rgbComponents(hex: value) == nil, "\(value ?? "nil")")
    }
    let fallback = Color.gray
    #expect(UAPPFeedbackTag(id: "1", name: "Sem cor").displayColor(fallback: fallback) == fallback)
    #expect(UAPPFeedbackTag(id: "1", name: "Inválida", color: "azul").displayColor(fallback: fallback) == fallback)
    #expect(UAPPFeedbackTag(id: "1", name: "Azul", color: "#2F80ED").displayColor(fallback: fallback) != fallback)
}

@Test("rótulos de acessibilidade de etiqueta e prioridade existem em todos os idiomas")
@MainActor
func feedbackTagAccessibilityLabelsAreLocalized() {
    let tag = UAPPFeedbackTag(id: "1", name: "Relatórios")
    for language in UAPPLanguage.supported.map(\.identifier) {
        let tagLabel = UAPPFeedbackTagList.tagAccessibilityLabel(tag, languageIdentifier: language)
        let priorityLabel = UAPPFeedbackTagList.priorityAccessibilityLabel(.urgent, languageIdentifier: language)
        #expect(tagLabel.contains("Relatórios") && !tagLabel.contains("feedback.tag_accessibility"), "\(language)")
        #expect(
            priorityLabel.contains(UAPPFeedbackPriority.urgent.title(languageIdentifier: language))
                && !priorityLabel.contains("feedback.priority_accessibility"),
            "\(language)"
        )
    }
    #expect(UAPPFeedbackTagList.tagAccessibilityLabel(tag, languageIdentifier: "pt-BR") == "Etiqueta: Relatórios")
    #expect(UAPPFeedbackTagList.priorityAccessibilityLabel(.high, languageIdentifier: "en") == "Priority: High")
}

@Test("lista de etiquetas ignora nomes vazios")
@MainActor
func feedbackTagListSkipsBlankNames() {
    let list = UAPPFeedbackTagList(
        tags: [.init(id: "1", name: "  "), .init(id: "2", name: "Relatórios")],
        languageIdentifier: "pt-BR"
    )
    #expect(list.tags.map(\.id) == ["2"])
}

@Test("etiquetas e prioridade renderizam no card, no detalhe e na lista")
@MainActor
func feedbackTagsRender() async {
    let tags = (1 ... 8).map {
        UAPPFeedbackTag(id: "\($0)", name: "Etiqueta com nome longo \($0)", color: $0.isMultiple(of: 2) ? "#F2C94C" : nil)
    }
    let item = UAPPFeedbackItem(
        id: "1", title: "Exportar", body: "Corpo", voteCount: 1, likeCount: 0, commentCount: 0,
        category: .feature, priority: 6, tags: tags
    )
    let status = UAPPRoadmapColumn.Status(id: "planned", key: "planned", name: "Planejado", position: 1)
    for layout in [UAPPFeedbackCard.Layout.feedback, .roadmap] {
        await render(UAPPFeedbackCard(
            item: item, status: status, accentColor: .blue, layout: layout,
            onReact: {}, onProfile: {}, onDetail: {}
        ))
    }
    await render(UAPPFeedbackTagList(tags: tags, priority: .urgent, languageIdentifier: "pt-BR"))
    await render(UAPPFeedbackTagList(tags: [], languageIdentifier: "pt-BR"))
    await render(UAPPFeedbackTagList(tags: tags, languageIdentifier: "ja").frame(width: 120))
    await render(UAPPFeedbackTagList(tags: tags, languageIdentifier: "pt-BR").environment(\.colorScheme, .dark))
    let client = makeClient { _ in response(#"{"ok":true,"comments":[]}"#) }
    await renderInNavigationStack(UAPPFeedbackDetailScreen(
        client: client, item: item, testingComments: [], isLoading: false
    ))
}
