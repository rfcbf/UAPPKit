import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@Test("Prioridade segue o valor do servidor e ignora requisições sem prioridade")
func feedbackPriorityMapsServerValues() {
    #expect(UAPPFeedbackPriority(value: 0) == nil)
    #expect(UAPPFeedbackPriority(value: -4) == nil)
    #expect(UAPPFeedbackPriority(value: 1) == .low)
    #expect(UAPPFeedbackPriority(value: 4) == .veryHigh)
    #expect(UAPPFeedbackPriority(value: 6) == .urgent)
    // Valores da escala antiga, acima do último nível, contam como o mais alto.
    #expect(UAPPFeedbackPriority(value: 80) == .urgent)
    #expect(UAPPFeedbackPriority.low < .urgent)
    #expect(UAPPFeedbackPriority.allCases.sorted() == UAPPFeedbackPriority.allCases)
}

@Test("Prioridade tem nome em todos os idiomas, símbolo e cor próprios")
func feedbackPriorityHasLocalizedTitles() {
    for priority in UAPPFeedbackPriority.allCases {
        for language in UAPPLanguage.supported.map(\.identifier) {
            let title = priority.title(languageIdentifier: language)
            #expect(!title.isEmpty && title != priority.localizationKey)
        }
        #expect(!priority.symbol.isEmpty)
    }
    #expect(UAPPFeedbackPriority.urgent.title(languageIdentifier: "pt-BR") == "Urgente")
    #expect(UAPPFeedbackPriority.veryHigh.title(languageIdentifier: "en") == "Very high")
    #expect(Set(UAPPFeedbackPriority.allCases.map(\.symbol)).count == 6)
    #expect(Set(UAPPFeedbackPriority.allCases.map(\.color)).count == 6)
}

@Test("Selo de prioridade monta em todos os níveis")
@MainActor
func feedbackPriorityBadgeRenders() async {
    for priority in UAPPFeedbackPriority.allCases {
        await render(UAPPFeedbackPriorityBadge(priority: priority, languageIdentifier: "pt-BR"))
    }
    await render(UAPPFeedbackPriorityBadge(priority: .high))
}
