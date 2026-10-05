import Foundation
import Testing
@testable import UAPPKit

@Test("comentários expõem votação a partir do contrato compatível")
func commentVotingUsesCompatibleTransport() {
    let comment = UAPPComment(
        id: "comment", body: "Message", likeCount: 4,
        createdAt: Date(timeIntervalSince1970: 0), authorKind: .community, viewerLiked: true
    )
    #expect(comment.voteCount == 4)
    #expect(comment.viewerVoted)
}

@Test("voto otimista usa o campo de votos sem alterar curtidas ou dados do feedback")
func feedbackOptimisticVoteKeepsOtherFields() throws {
    let original = try UAPPFeedbackItem(
        id: "item", title: "Title", body: "Body", voteCount: 2, likeCount: 7, commentCount: 3,
        category: .feature, priority: 1, viewerLiked: true,
        createdAt: Date(timeIntervalSince1970: 1), authorName: "Author",
        authorAvatarURL: URL(string: "https://example.com/avatar.jpg"), statusId: "planned",
        voters: [.init(displayName: "Voter", avatarURL: nil)],
        imageURL: URL(string: "https://example.com/image.jpg"),
        imageURLs: [#require(URL(string: "https://example.com/second.jpg"))]
    )
    let voted = original.settingVote(enabled: true)
    #expect(voted.voteCount == 3)
    #expect(voted.viewerVoted)
    #expect(voted.likeCount == 7)
    #expect(voted.viewerLiked)
    #expect(voted.settingVote(enabled: true) == voted)
    #expect(voted.settingVote(enabled: false) == original)
}

@Test("remover voto não produz contagem negativa e preserva campos opcionais ausentes")
func feedbackVoteHandlesMissingFields() {
    let inconsistent = UAPPFeedbackItem(
        id: "item", title: "Title", body: nil, voteCount: 0, likeCount: 0, commentCount: 0,
        viewerVoted: true
    )
    let removed = inconsistent.settingVote(enabled: false)
    #expect(removed.voteCount == 0)
    #expect(!removed.viewerVoted)
    #expect(removed.body == nil)
    #expect(removed.authorName == nil)
    #expect(removed.imageURLs == nil)
}
