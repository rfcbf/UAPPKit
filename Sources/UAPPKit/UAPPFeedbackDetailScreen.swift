#if canImport(SwiftUI)
import SwiftUI

struct UAPPFeedbackDetailScreen: View {
    let client: UAPPClient
    var accentColor: Color?
    var onUpdate: (UAPPFeedbackItem) -> Void = { _ in }
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier
    @State private var translationCache = UAPPReviewTranslationCache()
    @State private var item: UAPPFeedbackItem
    @State private var status: UAPPRoadmapColumn.Status?
    @State private var comments: [UAPPComment] = []
    @State private var commentBody = ""
    @State private var commentImage: [Data] = []
    @State private var isProcessingImage = false
    @State private var replyingTo: UAPPComment?
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var isAvailable = true
    @State private var isSending = false
    @State private var pendingReaction: UAPPReactionKind?
    @State private var reactingComments: Set<String> = []
    @State private var message: String?
    @State private var commentsError: String?
    @StateObject private var participation: UAPPParticipationModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case comment }

    init(
        client: UAPPClient,
        item: UAPPFeedbackItem,
        accentColor: Color? = nil,
        status: UAPPRoadmapColumn.Status? = nil,
        onUpdate: @escaping (UAPPFeedbackItem) -> Void = { _ in }
    ) {
        self.client = client
        self.accentColor = accentColor
        self.onUpdate = onUpdate
        _participation = StateObject(wrappedValue: UAPPParticipationModel(client: client))
        _item = State(initialValue: item)
        _status = State(initialValue: status)
    }

    init(
        client: UAPPClient,
        item: UAPPFeedbackItem,
        testingComments comments: [UAPPComment],
        isLoading: Bool,
        isSending: Bool = false,
        pendingReaction: UAPPReactionKind? = nil,
        message: String? = nil,
        commentBody: String = "",
        isAvailable: Bool = true,
        replyingTo: UAPPComment? = nil,
        commentsError: String? = nil
    ) {
        self.client = client
        _participation = StateObject(wrappedValue: UAPPParticipationModel(client: client))
        _item = State(initialValue: item)
        _comments = State(initialValue: comments)
        _isLoading = State(initialValue: isLoading)
        _isSending = State(initialValue: isSending)
        _pendingReaction = State(initialValue: pendingReaction)
        _message = State(initialValue: message)
        _commentBody = State(initialValue: commentBody)
        _isAvailable = State(initialValue: isAvailable)
        _replyingTo = State(initialValue: replyingTo)
        _commentsError = State(initialValue: commentsError)
    }

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    private var resolvedAccent: Color {
        palette.accent ?? accentColor ?? .accentColor
    }

    private var canSend: Bool {
        !isSending && !isProcessingImage && !participation.isBusy &&
            !commentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if isAvailable {
                        feedbackContent
                        Divider().overlay(palette.separator)
                        composer.id("comment-composer")
                        commentsContent
                    } else {
                        VStack(spacing: 12) {
                            UAPPAccentIconBadge(systemImage: "eye.slash", accent: resolvedAccent)
                            Text(verbatim: uappLocalized("unavailable.content"))
                                .font(.subheadline)
                                .foregroundStyle(palette.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .uappCardSurface(palette)
                    }
                }
                .padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
                .foregroundStyle(palette.primaryText)
            }
            .uappOnChange(of: replyingTo?.id) { id in
                guard id != nil else { return }
                proxy.scrollTo("comment-composer", anchor: .center)
                focusedField = .comment
            }
            .refreshable { await refresh(showError: true) }
        }
        .background(palette.background).tint(resolvedAccent)
        .uappToast(
            message: Binding(
                get: { message.map { uappLocalized($0) } },
                set: {
                    if $0 == nil {
                        message = nil
                    }
                }
            ),
            kind: message == "detail.comment_submitted" ? .success : .error
        )
        .uappKeyboardFieldNavigation(
            focusedField: $focusedField,
            fields: [.comment],
            accentColor: resolvedAccent
        )
        .modifier(UAPPParticipationModifier(model: participation, accentColor: resolvedAccent))
        .uappNavigationBar(
            titleKey: "feedback.detail_title",
            accentColor: resolvedAccent,
            showsCloseButton: false,
            showsLanguageMenu: false
        )
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: backButtonPlacement) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(resolvedAccent)
                }
                .buttonStyle(.plain)
                .foregroundStyle(resolvedAccent)
                .tint(resolvedAccent)
                .accessibilityLabel(Text(verbatim: uappLocalized("account.back")))
            }
        }
        .task(id: scenePhase) {
            if isLoading || scenePhase == .active {
                await refresh(showError: isLoading)
            }
        }
        .modifier(UAPPFeedbackLiveModifier(client: client) { await refresh() })
        .environment(\.uappFeedbackTranslationCache, translationCache)
        .environment(\.locale, Locale(identifier: selectedLanguage))
    }

    private var backButtonPlacement: ToolbarItemPlacement {
        #if canImport(UIKit)
        .navigationBarLeading
        #else
        .navigation
        #endif
    }

    private var feedbackContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                UAPPFeedbackAvatar(name: authorName, url: item.authorAvatarURL).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: authorName).font(.subheadline.weight(.semibold))
                    if let date = item.createdAt {
                        dateLabel(date)
                    }
                }
            }
            UAPPFeedbackTranslatedText(text: item.title).font(.title2.bold())
            if let body = item.body, !body.isEmpty {
                UAPPFeedbackTranslatedText(text: body).font(.body).foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
            if !item.attachmentURLs.isEmpty {
                UAPPFeedbackImageGallery(urls: item.attachmentURLs)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { statusAndComments; Spacer(minLength: 8); votersAndVotes }
                VStack(alignment: .leading, spacing: 12) { statusAndComments; votersAndVotes }
            }
        }
    }

    private var statusAndComments: some View {
        HStack(spacing: 10) {
            UAPPStatusBadge(status: status)
            Label(item.commentCount.formatted(), systemImage: "bubble.right")
                .font(.caption).foregroundStyle(palette.secondaryText)
                .accessibilityLabel(Text(verbatim: uappLocalizedFormat("feedback.comments_count", item.commentCount)))
        }
    }

    private var votersAndVotes: some View {
        HStack(spacing: 12) {
            HStack(spacing: -10) {
                ForEach(Array((item.voters ?? []).prefix(5).enumerated()), id: \.offset) { _, voter in
                    UAPPFeedbackAvatar(name: voter.displayName, url: voter.avatarURL, size: 32)
                        .overlay(Circle().strokeBorder(palette.background, lineWidth: 2))
                }
            }
            Button { Task { await participation.perform { await toggleVote() } } } label: {
                reactionLabel(count: item.voteCount, selected: item.viewerVoted)
            }
            .buttonStyle(.plain).disabled(pendingReaction != nil || participation.isBusy)
            .accessibilityLabel(Text(verbatim: uappLocalizedFormat("feedback.votes_count", item.voteCount)))
            .accessibilityAddTraits(item.viewerVoted ? [.isSelected] : [])
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            UAPPSectionHeader(
                title: uappLocalized("comments.title"),
                detail: item.commentCount > 0 ? item.commentCount.formatted() : nil,
                palette: palette,
                font: .headline
            )
            if let replyingTo {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption)
                        .foregroundStyle(resolvedAccent)
                        .accessibilityHidden(true)
                    Text(verbatim: uappLocalizedFormat("comments.replying_to", displayName(replyingTo)))
                        .font(.caption.weight(.medium)).foregroundStyle(palette.secondaryText)
                    Spacer()
                    Button { discardCommentDraft() } label: {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }
                    .disabled(isSending || isProcessingImage || participation.isBusy)
                    .accessibilityLabel(Text(verbatim: uappLocalized("comments.cancel_reply")))
                }
                .padding(.leading, 12)
                .background(
                    resolvedAccent.opacity(UAPPSurface.selectionFillOpacity(colorScheme)),
                    in: RoundedRectangle(cornerRadius: UAPPSurface.cornerRadius, style: .continuous)
                )
            }
            VStack(alignment: .leading, spacing: 8) {
                TextField(uappLocalized("comments.field"), text: $commentBody, axis: .vertical)
                    .lineLimit(3 ... 8).focused($focusedField, equals: .comment).disabled(isSending)
                HStack(alignment: .bottom) {
                    UAPPFeedbackImagePicker(data: $commentImage, isProcessing: $isProcessingImage).disabled(isSending)
                    Spacer()
                    if replyingTo != nil || !commentBody.isEmpty || !commentImage.isEmpty {
                        Button { discardCommentDraft() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(resolvedAccent)
                                .frame(width: 32, height: 32)
                                .background(palette.secondaryText.opacity(0.07), in: Circle())
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isSending || isProcessingImage || participation.isBusy)
                        .accessibilityLabel(Text(verbatim: uappLocalized("comments.discard_draft")))
                    }
                    Button { Task { await participation.perform { await submitComment() } } } label: {
                        if isSending {
                            ProgressView().controlSize(.small).frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .semibold)).frame(width: 32, height: 32)
                                .foregroundStyle(canSend ? Color.white : palette.secondaryText)
                                .background(canSend ? resolvedAccent : palette.secondaryText.opacity(0.07), in: Circle())
                        }
                    }
                    .frame(width: 44, height: 44).contentShape(Rectangle())
                    .buttonStyle(.plain).disabled(!canSend)
                    .accessibilityLabel(Text(verbatim: uappLocalized("common.send")))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .background(UAPPFieldBackground(
                isFocused: focusedField == .comment,
                accent: resolvedAccent,
                palette: palette,
                cornerRadius: 20
            ))
        }
    }

    private var commentsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if let commentsError {
                VStack(alignment: .leading, spacing: 10) {
                    UAPPInlineBanner(message: uappLocalized(commentsError), style: .error, accent: resolvedAccent)
                    Button {
                        Task { await refresh(showError: true) }
                    } label: {
                        UAPPSecondaryButtonLabel(
                            title: uappLocalized("common.retry"),
                            systemImage: "arrow.clockwise",
                            accent: resolvedAccent,
                            expands: false,
                            minHeight: 44
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshing)
                }
            } else if comments.isEmpty {
                HStack(spacing: 12) {
                    UAPPAccentIconBadge(
                        systemImage: "bubble.left.and.bubble.right",
                        accent: resolvedAccent,
                        size: 40,
                        cornerRadius: 12,
                        font: .body.weight(.semibold)
                    )
                    Text(verbatim: uappLocalized("comments.empty"))
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .uappCardSurface(palette)
            }
            ForEach(UAPPCommentThread.rows(comments), id: \.comment.id) { row in
                commentRow(row.comment).padding(.leading, CGFloat(min(row.depth, 3)) * 16)
            }
        }
    }

    private func discardCommentDraft() {
        commentBody = ""
        commentImage = []
        replyingTo = nil
        message = nil
        focusedField = nil
    }

    private func commentRow(_ comment: UAPPComment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            UAPPFeedbackAvatar(name: displayName(comment), url: comment.avatarURL(viewer: participation.session?.identity), size: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { commentHeading(comment); dateLabel(comment.createdAt) }
                    VStack(alignment: .leading, spacing: 4) { commentHeading(comment); dateLabel(comment.createdAt) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    if comment.moderationState == "pending" {
                        pendingCommentSkeleton
                        Text(verbatim: uappLocalized("comments.pending"))
                            .font(.caption).foregroundStyle(palette.secondaryText)
                            .padding(.top, 6)
                    } else {
                        UAPPFeedbackTranslatedText(text: comment.body)
                            .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                        if !comment.attachmentURLs.isEmpty {
                            UAPPFeedbackImageGallery(urls: comment.attachmentURLs).padding(.top, 6)
                        }
                        HStack {
                            Button(uappLocalized("comments.reply")) { replyingTo = comment }
                                .font(.subheadline).frame(minHeight: 44)
                                .foregroundStyle(resolvedAccent)
                                .tint(resolvedAccent)
                            Spacer()
                            Button { Task { await participation.perform { await toggleCommentVote(comment) } } } label: {
                                reactionLabel(count: comment.voteCount, selected: comment.viewerVoted)
                            }
                            .buttonStyle(.plain).disabled(reactingComments.contains(comment.id) || participation.isBusy)
                            .accessibilityLabel(Text(verbatim: uappLocalizedFormat("feedback.votes_count", comment.voteCount)))
                            .accessibilityAddTraits(comment.viewerVoted ? [.isSelected] : [])
                        }
                        .foregroundStyle(palette.secondaryText)
                    }
                }
            }
        }
    }

    private var pendingCommentSkeleton: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(palette.secondaryText.opacity(0.12))
                .frame(maxWidth: 240).frame(height: 12)
            RoundedRectangle(cornerRadius: 4)
                .fill(palette.secondaryText.opacity(0.12))
                .frame(maxWidth: 160).frame(height: 12)
        }
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }

    private func reactionLabel(count: Int, selected: Bool) -> some View {
        Label(count.formatted(), systemImage: "arrow.up")
            .font(.caption.weight(.semibold)).monospacedDigit()
            .padding(.horizontal, 10).frame(height: 32)
            .background(selected ? resolvedAccent.opacity(0.12) : palette.cardBackground, in: Capsule())
            .overlay(Capsule().strokeBorder(palette.separator, lineWidth: 1))
            .padding(.vertical, 6).contentShape(Rectangle())
    }

    private func commentHeading(_ comment: UAPPComment) -> some View {
        Text(verbatim: displayName(comment)).font(.subheadline.weight(.semibold))
    }

    private func dateLabel(_ date: Date) -> some View {
        Text(date, format: .dateTime.day().month(.abbreviated).year())
            .font(.caption).foregroundStyle(palette.secondaryText)
    }

    private var authorName: String {
        normalizedName(item.authorName, fallback: "comments.community")
    }

    private func displayName(_ comment: UAPPComment) -> String {
        normalizedName(comment.authorName, fallback: comment.authorKind == .team ? "comments.team" : "comments.community")
    }

    private func normalizedName(_ name: String?, fallback: String) -> String {
        let value = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? uappLocalized(fallback) : value
    }

    private func refresh(showError: Bool = false) async {
        // Uma atualização após envio aguarda a consulta anterior e busca de novo.
        while isRefreshing {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
        }
        guard !Task.isCancelled else { return }
        isRefreshing = true
        defer { isRefreshing = false; isLoading = false }
        do {
            let updated = try await client.allComments(itemId: item.id)
            try Task.checkCancellation()
            if comments != updated {
                comments = updated
            }
            commentsError = nil
        } catch is CancellationError { return }
        catch {
            if showError || comments.isEmpty {
                commentsError = "detail.comments_load_error"
            }
        }
        do {
            let page = try await client.feedbackPage(itemId: item.id)
            try Task.checkCancellation()
            if let updated = page.items.first(where: { $0.id == item.id }) {
                isAvailable = true
                item = updated
                status = page.statuses.first { $0.id == updated.statusId }
                onUpdate(updated)
            } else {
                isAvailable = false
                comments = []
            }
        } catch UAPPKitError.http(status: 403, _) {
            isAvailable = false
            comments = []
        } catch UAPPKitError.http(status: 404, _) {
            isAvailable = false
            comments = []
        } catch {
            // Temporary failures preserve the last known public content.
        }
    }

    private func toggleVote() async {
        guard pendingReaction == nil else { return }
        pendingReaction = .vote
        defer { pendingReaction = nil }
        do {
            try await client.setReaction(itemId: item.id, kind: .vote, enabled: !item.viewerVoted)
            await refresh(showError: true)
        } catch { message = "detail.reaction_error" }
    }

    private func toggleCommentVote(_ comment: UAPPComment) async {
        guard reactingComments.insert(comment.id).inserted else { return }
        defer { reactingComments.remove(comment.id) }
        do {
            try await client.setReaction(itemId: item.id, commentId: comment.id, kind: .vote, enabled: !comment.viewerVoted)
            await refresh(showError: true)
        } catch { message = "detail.reaction_error" }
    }

    private func submitComment() async {
        let body = commentBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !isSending, !isProcessingImage else { return }
        isSending = true
        defer { isSending = false }
        do {
            _ = try await client.submitComment(
                itemId: item.id,
                body: body,
                parentCommentId: replyingTo?.id,
                imagesData: commentImage
            )
            commentBody = ""
            commentImage = []
            replyingTo = nil
            focusedField = nil
            message = "detail.comment_submitted"
            await refresh(showError: true)
        } catch { message = "detail.comment_error" }
    }
}

enum UAPPCommentThread {
    struct Row {
        let comment: UAPPComment
        let depth: Int
    }

    /// Pais antes das respostas; comentários órfãos/ciclos continuam visíveis.
    static func rows(_ comments: [UAPPComment]) -> [Row] {
        let ids = Set(comments.map(\.id))
        let children = Dictionary(grouping: comments, by: { $0.parentCommentId ?? "" })
        let roots = comments.filter { comment in
            guard let parent = comment.parentCommentId else { return true }
            return !ids.contains(parent)
        }
        var seen: Set<String> = []
        var result: [Row] = []
        func append(_ comment: UAPPComment, depth: Int) {
            var stack = [Row(comment: comment, depth: depth)]
            while let row = stack.popLast() {
                guard seen.insert(row.comment.id).inserted else { continue }
                result.append(row)
                stack.append(contentsOf: (children[row.comment.id] ?? []).reversed().map {
                    Row(comment: $0, depth: row.depth + 1)
                })
            }
        }
        for root in roots {
            append(root, depth: 0)
        }
        for comment in comments where !seen.contains(comment.id) {
            append(comment, depth: 0)
        }
        return result
    }
}
#endif
