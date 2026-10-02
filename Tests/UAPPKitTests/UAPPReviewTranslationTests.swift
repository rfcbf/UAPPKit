import Testing
#if canImport(Translation)
import SwiftUI
#endif
@testable import UAPPKit

@Test("Reviews detecta idiomas e evita traduzir texto no idioma selecionado")
func reviewTranslationDetectsLanguages() {
    let english = "This application is very useful and easy to use every day."
    let portuguese = "Este aplicativo é muito útil e fácil de usar todos os dias."
    #expect(UAPPReviewTranslation.sourceIdentifier(for: english, targetIdentifier: "pt-BR") == "en")
    #expect(UAPPReviewTranslation.sourceIdentifier(for: portuguese, targetIdentifier: "en") == "pt")
    #expect(UAPPReviewTranslation.sourceIdentifier(for: portuguese, targetIdentifier: "pt-BR") == nil)
    #expect(UAPPReviewTranslation.sourceIdentifier(for: "", targetIdentifier: "en") == nil)
    #expect(UAPPReviewTranslation.shouldTranslate(english, targetIdentifier: "pt-BR"))
    #expect(!UAPPReviewTranslation.shouldTranslate(portuguese, targetIdentifier: "pt-BR"))
    #expect(!UAPPReviewTranslation.shouldTranslate(" \n", targetIdentifier: "en"))
}

#if canImport(Translation)
@Test("Review mantém o original quando a tradução do sistema está desligada")
@MainActor
func reviewTranslationRespectsSystemTranslationFlag() async {
    #expect(EnvironmentValues().uappSystemTranslationEnabled)
    var disabled = EnvironmentValues()
    disabled.uappSystemTranslationEnabled = false
    #expect(!disabled.uappSystemTranslationEnabled)
    if #available(iOS 18.0, macOS 15.0, *) {
        await render(UAPPReviewTranslationContent(
            text: "This application is very useful and easy to use every day.",
            targetIdentifier: "pt-BR"
        ))
    }
}
#endif

@Test("Tradução de review usa texto inteiro ou fragmentos de Markdown em lote")
func reviewTranslationChoosesStrategy() async throws {
    let plain = try await UAPPReviewTranslation.translate(
        "Olá", rendersMarkdown: false,
        single: { "\($0) → Hello" }, batch: { _ in Issue.record("Lote inesperado"); return [] }
    )
    #expect(plain == "Olá → Hello")
    let markdown = try await UAPPReviewTranslation.translate(
        "1. Progresso", rendersMarkdown: true,
        single: { _ in Issue.record("Texto inteiro inesperado"); return "" },
        batch: { $0.map { "EN \($0)" } }
    )
    #expect(markdown.contains("EN"))
}
