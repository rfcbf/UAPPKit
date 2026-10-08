import SwiftUI
import Testing
@testable import UAPPKit

@MainActor
struct UAPPSharedListControlsTests {
    @Test("Texto traduzido e menu de idiomas constroem dentro do escopo de tradução")
    func translatedTextAndLanguageMenuRender() async {
        await render(
            NavigationStack {
                List {
                    UAPPTranslatedText("Exportar relatório em planilha")
                    UAPPTranslatedText("Linha um\nLinha dois\nLinha três", lineLimit: 2)
                }
                .toolbar { UAPPLanguageMenuButton(accentColor: .purple) }
                .uappTranslationScope()
                .environment(\.uappSystemTranslationEnabled, false)
            }
        )
    }

    @Test("Campo de busca aberto e fechado constroem a lista com o texto do aplicativo")
    func searchFieldStatesRender() async {
        for presented in [true, false] {
            var text = presented ? "planilha" : ""
            var isPresented = presented
            await render(
                NavigationStack {
                    List { Text("Requisição") }
                        .uappSearchField(
                            text: Binding(get: { text }, set: { text = $0 }),
                            isPresented: Binding(get: { isPresented }, set: { isPresented = $0 }),
                            prompt: "Buscar requisições",
                            accentColor: .purple
                        )
                }
            )
        }
    }

    @Test("Etapas padrão são traduzidas pela chave e as personalizadas mantêm o nome")
    func statusTitleUsesKeyThenFallback() {
        let previous = UserDefaults.standard.string(forKey: UAPPLocalizationPreferences.presentationStorageKey)
        defer {
            UserDefaults.standard.set(previous, forKey: UAPPLocalizationPreferences.presentationStorageKey)
        }
        UserDefaults.standard.set("en", forKey: UAPPLocalizationPreferences.presentationStorageKey)

        #expect(UAPPRequestStatusTitle.localized(key: "planned", fallback: "Planejados") ==
            uappLocalized("status.planned", languageIdentifier: "en"))
        #expect(UAPPRequestStatusTitle.localized(key: "custom", fallback: "Etapa própria") == "Etapa própria")
    }
}
