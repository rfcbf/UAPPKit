import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

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

    @Test("Seletor e galeria de anexos constroem vazios e com imagens")
    func attachmentPickerAndGalleryRender() async {
        var data: [Data] = []
        var isProcessing = false
        await render(
            VStack {
                UAPPImageAttachmentPicker(
                    data: Binding(get: { data }, set: { data = $0 }),
                    isProcessing: Binding(get: { isProcessing }, set: { isProcessing = $0 })
                )
                UAPPImageAttachmentGallery(urls: [])
                UAPPImageAttachmentGallery(urls: [URL(string: "https://example.com/a.jpg")!])
            }
        )
        #expect(UAPPImageAttachmentPicker.limit == 2)
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
        #expect(UAPPRequestStatusTitle.localized(key: "planned", fallback: "Planejados", languageIdentifier: "pt-BR") ==
            uappLocalized("status.planned", languageIdentifier: "pt-BR"))
    }
}
