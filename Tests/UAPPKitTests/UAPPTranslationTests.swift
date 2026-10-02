import SwiftUI
import Testing
@testable import UAPPKit

@Test("Tradução existente mantém biografia e idiomas regionais ao renderizar")
@MainActor
func existingTranslationRendersRegionalFallbacks() async {
    await render(UAPPAboutBio(text: "Original", defaultLanguageIdentifier: "pt-BR", translations: ["en": "English"], targetIdentifier: "en-US"))
    await render(UAPPAboutBio(text: "Original", defaultLanguageIdentifier: "pt-BR", translations: ["pt_BR": "Texto"], targetIdentifier: "pt-BR"))
    await render(UAPPAboutBio(text: "Original", defaultLanguageIdentifier: "zh-Hans", translations: [:], targetIdentifier: "zh-Hant"))
    await render(UAPPAboutBio(text: "Original", defaultLanguageIdentifier: "pt-BR", translations: ["en": " "], targetIdentifier: "en"))
}

@Test("Resultado da tradução da biografia distingue sucesso, cancelamento e falha")
func bioTranslationOutcome() async {
    #expect(await UAPPBioTranslationOutcome.resolve { "Translated" } == .translated("Translated"))
    #expect(await UAPPBioTranslationOutcome.resolve { throw CancellationError() } == .cancelled)
    #expect(await UAPPBioTranslationOutcome.resolve { throw TestError.expected } == .failed)
    let cancelledSuccess = Task { await UAPPBioTranslationOutcome.resolve { withUnsafeCurrentTask { $0?.cancel() }; return "Late" } }
    #expect(await cancelledSuccess.value == .ignored)
    let cancelledFailure = Task {
        await UAPPBioTranslationOutcome.resolve { withUnsafeCurrentTask { $0?.cancel() }; throw TestError.expected }
    }
    #expect(await cancelledFailure.value == .ignored)
}

#if canImport(Translation)
@Test("Biografia traduzida, em tradução e original constroem a interface")
@MainActor
func appleTranslatedBioStatesRender() async {
    if #available(iOS 18.0, macOS 15.0, *) {
        await render(UAPPAppleTranslatedBio(text: "Original", sourceIdentifier: "pt", targetIdentifier: "en"))
        await render(UAPPAppleTranslatedBio(
            text: "Original", sourceIdentifier: "pt", targetIdentifier: "en", isTranslating: true
        ))
        await render(UAPPAppleTranslatedBio(
            text: "Original", sourceIdentifier: "pt", targetIdentifier: "en", translatedText: "Translated"
        ).environment(\.uappTheme, .init(light: .init(accent: .purple))))
    }
}
#endif
