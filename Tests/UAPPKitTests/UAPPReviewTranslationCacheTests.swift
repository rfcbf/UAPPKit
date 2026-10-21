import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@Test("Reviews reutiliza tradução após recriar linhas e alternar idiomas")
@MainActor
func reviewsTranslationCacheReusesCompletedText() async {
    let cache = UAPPReviewTranslationCache()
    let model = cache.model(for: "Thank you", targetIdentifier: "pt-BR")
    var calls = 0
    await model.translate { _ in
        calls += 1
        return "Obrigado"
    }
    let recreated = cache.model(for: "Thank you", targetIdentifier: "pt-BR")
    #expect(recreated === model)
    await recreated.translate { _ in
        calls += 1
        return "Outra tradução"
    }
    #expect(calls == 1)
    #expect(recreated.displayText == "Obrigado")
    let spanish = cache.model(for: "Thank you", targetIdentifier: "es")
    #expect(spanish !== model)
    await spanish.translate { _ in "Gracias" }
    #expect(cache.model(for: "Thank you", targetIdentifier: "pt-BR").displayText == "Obrigado")
    #expect(cache.model(for: "Updated text", targetIdentifier: "pt-BR") !== model)
    #expect(UAPPReviewTranslationCache().model(for: "Thank you", targetIdentifier: "pt-BR") !== model)
}

@Test("Reviews compartilha tradução em andamento sem iniciar outra sessão")
@MainActor
func reviewsTranslationCacheDeduplicatesInFlightWork() async {
    let cache = UAPPReviewTranslationCache()
    let model = cache.model(for: "Thank you", targetIdentifier: "pt-BR")
    await model.translate { _ in
        #expect(model.isTranslating)
        let second = cache.model(for: "Thank you", targetIdentifier: "pt-BR")
        #expect(second.isTranslating)
        await second.translate { _ in
            Issue.record("Não deve iniciar outra tradução para o mesmo texto e idioma")
            return "Duplicada"
        }
        return "Obrigado"
    }
    #expect(model.displayText == "Obrigado")
    #expect(!model.isTranslating)
}

@Test("Reviews permite nova tradução após falha sem guardar resultado inválido")
@MainActor
func reviewsTranslationCacheRetriesFailures() async {
    let cache = UAPPReviewTranslationCache()
    let model = cache.model(for: "Thank you", targetIdentifier: "pt-BR")
    await model.translate { _ in throw TestError.expected }
    #expect(model.hasError)
    await cache.model(for: "Thank you", targetIdentifier: "pt-BR").translate { _ in "Obrigado" }
    #expect(model.displayText == "Obrigado")
    #expect(!model.hasError)
}
