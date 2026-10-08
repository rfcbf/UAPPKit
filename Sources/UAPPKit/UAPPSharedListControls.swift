#if canImport(SwiftUI)
import SwiftUI

/// Texto traduzido automaticamente para o idioma de apresentação escolhido no
/// menu de idiomas do pacote. Quando o texto já está nesse idioma, ou a
/// tradução não está disponível, mostra o original.
public struct UAPPTranslatedText: View {
    private let text: String
    private let lineLimit: Int?

    public init(_ text: String, lineLimit: Int? = nil) {
        self.text = text
        self.lineLimit = lineLimit
    }

    public var body: some View {
        UAPPFeedbackTranslatedText(text: text, lineLimit: lineLimit)
    }
}

/// Botão de globo que abre a lista de idiomas de apresentação. A escolha vale
/// para as telas do pacote e para todo `UAPPTranslatedText`.
public struct UAPPLanguageMenuButton: View {
    private let accentColor: Color?

    public init(accentColor: Color? = nil) {
        self.accentColor = accentColor
    }

    public var body: some View {
        UAPPLanguageMenu(accentOverride: accentColor)
    }
}

/// Nome de uma etapa de requisição no idioma de apresentação.
public enum UAPPRequestStatusTitle {
    /// Etapas padrão do UAPP são traduzidas pela chave; as personalizadas usam o nome recebido.
    public static func localized(key: String, fallback: String) -> String {
        uappFeedbackStatusTitle(UAPPRoadmapColumn.Status(id: key, key: key, name: fallback, position: 0))
    }
}

public extension View {
    /// Mantém as traduções já feitas enquanto a tela existir, para que as
    /// linhas de uma lista não traduzam de novo ao rolar. Também aplica o
    /// idioma de apresentação escolhido às datas e aos números da tela.
    func uappTranslationScope() -> some View {
        modifier(UAPPTranslationScopeModifier())
    }

    /// Campo de busca do sistema aberto por um botão da tela: na barra de
    /// ferramentas a partir do iOS 26 e em uma cápsula inferior nas versões
    /// anteriores. Com `isPresented` falso, nenhum campo é mostrado.
    func uappSearchField(
        text: Binding<String>,
        isPresented: Binding<Bool>,
        prompt: String,
        accentColor: Color = .accentColor
    ) -> some View {
        modifier(UAPPChangelogSearchModifier(
            enabled: true,
            query: text,
            isPresented: isPresented,
            accentColor: accentColor,
            promptText: prompt
        ))
    }
}

struct UAPPTranslationScopeModifier: ViewModifier {
    @State private var cache = UAPPReviewTranslationCache()
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier

    func body(content: Content) -> some View {
        content
            .environment(\.uappFeedbackTranslationCache, cache)
            .environment(\.locale, Locale(identifier: selectedLanguage))
    }
}
#endif
