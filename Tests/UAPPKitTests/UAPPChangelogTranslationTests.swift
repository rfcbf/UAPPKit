import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@Test("changelog compartilha tradução Markdown entre lista e detalhes por idioma")
@MainActor
func changelogTranslationCache() async {
    let original = "Added **search** and improved navigation."
    let cache = UAPPReviewTranslationCache()
    let model = cache.model(for: original, targetIdentifier: "pt-BR")
    await model.translate { text in
        #expect(text == original)
        return "Adicionada **pesquisa** e melhorada a navegação."
    }
    #expect(cache.model(for: original, targetIdentifier: "pt-BR") === model)
    #expect(cache.model(for: original, targetIdentifier: "es") !== model)
    #expect(cache.model(for: original, targetIdentifier: "es").translated == nil)
    #expect(String(uappChangelogMarkdown(model.displayText).characters) == "Adicionada pesquisa e melhorada a navegação.")
    for limit in [3, nil] {
        await render(UAPPReviewTranslationContent(
            text: original, targetIdentifier: "pt-BR", model: model,
            rendersMarkdown: true, lineLimit: limit
        ))
    }
    await render(UAPPChangelogTranslatedText(text: original, lineLimit: 3)
        .environment(\.uappChangelogTranslationCache, cache))
}

@Test("changelog mantém o original quando a tradução falha e mostra carregamento")
@MainActor
func changelogTranslationFailure() async {
    let original = "**Novidades** e correções nesta versão."
    let model = UAPPReviewTextModel(original: original)
    await model.translate { _ in
        #expect(model.isTranslating)
        await render(UAPPReviewTranslationContent(
            text: original, targetIdentifier: "pt-BR", model: model,
            rendersMarkdown: true, lineLimit: 3
        ))
        throw TestError.expected
    }
    #expect(model.hasError)
    #expect(model.displayText == original)
    await render(UAPPReviewTranslationContent(
        text: original, targetIdentifier: "pt-BR", model: model, rendersMarkdown: true
    ))
    #expect(!UAPPReviewTranslation.shouldTranslate(original, targetIdentifier: "pt-BR"))
    #expect(UAPPReviewTranslation.shouldTranslate(original, targetIdentifier: "en"))
}

@Test("tradução do changelog mantém espaçamento, marcadores e numeração originais")
@MainActor
func changelogTranslationPreservesLayout() async throws {
    let source = "## Novidades\n1. Progresso do dia\n2. Saldo de horas\n\n  - **Sincronização** e *melhorias*.\n\nDescrição geral.\n"
    var fragments: [String] = []
    let translated = try await uappTranslateChangelogMarkdown(source) { fragment in
        fragments.append(fragment)
        return "\n\nTranslated \(fragment)\n\n"
    }
    #expect(translated == "## Translated Novidades\n1. Translated Progresso do dia\n2. Translated Saldo de horas\n\n  - Translated **Sincronização** e *melhorias*.\n\nTranslated Descrição geral.\n")
    #expect(fragments == ["Novidades", "Progresso do dia", "Saldo de horas", "**Sincronização** e *melhorias*.", "Descrição geral."])
    #expect(String(uappChangelogMarkdown(translated).characters).contains("1. Translated Progresso do dia\n2. Translated Saldo de horas"))
    #expect(translated.filter { $0 == "\n" }.count == source.filter { $0 == "\n" }.count)
}

@Test("tradução preserva linhas vazias e blocos de código, e rejeita resultado vazio")
@MainActor
func changelogTranslationEmptyAndCode() async throws {
    var calls = 0
    let source = "\r\n~~~swift\r\nlet value = 1\r\n~~~\r\n\r\nTexto\r\n"
    let result = try await uappTranslateChangelogMarkdown(source) { _ in
        calls += 1
        return "Text"
    }
    #expect(result == "\n~~~swift\nlet value = 1\n~~~\n\nText\n")
    #expect(calls == 1)
    await #expect(throws: UAPPChangelogTranslationError.self) {
        try await uappTranslateChangelogMarkdown("1. Item") { _ in "\n  \n" }
    }
}

@Test("lista, detalhes e células recriadas reutilizam a mesma tradução sem novas chamadas")
@MainActor
func changelogTranslationSurvivesNavigationAndReuse() async throws {
    let original = "1. Progresso do dia\n2. Saldo de horas"
    let entry = UAPPChangelogEntry(title: "2.0", slug: "2", bodyMarkdown: original, version: "2.0")
    let cache = UAPPReviewTranslationCache()
    let client = makeClient { _ in response(#"{"ok":true,"items":[]}"#) }
    await renderInNavigationStack(UAPPFeedbackScreen(
        client: client, mode: .changelog, testingIsLoading: false, changelog: [entry],
        testingChangelogTranslationCache: cache
    ))
    let detail = UAPPFeedbackScreen.changelogDetailScreen(for: entry, accentColor: .blue, translationCache: cache)
    #expect(detail.translationCache === cache)
    #expect(detail.entry == entry)
    let model = cache.model(for: original, targetIdentifier: "en")
    var calls = 0
    await model.translate { _ in
        calls += 1
        #expect(detail.translationCache?.model(for: original, targetIdentifier: "en") === model)
        #expect(model.isTranslating)
        return "1. Day progress\n2. Hours balance"
    }
    for _ in 0 ..< 3 {
        let recreated = UAPPChangelogCard(entry: entry, configuration: .init(), translationCache: cache)
        await render(recreated.environment(\.uappChangelogImageFixture, .success))
        let reusedCache = try #require(UAPPFeedbackScreen.changelogDetailScreen(
            for: entry, accentColor: .blue, translationCache: cache
        ).translationCache)
        let reusedModel = reusedCache.model(for: original, targetIdentifier: "en")
        await reusedModel.translate { _ in
            calls += 1
            return "Unexpected translation"
        }
        await render(UAPPReviewTranslationContent(
            text: original, targetIdentifier: "en", model: reusedModel, rendersMarkdown: true
        ))
        #expect(reusedModel === model)
    }
    #expect(calls == 1)
    #expect(model.displayText == "1. Day progress\n2. Hours balance")
    #expect(cache.model(for: original, targetIdentifier: "es") !== model)
    #expect(cache.model(for: original + "\n3. Outro item", targetIdentifier: "en") !== model)
}

@Test("falha ao traduzir um item mantém o Markdown original completo")
@MainActor
func changelogTranslationFragmentFailure() async {
    let original = "1. Primeiro\n2. Segundo"
    let model = UAPPReviewTextModel(original: original)
    await model.translate { text in
        try await uappTranslateChangelogMarkdown(text) { fragment in
            if fragment == "Segundo" {
                throw TestError.expected
            }
            return "First"
        }
    }
    #expect(model.hasError)
    #expect(model.displayText == original)
    #expect(model.translated == nil)
}

@Test("detalhes aguardam a tradução da lista sem executar uma segunda tradução")
@MainActor
func changelogTranslationSharesPendingRequest() async {
    let gate = RequestGate()
    let model = UAPPReviewTextModel(original: "Primeiro")
    var calls = 0
    let listTask = Task {
        await model.translate(waitForPending: true) { _ in
            calls += 1
            await gate.suspend()
            return "First"
        }
    }
    await gate.waitUntilStarted()
    let detailTask = Task {
        await model.translate(waitForPending: true) { _ in
            calls += 1
            return "Duplicate"
        }
    }
    await Task.yield()
    await gate.resume()
    await listTask.value
    await detailTask.value
    #expect(calls == 1)
    #expect(model.displayText == "First")
}

@Test("detalhes retomam tradução pendente se a célula desaparece e cancela a tarefa")
@MainActor
func changelogTranslationRecoversCancelledRow() async {
    let gate = RequestGate()
    let model = UAPPReviewTextModel(original: "Primeiro")
    let listTask = Task {
        await model.translate(waitForPending: true) { _ in
            await gate.suspend()
            try Task.checkCancellation()
            return "Cancelled"
        }
    }
    await gate.waitUntilStarted()
    let detailTask = Task {
        await model.translate(waitForPending: true) { _ in "First" }
    }
    await Task.yield()
    listTask.cancel()
    await gate.resume()
    await listTask.value
    await detailTask.value
    #expect(!model.isTranslating)
    #expect(!model.hasError)
    #expect(model.displayText == "First")
}

@Test("cancelar sessão que não retorna libera tradução dos detalhes imediatamente")
@MainActor
func changelogTranslationRecoversUnresponsiveSession() async {
    let gate = RequestGate()
    let model = UAPPReviewTextModel(original: "1. Primeiro\n2. Segundo")
    let listTask = Task {
        await model.translate(waitForPending: true) { _ in
            await gate.suspend()
            return "Obsolete result"
        }
    }
    await gate.waitUntilStarted()
    let detailTask = Task {
        await model.translate(waitForPending: true) { _ in "1. First\n2. Second" }
    }
    await Task.yield()
    listTask.cancel()
    // The original service is still suspended; recovery must not wait for it.
    await detailTask.value
    #expect(!model.isTranslating)
    #expect(!model.hasError)
    #expect(model.displayText == "1. First\n2. Second")
    await gate.resume()
    await listTask.value
    #expect(model.displayText == "1. First\n2. Second")
}

@Test("cancelar detalhes enquanto aguardam não cancela a tradução da lista")
@MainActor
func changelogTranslationCancelsWaitingView() async {
    let gate = RequestGate()
    let model = UAPPReviewTextModel(original: "Primeiro")
    let listTask = Task {
        await model.translate(waitForPending: true) { _ in
            await gate.suspend()
            return "First"
        }
    }
    await gate.waitUntilStarted()
    let detailTask = Task {
        await model.translate(waitForPending: true) { _ in
            Issue.record("A tela cancelada não deve iniciar uma tradução")
            return "Duplicate"
        }
    }
    await Task.yield()
    detailTask.cancel()
    await detailTask.value
    #expect(model.isTranslating)
    await gate.resume()
    await listTask.value
    #expect(model.displayText == "First")
}

@Test("changelog traduz todas as linhas em um lote sem mudar o layout")
@MainActor
func changelogTranslationBatchesLines() async throws {
    var calls = 0
    let result = try await uappTranslateChangelogMarkdown(
        "1. Progresso do dia\n2. Saldo de horas\n\n- **Sincronização** via iCloud.",
        usingBatch: { fragments in
            calls += 1
            #expect(fragments == ["Progresso do dia", "Saldo de horas", "**Sincronização** via iCloud."])
            return ["Day progress", "Hours balance", "**Synchronization** via iCloud."]
        }
    )
    #expect(calls == 1)
    #expect(result == "1. Day progress\n2. Hours balance\n\n- **Synchronization** via iCloud.")
    await #expect(throws: UAPPChangelogTranslationError.self) {
        try await uappTranslateChangelogMarkdown("1. Primeiro\n2. Segundo", usingBatch: { _ in ["First"] })
    }
    let empty = try await uappTranslateChangelogMarkdown("\n\n", usingBatch: { _ in
        Issue.record("Linhas vazias não devem chamar o serviço")
        return []
    })
    #expect(empty == "\n\n")
}
