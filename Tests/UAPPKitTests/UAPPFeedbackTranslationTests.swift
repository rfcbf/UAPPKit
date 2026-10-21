import Testing
@_spi(UAPPInternal) @testable import UAPPKit

#if canImport(SwiftUI)
@Test("resumo de feedback preserva quebras de linha e sinaliza conteúdo oculto")
func feedbackDescriptionKeepsFormatting() {
    let complete = "Primeira linha\n\n  1) Segunda parte 😁"
    #expect(uappFeedbackDescriptionPreview(complete, maximumLines: 3) == complete)
    #expect(uappFeedbackDescriptionPreview("Assadas\nAssacadas\n\nTexto oculto", maximumLines: 3) ==
        "Assadas\nAssacadas…")
    #expect(uappFeedbackDescriptionPreview("Título\n\n1) Item\n2) Outro", maximumLines: 3) ==
        "Título\n\n1) Item…")
    #expect(uappFeedbackDescriptionPreview("Um\r\nDois\r\nTrês\r\nQuatro", maximumLines: 3) ==
        "Um\nDois\nTrês…")
}

@Test("status padrão do feedback são localizados em todos os idiomas", arguments: UAPPLanguage.supported)
func feedbackStatusTranslations(_ language: UAPPLanguage) {
    for key in ["new", "reviewing", "planned", "in_progress", "in_test", "shipped", "delivered"] {
        let localized = uappLocalized("status.\(key)", languageIdentifier: language.identifier)
        #expect(localized != "status.\(key)")
        let status = UAPPRoadmapColumn.Status(id: key, key: key, name: "Server label", position: 0)
        #expect(uappFeedbackStatusTitle(status, languageIdentifier: language.identifier) == localized)
    }
}

@Test("status concluído legado e status opcionais mantêm apresentação compatível")
func feedbackStatusFallbacks() {
    let done = UAPPRoadmapColumn.Status(id: "1", key: "done", name: "Concluído", position: 0)
    #expect(uappFeedbackStatusTitle(done, languageIdentifier: "en") == "Completed")
    let custom = UAPPRoadmapColumn.Status(id: "2", key: "custom", name: "Custom stage", position: 0)
    #expect(uappFeedbackStatusTitle(custom, languageIdentifier: "en") == "Custom stage")
    #expect(uappFeedbackStatusTitle(nil, languageIdentifier: "en") ==
        uappLocalized("feedback.status.none", languageIdentifier: "en"))
}
#endif
