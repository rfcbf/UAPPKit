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
    @State private var isSubmittingFeedback = false

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
        .toolbar {
            if case .feedback = mode {
                Button("Enviar feedback") { isSubmittingFeedback = true }
            }
        }
        .sheet(isPresented: $isSubmittingFeedback) {
            NavigationStack {
                UAPPSubmitFeedbackScreen(client: client) {
                    isSubmittingFeedback = false
                    Task { await load() }
                }
            }
        }
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
                NavigationLink {
                    UAPPFeedbackDetailScreen(client: client, item: item)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.headline)
                        if let body = item.body, !body.isEmpty {
                            Text(body).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text("\(item.voteCount) votos · \(item.likeCount) curtidas · \(item.commentCount) comentários")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        case .roadmap:
            ForEach(roadmap, id: \.status.key) { column in
                Section(column.status.name) {
                    if column.items.isEmpty {
                        Text("Nada publicado").foregroundStyle(.secondary)
                    }
                    ForEach(column.items) { item in
                        NavigationLink(item.title) {
                            UAPPFeedbackDetailScreen(client: client, item: item)
                        }
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

private struct UAPPSubmitFeedbackScreen: View {
    let client: UAPPClient
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""
    @State private var category: UAPPFeedbackCategory = .feature
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            TextField("Título", text: $title)
            Picker("Tipo", selection: $category) {
                Text("Bug").tag(UAPPFeedbackCategory.bug)
                Text("Funcionalidade").tag(UAPPFeedbackCategory.feature)
                Text("Melhoria").tag(UAPPFeedbackCategory.improvement)
                Text("Dúvida").tag(UAPPFeedbackCategory.question)
            }
            TextField("Descrição", text: $details, axis: .vertical)
                .lineLimit(4...10)
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .navigationTitle("Novo feedback")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }.disabled(isSending)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enviar") { Task { await submit() } }
                    .disabled(isSending || title.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
            }
        }
    }

    private func submit() async {
        isSending = true
        errorMessage = nil
        do {
            _ = try await client.submitFeedback(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: details.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category
            )
            onComplete()
        } catch {
            errorMessage = "Não foi possível enviar o feedback."
        }
        isSending = false
    }
}

private struct UAPPFeedbackDetailScreen: View {
    let client: UAPPClient
    @State private var item: UAPPFeedbackItem
    @State private var comments: [UAPPComment] = []
    @State private var commentBody = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var pendingReaction: UAPPReactionKind?
    @State private var message: String?

    init(client: UAPPClient, item: UAPPFeedbackItem) {
        self.client = client
        _item = State(initialValue: item)
    }

    var body: some View {
        List {
            Section {
                if let body = item.body, !body.isEmpty {
                    Text(body)
                }
                HStack {
                    Button {
                        Task { await toggle(.vote) }
                    } label: {
                        Label("\(item.voteCount)", systemImage: item.viewerVoted ? "arrow.up.circle.fill" : "arrow.up.circle")
                    }
                    .disabled(pendingReaction != nil)

                    Button {
                        Task { await toggle(.like) }
                    } label: {
                        Label("\(item.likeCount)", systemImage: item.viewerLiked ? "heart.fill" : "heart")
                    }
                    .disabled(pendingReaction != nil)
                }
            }

            Section("Comentários") {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if comments.isEmpty {
                    Text("Nenhum comentário publicado.")
                        .foregroundStyle(.secondary)
                }
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(comment.authorKind == .team ? "Equipe do aplicativo" : "Comunidade")
                            .font(.caption.bold())
                        Text(comment.body)
                        Button {
                            Task { await toggleCommentLike(comment) }
                        } label: {
                            Label("\(comment.likeCount)", systemImage: comment.viewerLiked ? "heart.fill" : "heart")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Section("Comentar") {
                TextField("Escreva um comentário", text: $commentBody, axis: .vertical)
                    .lineLimit(3...8)
                Button("Enviar") {
                    Task { await submitComment() }
                }
                .disabled(isSending || commentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(item.title)
        .task { await loadComments() }
    }

    private func loadComments() async {
        isLoading = true
        do {
            comments = try await client.comments(itemId: item.id).comments
        } catch {
            message = "Não foi possível carregar os comentários."
        }
        isLoading = false
    }

    private func toggle(_ kind: UAPPReactionKind) async {
        pendingReaction = kind
        let enabled = kind == .vote ? !item.viewerVoted : !item.viewerLiked
        do {
            try await client.setReaction(
                itemId: item.id,
                kind: kind,
                enabled: enabled
            )
            item = UAPPFeedbackItem(
                id: item.id,
                title: item.title,
                body: item.body,
                voteCount: item.voteCount + (kind == .vote ? (enabled ? 1 : -1) : 0),
                likeCount: item.likeCount + (kind == .like ? (enabled ? 1 : -1) : 0),
                commentCount: item.commentCount,
                category: item.category,
                priority: item.priority,
                viewerVoted: kind == .vote ? enabled : item.viewerVoted,
                viewerLiked: kind == .like ? enabled : item.viewerLiked,
                createdAt: item.createdAt
            )
        } catch {
            message = "Não foi possível registrar a reação."
        }
        pendingReaction = nil
    }

    private func toggleCommentLike(_ comment: UAPPComment) async {
        do {
            try await client.setReaction(
                itemId: item.id,
                commentId: comment.id,
                kind: .like,
                enabled: !comment.viewerLiked
            )
            await loadComments()
        } catch {
            message = "Não foi possível registrar a curtida."
        }
    }

    private func submitComment() async {
        let body = commentBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        isSending = true
        do {
            _ = try await client.submitComment(itemId: item.id, body: body)
            commentBody = ""
            message = "Comentário recebido e aguardando publicação."
        } catch {
            message = "Não foi possível enviar o comentário."
        }
        isSending = false
    }
}
#endif
