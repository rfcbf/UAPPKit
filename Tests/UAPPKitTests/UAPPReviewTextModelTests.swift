import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@Test("Tradução de review mantém original até sucesso e aceita nova tradução")
@MainActor
func reviewTextTranslationSucceeds() async {
    let model = UAPPReviewTextModel(original: "Thank you")
    #expect(model.displayText == "Thank you")
    await model.translate { text in
        #expect(text == "Thank you")
        #expect(model.isTranslating)
        return "Obrigado"
    }
    #expect(model.displayText == "Obrigado")
    #expect(!model.hasError && !model.isTranslating)
    model.reset()
    #expect(model.displayText == "Thank you")
    await model.translate { _ in "Gracias" }
    #expect(model.displayText == "Gracias")
}

@Test("Tradução de review preserva original em falha ou resposta vazia")
@MainActor
func reviewTextTranslationFails() async {
    let model = UAPPReviewTextModel(original: "Thank you")
    await model.translate { _ in throw TestError.expected }
    #expect(model.displayText == "Thank you")
    #expect(model.hasError && !model.isTranslating)
    model.reset()
    #expect(!model.hasError)
    await model.translate { _ in " \n" }
    #expect(model.hasError)
    #expect(model.displayText == "Thank you")
}

@Test("Tradução de review ignora resultados antigos após reset")
@MainActor
func reviewTextTranslationIgnoresStaleResults() async {
    let model = UAPPReviewTextModel(original: "Thank you")
    await model.translate { _ in
        model.reset()
        return "Antigo"
    }
    #expect(model.displayText == "Thank you")
    #expect(!model.isTranslating)
    await model.translate { _ in
        model.reset()
        throw TestError.expected
    }
    #expect(!model.hasError)
}

@Test("Tradução de review cancelada preserva original sem mensagem de falha")
@MainActor
func reviewTextTranslationCancels() async {
    let model = UAPPReviewTextModel(original: "Thank you")
    let task = Task {
        await model.translate { _ in
            withUnsafeCurrentTask { $0?.cancel() }
            return "Obrigado"
        }
    }
    await task.value
    #expect(model.displayText == "Thank you")
    #expect(!model.hasError && !model.isTranslating)
}
