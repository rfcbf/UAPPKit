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

/// Requisição preenchida no compositor e entregue ao envio do aplicativo.
/// Título e descrição chegam sem espaços nas pontas; `imagesData` traz os
/// anexos já compactados, até o limite do compositor.
public struct UAPPFeedbackSubmission: Sendable, Equatable {
    public var title: String
    public var details: String
    public var category: UAPPFeedbackCategory
    public var imagesData: [Data]

    public init(
        title: String,
        details: String = "",
        category: UAPPFeedbackCategory = .feature,
        imagesData: [Data] = []
    ) {
        self.title = title
        self.details = details
        self.category = category
        self.imagesData = imagesData
    }
}

/// Destino do envio do compositor: o cliente do projeto ou a função do
/// aplicativo.
enum UAPPFeedbackSender {
    case client(UAPPClient)
    case custom(@MainActor (UAPPFeedbackSubmission) async throws -> Void)

    @MainActor
    func send(_ submission: UAPPFeedbackSubmission) async throws {
        switch self {
        case let .client(client):
            _ = try await client.submitFeedback(
                title: submission.title,
                body: submission.details,
                category: submission.category,
                imagesData: submission.imagesData
            )
        case let .custom(submit):
            try await submit(submission)
        }
    }

    /// Aviso exibido quando o envio falha. O envio do aplicativo pode trazer a
    /// própria mensagem por `LocalizedError.errorDescription`; o cliente do
    /// projeto mantém sempre a mensagem genérica.
    func failure(for error: any Error) -> UAPPFeedbackSubmitFailure {
        guard case .custom = self,
              let description = (error as? any LocalizedError)?.errorDescription?
              .trimmingCharacters(in: .whitespacesAndNewlines),
              !description.isEmpty
        else { return .generic }
        return .described(description)
    }
}

/// Falha de envio mostrada no aviso do compositor.
enum UAPPFeedbackSubmitFailure: Equatable {
    case generic
    case described(String)

    var message: String {
        switch self {
        case .generic: uappLocalized("feedback.submit_error")
        case let .described(text): text
        }
    }
}

/// Compositor nativo de feedback apresentado diretamente pelo aplicativo, sem
/// passar pela lista de Feedback. Traz sua própria navegação; apresente em
/// sheet ou destino equivalente.
public struct UAPPFeedbackComposerScreen: View {
    private let sender: UAPPFeedbackSender
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
        sender = .client(client)
        self.draft = draft
        self.theme = theme
        self.onComplete = onComplete
    }

    /// Mesmo compositor, com o envio feito pelo aplicativo, por exemplo para o
    /// próprio backend.
    ///
    /// - Parameters:
    ///   - draft: título, descrição e tipo iniciais.
    ///   - theme: tema aplicado ao compositor.
    ///   - submit: envia a requisição. Se lançar um erro, o compositor continua
    ///     aberto e mostra um aviso: o texto de `LocalizedError.errorDescription`,
    ///     quando houver, ou a mensagem genérica de falha no envio.
    ///   - onComplete: chamado depois que `submit` termina sem erro; o
    ///     aplicativo fecha a apresentação.
    public init(
        draft: UAPPFeedbackDraft = UAPPFeedbackDraft(),
        theme: UAPPTheme = .system,
        submit: @escaping @MainActor (UAPPFeedbackSubmission) async throws -> Void,
        onComplete: @escaping @MainActor () -> Void
    ) {
        sender = .custom(submit)
        self.draft = draft
        self.theme = theme
        self.onComplete = onComplete
    }

    public var body: some View {
        screenBody.uappTextSizeLimit()
    }

    private var screenBody: some View {
        NavigationStack {
            UAPPSubmitFeedbackScreen(sender: sender, draft: draft) { onComplete() }
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

#Preview("Compositor com envio próprio") {
    UAPPFeedbackComposerScreen(
        draft: UAPPFeedbackDraft(
            title: "Exportar em planilha",
            details: "Seria útil exportar o relatório mensal.",
            category: .feature
        ),
        submit: { _ in try await Task.sleep(for: .seconds(1)) },
        onComplete: {}
    )
}
#endif
