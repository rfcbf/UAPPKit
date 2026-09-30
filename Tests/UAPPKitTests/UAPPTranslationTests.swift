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
