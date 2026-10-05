import SwiftUI
import Testing
@testable import UAPPKit

@MainActor
@Test("UAPPFeedbackCard renderiza os layouts de Feedback e Roadmap")
func feedbackCardRendersBothLayouts() async {
    let status = UAPPRoadmapColumn.Status(id: "planned", key: "planned", name: "Planejado", position: 1)
    let categorized = UAPPFeedbackItem(
        id: "1", title: "Exportar dados", body: "Permitir exportar em CSV.",
        voteCount: 3, likeCount: 0, commentCount: 2, category: .bug, priority: 0,
        viewerVoted: true, authorName: "Ana"
    )
    let uncategorized = UAPPFeedbackItem(
        id: "2", title: "Sem tipo", body: nil,
        voteCount: 0, likeCount: 0, commentCount: 0, category: nil, priority: 0
    )

    for layout in [UAPPFeedbackCard.Layout.feedback, .roadmap] {
        for item in [categorized, uncategorized] {
            await render(UAPPFeedbackCard(
                item: item, status: status, accentColor: .blue, layout: layout,
                onReact: {}, onProfile: {}, onDetail: {}
            ))
        }
    }
}

@MainActor
@Test("badge de tipo usa ícone próprio por categoria e renderiza sem tipo")
func feedbackCategoryBadgeSymbols() async {
    let categories: [UAPPFeedbackCategory?] = UAPPFeedbackCategory.allCases.map(\.self) + [nil]
    let symbols = Set(categories.map(UAPPFeedbackCategoryBadge.symbol(for:)))
    #expect(symbols.count == categories.count)
    #expect(UAPPFeedbackCategoryBadge.symbol(for: .bug) == "ladybug.fill")
    #expect(UAPPFeedbackCategoryBadge.symbol(for: nil) == "tag")
    for category in categories {
        await render(UAPPFeedbackCategoryBadge(category: category, languageIdentifier: "pt-BR"))
    }
}
