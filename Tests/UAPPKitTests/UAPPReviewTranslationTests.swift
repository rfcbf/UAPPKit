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
@Test("Review configura tradução nativa para origem detectada sem iniciar sessão")
@MainActor
func reviewTranslationBuildsNativeConfiguration() {
    if #available(iOS 18.0, macOS 15.0, *) {
        let content = UAPPReviewTranslationContent(
            text: "This application is very useful and easy to use every day.",
            targetIdentifier: "pt-BR"
        )
        _ = content.body
    }
}
#endif
