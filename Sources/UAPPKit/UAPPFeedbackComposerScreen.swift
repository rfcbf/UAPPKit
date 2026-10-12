#if canImport(SwiftUI)
import SwiftUI

/// Conteúdo inicial do compositor de feedback, para o aplicativo abrir o envio
/// já preenchido com o contexto que tem em mãos. A pessoa pode revisar e
/// alterar tudo antes de enviar.
public struct UAPPFeedbackDraft: Sendable, Equatable {
    public var title: String
    public var details: String
    public var category: UAPPFeedbackCategory

    public init(
        title: String = "",
        details: String = "",
        category: UAPPFeedbackCategory = .feature
    ) {
        self.title = title
        self.details = details
        self.category = category
    }
}

/// Compositor nativo de feedback apresentado diretamente pelo aplicativo, sem
/// passar pela lista de Feedback. Traz sua própria navegação; apresente em
/// sheet ou destino equivalente.
public struct UAPPFeedbackComposerScreen: View {
    private let client: UAPPClient
    private let draft: UAPPFeedbackDraft
    private let theme: UAPPTheme
    private let onComplete: @MainActor () -> Void
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier

    /// - Parameters:
    ///   - client: cliente do projeto que receberá o feedback.
    ///   - draft: título, descrição e tipo iniciais.
    ///   - theme: tema aplicado ao compositor.
    ///   - onComplete: chamado após o envio; o aplicativo fecha a apresentação.
    public init(
        client: UAPPClient,
        draft: UAPPFeedbackDraft = UAPPFeedbackDraft(),
        theme: UAPPTheme = .system,
        onComplete: @escaping @MainActor () -> Void
    ) {
        self.client = client
        self.draft = draft
        self.theme = theme
        self.onComplete = onComplete
    }

    public var body: some View {
        screenBody.uappTextSizeLimit()
    }

    private var screenBody: some View {
        NavigationStack {
            UAPPSubmitFeedbackScreen(client: client, draft: draft) { onComplete() }
        }
        .environment(\.uappTheme, theme)
        .environment(\.locale, Locale(identifier: selectedLanguage))
    }
}

#Preview("Compositor preenchido") {
    UAPPFeedbackComposerScreen(
        client: UAPPClient(configuration: UAPPConfiguration(projectId: "exemplo")),
        draft: UAPPFeedbackDraft(
            title: "Falha ao importar relatórios",
            details: "A importação parou no terceiro mês.",
            category: .bug
        ),
        onComplete: {}
    )
}
#endif
