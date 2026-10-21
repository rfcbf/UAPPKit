import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@Test("UAPPFeedbackDetailScreen constrói a view inicial")
@MainActor
func feedbackDetailScreenBuildsInitialView() async {
    let client = makeClient { _ in response(#"{"ok":true,"comments":[]}"#) }
    let item = UAPPFeedbackItem(
        id: "item",
        title: "Título",
        body: "Corpo",
        voteCount: 1,
        likeCount: 2,
        commentCount: 3
    )
    await render(UAPPFeedbackDetailScreen(client: client, item: item))
}

@Test("UAPPFeedbackDetailScreen constrói comentários publicados, skeleton pendente e estados de envio")
@MainActor
func feedbackDetailScreenBuildsLoadedState() async {
    let client = makeClient { _ in response(#"{"ok":true,"comments":[]}"#) }
    let item = UAPPFeedbackItem(
        id: "item",
        title: "Título",
        body: "Corpo",
        voteCount: 1,
        likeCount: 2,
        commentCount: 2,
        viewerVoted: true,
        viewerLiked: false
    )
    let comments = [
        UAPPComment(
            id: "team-comment",
            body: "Resposta da equipe",
            parentCommentId: nil,
            likeCount: 1,
            createdAt: Date(),
            authorKind: .team,
            viewerLiked: true
        ),
        UAPPComment(
            id: "community-comment",
            body: "Comentário da comunidade",
            parentCommentId: "team-comment",
            likeCount: 0,
            createdAt: Date(),
            authorKind: .community,
            viewerLiked: false
        ),
        UAPPComment(
            id: "pending-reply",
            body: "Resposta ainda aguardando aprovação",
            parentCommentId: "team-comment",
            likeCount: 0,
            createdAt: Date(timeIntervalSince1970: 0),
            authorKind: .community,
            viewerLiked: false,
            imageURL: URL(string: "https://example.test/pending-image.jpg"),
            moderationState: "pending"
        )
    ]

    await render(UAPPFeedbackDetailScreen(
        client: client,
        item: item,
        testingComments: comments,
        isLoading: false,
        isSending: true,
        pendingReaction: .vote,
        message: "Comentário recebido",
        commentBody: "Novo comentário"
    ))
    await render(UAPPFeedbackDetailScreen(
        client: client,
        item: item,
        testingComments: [],
        isLoading: false
    ))
}

#if canImport(UIKit) || canImport(AppKit)
@Test("UAPPFeedbackDetailScreen renderiza comentários no host SwiftUI")
@MainActor
func feedbackDetailScreenRendersLoadedContentInHost() async {
    let client = makeClient { _ in response(#"{"ok":true,"comments":[]}"#) }
    let item = UAPPFeedbackItem(
        id: "item",
        title: "Título",
        body: "Corpo",
        voteCount: 1,
        likeCount: 2,
        commentCount: 1
    )
    let comment = UAPPComment(
        id: "comment",
        body: "Comentário",
        parentCommentId: nil,
        likeCount: 1,
        createdAt: Date(),
        authorKind: .community,
        viewerLiked: false
    )
    await render(UAPPFeedbackDetailScreen(
        client: client,
        item: item,
        testingComments: [comment],
        isLoading: false
    ))
}
#endif

@Test("Detalhe mostra conteúdo indisponível, resposta em andamento, anexos e votantes")
@MainActor
func feedbackDetailScreenSecondaryStates() async throws {
    let client = makeClient { _ in response(#"{"ok":true,"comments":[]}"#) }
    let image = try temporaryFile(sampleJPEG())
    defer { try? FileManager.default.removeItem(at: image) }
    let item = UAPPFeedbackItem(
        id: "item", title: "Título", body: "Corpo", voteCount: 3, likeCount: 0, commentCount: 1,
        voters: [.init(displayName: "Ana"), .init(displayName: "Bruno", avatarURL: image)],
        imageURLs: [image]
    )
    let parent = UAPPComment(
        id: "parent", body: "Comentário", likeCount: 0, createdAt: Date(), authorKind: .community,
        viewerLiked: false, authorName: "Ana", imageURLs: [image]
    )
    await render(UAPPFeedbackDetailScreen(
        client: client, item: item, testingComments: [], isLoading: false, isAvailable: false
    ))
    await render(UAPPFeedbackDetailScreen(
        client: client, item: item, testingComments: [parent], isLoading: false,
        commentBody: "Resposta", replyingTo: parent, commentsError: "detail.comments_load_error"
    ), settling: true)
}

@Test("Detalhe trata item removido, acesso negado e falha nos comentários")
@MainActor
func feedbackDetailScreenRefreshFailures() async {
    let item = UAPPFeedbackItem(id: "item", title: "Título", body: nil, voteCount: 0, likeCount: 0, commentCount: 0)
    for status in [403, 404] {
        let client = makeClient { request in
            queryValue("resource", in: request) == "comments"
                ? response(#"{"comments":[],"nextCursor":null}"#)
                : response(status, #"{"error":"Indisponível"}"#)
        }
        await render(UAPPFeedbackDetailScreen(client: client, item: item), settling: true)
    }
    let missing = makeClient { request in
        queryValue("resource", in: request) == "comments"
            ? response(500, "{}")
            : response(#"{"items":[],"nextCursor":null}"#)
    }
    await render(UAPPFeedbackDetailScreen(client: missing, item: item), settling: true)
    let temporary = makeClient { _ in response(503, "{}") }
    await render(UAPPFeedbackDetailScreen(client: temporary, item: item), settling: true)
}
