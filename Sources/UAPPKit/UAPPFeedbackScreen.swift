#if canImport(SwiftUI)
import SwiftUI

/// Modo de exibição da tela nativa.
public enum UAPPScreenMode: Sendable {
    case feedback
    case roadmap
    case changelog

    var title: String {
        switch self {
        case .feedback: return "Feedback"
        case .roadmap: return "Roadmap"
        case .changelog: return "Novidades"
        }
    }
}

/// Tela SwiftUI nativa que consome as Edge Functions públicas do UAPP.
/// Sem WebView: toda a interface é nativa e evolui pelo próprio pacote.
public struct UAPPFeedbackScreen: View {
    let client: UAPPClient
    let mode: UAPPScreenMode

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var feedback: [UAPPFeedbackItem] = []
    @State private var roadmap: [UAPPRoadmapColumn] = []
    @State private var changelog: [UAPPChangelogEntry] = []

    public init(client: UAPPClient, mode: UAPPScreenMode) {
        self.client = client
        self.mode = mode
    }

    public var body: some View {
        List {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.secondary)
            } else {
                content
            }
        }
        .navigationTitle(mode.title)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .feedback:
            if feedback.isEmpty {
                Text("Ainda não há feedback publicado.")
                    .foregroundStyle(.secondary)
            }
            ForEach(feedback) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.headline)
                    if let body = item.body, !body.isEmpty {
                        Text(body).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("\(item.voteCount) votos · \(item.commentCount) comentários")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        case .roadmap:
            ForEach(roadmap, id: \.status.key) { column in
                Section(column.status.name) {
                    if column.items.isEmpty {
                        Text("Nada publicado").foregroundStyle(.secondary)
                    }
                    ForEach(column.items) { item in
                        Text(item.title)
                    }
                }
            }
        case .changelog:
            if changelog.isEmpty {
                Text("Nenhuma novidade publicada.")
                    .foregroundStyle(.secondary)
            }
            ForEach(changelog) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title).font(.headline)
                    Text(formattedChangelogBody(entry.bodyMarkdown))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            switch mode {
            case .feedback:
                feedback = try await client.feedback()
            case .roadmap:
                roadmap = try await client.roadmap()
            case .changelog:
                changelog = try await client.changelog()
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Não foi possível carregar."
        }
        isLoading = false
    }

    /// Renderiza negrito/itálico/listas do changelog (CommonMark básico, o mesmo suportado no web).
    private func formattedChangelogBody(_ markdown: String) -> AttributedString {
        (try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        )) ?? AttributedString(markdown)
    }
}
#endif
