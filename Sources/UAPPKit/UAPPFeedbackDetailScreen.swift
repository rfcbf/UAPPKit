#if canImport(SwiftUI)
import SwiftUI

struct UAPPFeedbackDetailScreen: View {
    let client: UAPPClient
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
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

    init(
        client: UAPPClient,
        item: UAPPFeedbackItem,
        testingComments comments: [UAPPComment],
        isLoading: Bool,
        isSending: Bool = false,
        pendingReaction: UAPPReactionKind? = nil,
        message: String? = nil,
        commentBody: String = ""
    ) {
        self.client = client
        _item = State(initialValue: item)
        _comments = State(initialValue: comments)
        _isLoading = State(initialValue: isLoading)
        _isSending = State(initialValue: isSending)
        _pendingReaction = State(initialValue: pendingReaction)
        _message = State(initialValue: message)
        _commentBody = State(initialValue: commentBody)
    }

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
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

            Section {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if comments.isEmpty {
                    Text(verbatim: uappLocalized("comments.empty"))
                        .foregroundStyle(palette.secondaryText)
                }
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: uappLocalized(
                            comment.authorKind == .team ? "comments.team" : "comments.community"
                        ))
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
            } header: {
                Text(verbatim: uappLocalized("comments.title"))
            }

            Section {
                TextField(
                    uappLocalized("comments.field"),
                    text: $commentBody,
                    axis: .vertical
                )
                .lineLimit(3 ... 8)
                Button {
                    Task { await submitComment() }
                } label: {
                    Text(verbatim: uappLocalized("common.send"))
                }
                .disabled(isSending || commentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let message {
                    Text(message).font(.caption).foregroundStyle(palette.secondaryText)
                }
            } header: {
                Text(verbatim: uappLocalized("comments.write"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .foregroundStyle(palette.primaryText)
        .tint(palette.accent ?? .accentColor)
        .listRowSeparatorTint(palette.separator)
        .listRowBackground(palette.cardBackground)
        .uappNavigationBar(
            verbatimTitle: item.title,
            accentColor: palette.accent ?? .accentColor,
            showsCloseButton: false
        )
        .task { await loadComments() }
    }

    private func loadComments() async {
        isLoading = true
        do {
            comments = try await client.comments(itemId: item.id).comments
        } catch {
            message = uappLocalized("detail.comments_load_error")
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
            message = uappLocalized("detail.reaction_error")
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
            message = uappLocalized("detail.like_error")
        }
    }

    private func submitComment() async {
        let body = commentBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        isSending = true
        do {
            _ = try await client.submitComment(itemId: item.id, body: body)
            commentBody = ""
            message = uappLocalized("detail.comment_submitted")
        } catch {
            message = uappLocalized("detail.comment_error")
        }
        isSending = false
    }
}
#endif
