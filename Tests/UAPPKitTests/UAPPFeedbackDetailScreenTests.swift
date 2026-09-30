import SwiftUI
import Testing
@testable import UAPPKit

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

@Test("UAPPFeedbackDetailScreen constrói comentários e estados de envio")
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
