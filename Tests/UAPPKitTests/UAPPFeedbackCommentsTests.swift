import Foundation
import Testing
@testable import UAPPKit

@Test("Comentários aceitam datas ISO com e sem frações de segundo", arguments: [
    "2026-10-02T12:00:00Z",
    "2026-10-02T12:00:00.123Z",
    "2026-10-02T12:00:00.123456+00:00"
])
func feedbackCommentsDecodeTimestamp(timestamp: String) async throws {
    let client = makeClient { _ in
        response("""
        {"comments":[{"id":"comment","body":"Publicado","parentCommentId":null,"likeCount":0,"createdAt":"\(timestamp)","authorKind":"team","viewerLiked":false}],"nextCursor":null}
        """)
    }
    let comments = try await client.allComments(itemId: "item")
    let comment = try #require(comments.first)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: comment.createdAt)
    #expect(components.year == 2026)
    #expect(components.month == 10)
    #expect(components.day == 2)
    #expect(components.hour == 12)
    #expect(components.minute == 0)
    #expect(components.second == 0)
    if timestamp.contains(".123") {
        #expect(abs(comment.createdAt.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) - 0.123) < 0.001)
    }
}

@Test("Data inválida informa erro em vez de descartar os comentários")
func feedbackCommentsRejectInvalidTimestamp() async {
    let client = makeClient { _ in
        response(#"{"comments":[{"id":"comment","body":"Publicado","parentCommentId":null,"likeCount":0,"createdAt":"invalid","authorKind":"team","viewerLiked":false}],"nextCursor":null}"#)
    }
    await #expect(throws: UAPPKitError.invalidResponse) { try await client.allComments(itemId: "item") }
}

@Test("Atualização carrega a última página de comentários publicados")
func feedbackCommentsLoadAllPages() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { request in
        if queryValue("cursor", in: request) == "next" {
            return response(#"{"comments":[{"id":"new","body":"Publicado agora","parentCommentId":null,"likeCount":0,"createdAt":"2026-10-02T12:00:00Z","authorKind":"team","viewerLiked":false}],"nextCursor":null}"#)
        }
        return response(#"{"comments":[{"id":"old","body":"Anterior","parentCommentId":null,"likeCount":0,"createdAt":"2026-10-01T12:00:00Z","authorKind":"community","viewerLiked":false}],"nextCursor":"next"}"#)
    }
    let comments = try await client.allComments(itemId: "item")
    #expect(comments.map(\.id) == ["old", "new"])
    #expect(recorder.requests.count == 2)
    #expect(recorder.requests.allSatisfy { queryValue("itemId", in: $0) == "item" })
}

@Test("Paginação repetida encerra com erro em vez de repetir indefinidamente")
func feedbackCommentsRejectRepeatedCursor() async {
    let client = makeClient { _ in response(#"{"comments":[],"nextCursor":"same"}"#) }
    await #expect(throws: UAPPKitError.invalidResponse) { try await client.allComments(itemId: "item") }
}

@Test("Falha na última página não entrega uma conversa parcial")
func feedbackCommentsPropagatePageError() async {
    let client = makeClient { request in
        queryValue("cursor", in: request) == nil
            ? response(#"{"comments":[],"nextCursor":"next"}"#)
            : (503, Data(#"{"error":"Indisponível"}"#.utf8))
    }
    await #expect(throws: UAPPKitError.http(status: 503, message: "Indisponível")) {
        try await client.allComments(itemId: "item")
    }
}

@Test("Detalhes consultam o item específico, mesmo fora da primeira página")
func feedbackDetailFiltersItem() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in response(#"{"items":[],"nextCursor":null}"#) }
    _ = try await client.feedbackPage(itemId: "selected")
    let request = try #require(recorder.requests.first)
    #expect(queryValue("itemId", in: request) == "selected")
}

#if canImport(SwiftUI)
@Test("Respostas seguem o pai; órfãos e ciclos aparecem uma vez")
func feedbackCommentsGroupThreads() {
    func comment(_ id: String, parent: String? = nil) -> UAPPComment {
        UAPPComment(
            id: id,
            body: id,
            parentCommentId: parent,
            likeCount: 0,
            createdAt: Date(timeIntervalSince1970: 0),
            authorKind: .community,
            viewerLiked: false
        )
    }
    let rows = UAPPCommentThread.rows([
        comment("reply", parent: "root"), comment("root"), comment("other"),
        comment("orphan", parent: "missing"), comment("a", parent: "b"), comment("b", parent: "a")
    ])
    #expect(rows.map(\.comment.id) == ["root", "reply", "other", "orphan", "a", "b"])
    #expect(rows.map(\.depth) == [0, 1, 0, 0, 0, 1])
}
#endif
