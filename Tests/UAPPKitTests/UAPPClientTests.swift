import Foundation
import Testing
@testable import UAPPKit

@Test("feedback com anexos envia os bytes da foto do perfil sem arquivo local")
func clientFeedbackIncludesProfilePhotoBytes() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in response(#"{"ok":true,"id":"feedback"}"#) }
    let photo = Data([0xFF, 0xD8, 0xFF, 0xD9])
    await client.setIdentity(UAPPIdentity(userId: "profile", displayName: "Visitante", avatarData: photo))
    _ = try await client.submitFeedback(title: "Novo feedback", imagesData: [])
    let body = try #require(recorder.requests.first?.httpBody)
    let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    let avatar = try #require(payload["profilePhoto"] as? [String: String])
    #expect(avatar["base64"] == photo.base64EncodedString())
    #expect(avatar["mimeType"] == "image/jpeg")
    #expect(payload["image"] == nil)
    #expect(payload["images"] == nil)
}

@Test("foto do perfil inválida falha antes de enviar")
func clientFeedbackRejectsInvalidProfilePhotoBytes() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in response(#"{"ok":true}"#) }
    await client.setIdentity(UAPPIdentity(userId: "profile", avatarData: Data("not an image".utf8)))
    await #expect(throws: UAPPKitError.invalidResponse) {
        try await client.submitFeedback(title: "Novo feedback", imagesData: [])
    }
    #expect(recorder.requests.isEmpty)
}

@Test("feedback envia foto local, nome e e-mail sem exigir conta")
func clientFeedbackIncludesLocalProfilePhoto() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
    let photo = Data([0xFF, 0xD8, 0xFF, 0xD9])
    try photo.write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in response(#"{"ok":true,"id":"feedback"}"#) }
    await client.setIdentity(UAPPIdentity(userId: "profile", email: "visitor@example.test",
                                         displayName: "Visitante", avatarURL: url))
    _ = try await client.submitFeedback(title: "Novo feedback")
    let request = try #require(recorder.requests.first)
    let body = try #require(request.httpBody)
    let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    let avatar = try #require(payload["profilePhoto"] as? [String: String])
    #expect(payload["email"] as? String == "visitor@example.test")
    #expect(payload["displayName"] as? String == "Visitante")
    #expect(avatar["base64"] == photo.base64EncodedString())
    #expect(avatar["mimeType"] == "image/jpeg")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)

    await client.setIdentity(UAPPIdentity(userId: "profile", displayName: "Visitante"))
    _ = try await client.submitFeedback(title: "Sem foto")
    let second = try #require(recorder.requests.last?.httpBody)
    let withoutPhoto = try #require(JSONSerialization.jsonObject(with: second) as? [String: Any])
    #expect(withoutPhoto["profilePhoto"] is NSNull)
}

@Test("foto local acima do limite impede envio do feedback")
func clientFeedbackRejectsOversizedProfilePhoto() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
    try Data(repeating: 0, count: 512 * 1024 + 1).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in response(#"{"ok":true}"#) }
    await client.setIdentity(UAPPIdentity(userId: "profile", avatarURL: url))
    await #expect(throws: UAPPKitError.invalidResponse) {
        try await client.submitFeedback(title: "Novo feedback")
    }
    #expect(recorder.requests.isEmpty)
}

@Test("cliente guarda e limpa a identidade corrente")
func clientStoresAndClearsIdentity() async {
    let client = makeClient { _ in response(#"{"ok":true}"#) }
    let identity = UAPPIdentity(userId: "u1", displayName: "Renato")

    await client.setIdentity(identity)
    #expect(await client.currentIdentity() == identity)
    await client.setIdentity(nil)
    #expect(await client.currentIdentity() == nil)
}

@Test("feedback envia paginação, assinatura e atualiza o projeto")
func clientFeedbackSendsPaginationAndSignature() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(
        recorder: recorder,
        signatureProvider: { "signed-token" }
    ) { _ in
        response("""
        {"ok":true,"project":{"slug":"meu-app","displayName":"Meu App"},"items":[],"nextCursor":"cursor-2"}
        """)
    }

    let page = try await client.feedbackPage(limit: 12, cursor: "cursor-1")
    let request = try #require(recorder.requests.first)
    #expect(page.items.isEmpty)
    #expect(page.statuses.isEmpty)
    #expect(page.nextCursor == "cursor-2")
    #expect(queryValue("slug", in: request) == "meu-app")
    #expect(queryValue("resource", in: request) == "feedback")
    #expect(queryValue("limit", in: request) == "12")
    #expect(queryValue("cursor", in: request) == "cursor-1")
    #expect(request.value(forHTTPHeaderField: "x-uapp-signature") == "Bearer signed-token")
    #expect(await client.currentProject()?.displayName == "Meu App")
}

@Test("feedback expõe status ordenados e preserva autor e cor opcionais")
func clientFeedbackPreservesCardMetadata() async throws {
    let client = makeClient { _ in
        response("""
        {"statuses":[
          {"id":"done","key":"shipped","name":"Concluído","position":2,"color":"#28734D"},
          {"id":"planned","key":"planned","name":"Planejado","position":1}],
         "items":[{"id":"1","title":"Ideia","body":null,"status_id":"planned",
          "vote_count":3,"like_count":0,"public_comment_count":2,"priority":0,
          "viewer_voted":false,"viewer_liked":false,"author_name":"Ana",
          "author_avatar_url":"https://example.test/photo.jpg"}]}
        """)
    }
    let page = try await client.feedbackPage()
    #expect(page.statuses.map(\.id) == ["planned", "done"])
    #expect(page.statuses.first?.color == nil)
    #expect(page.statuses.last?.color == "#28734D")
    #expect(page.items.first?.authorName == "Ana")
    #expect(page.items.first?.authorAvatarURL?.host == "example.test")
    #expect(page.items.first?.statusId == "planned")
}

@Test("roadmap preserva autor, foto e data dos cards")
func clientRoadmapPreservesCardMetadata() async throws {
    let client = makeClient { _ in
        response("""
        {"statuses":[{"id":"planned","key":"planned","name":"Planejado","position":1}],
         "items":[{"id":"1","title":"Ideia","body":null,"status_id":"planned",
          "vote_count":3,"like_count":0,"public_comment_count":2,"priority":0,
          "viewer_voted":false,"viewer_liked":false,"author_name":"Ana",
          "author_avatar_url":"https://example.test/photo.jpg","created_at":"2026-10-01T12:00:00Z"}]}
        """)
    }
    let item = try #require(try await client.roadmap().first?.items.first)
    #expect(item.authorName == "Ana")
    #expect(item.authorAvatarURL?.host == "example.test")
    #expect(item.statusId == "planned")
    #expect(item.createdAt != nil)
}

@Test("cliente envia o idioma atual no Accept-Language")
func clientSendsCurrentLocale() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(
        recorder: recorder,
        locale: Locale(identifier: "de")
    ) { _ in
        response(#"{"ok":true,"items":[],"nextCursor":null}"#)
    }

    _ = try await client.feedback()
    let request = try #require(recorder.requests.first)
    #expect(request.value(forHTTPHeaderField: "Accept-Language") == "de")

    await client.setLocale(Locale(identifier: "ja"))
    _ = try await client.feedback()
    let updatedRequest = try #require(recorder.requests.last)
    #expect(updatedRequest.value(forHTTPHeaderField: "Accept-Language") == "ja")
}

@Test("roadmap filtra status invisível, ordena e agrupa itens")
func clientRoadmapFiltersAndSorts() async throws {
    let client = makeClient { _ in
        response("""
        {"project":{"slug":"meu-app"},"statuses":[
          {"id":"done","key":"done","name":"Feito","position":2,"isRoadmapVisible":true},
          {"id":"hidden","key":"hidden","name":"Oculto","position":0,"isRoadmapVisible":false},
          {"id":"todo","key":"todo","name":"A fazer","position":1,"isRoadmapVisible":null}],
         "items":[
          {"id":"2","title":"Tarefa","body":null,"status_id":"done","vote_count":2,"like_count":1,"public_comment_count":0,"category":"bug","priority":4,"viewer_voted":false,"viewer_liked":true},
          {"id":"1","title":"Ideia","body":"Texto","status_id":"hidden","vote_count":1,"like_count":0,"public_comment_count":2,"category":"feature","priority":8,"viewer_voted":true,"viewer_liked":false}]}
        """)
    }

    let columns = try await client.roadmap(limit: 30)
    #expect(columns.map(\.status.key) == ["todo", "done"])
    #expect(columns[0].items.isEmpty)
    #expect(columns[1].items.first?.title == "Tarefa")
    #expect(columns[1].items.first?.createdAt == nil)
}

@Test("changelog envia todos os filtros e retorna metadados")
func clientChangelogSendsFilters() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in
        response("""
        {"project":{"slug":"meu-app"},"entries":[],"nextCursor":null,"totalCount":42}
        """)
    }
    let filters = UAPPChangelogFilters(category: .new, platform: .ios, version: "1.2", build: "3", from: "2026-01-01", to: "2026-02-01")

    let page = try await client.changelogPage(limit: 7, cursor: "old", filters: filters)
    let request = try #require(recorder.requests.first)
    #expect(page.entries.isEmpty)
    #expect(page.totalCount == 42)
    #expect(queryValue("resource", in: request) == "changelog")
    #expect(queryValue("category", in: request) == "new")
    #expect(queryValue("platform", in: request) == "ios")
    #expect(queryValue("version", in: request) == "1.2")
    #expect(queryValue("build", in: request) == "3")
    #expect(queryValue("from", in: request) == "2026-01-01")
    #expect(queryValue("to", in: request) == "2026-02-01")
}

@Test("comments inclui item e cursor na consulta")
func clientCommentsIncludesItemAndCursor() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in
        response("""
        {"comments":[{"id":"c1","body":"Oi","parentCommentId":null,"likeCount":1,"createdAt":"2026-09-07T12:00:00Z","authorKind":"community","viewerLiked":false}],"nextCursor":"next"}
        """)
    }

    let page = try await client.comments(itemId: "feedback-1", limit: 4, cursor: "cursor")
    let request = try #require(recorder.requests.first)
    #expect(page.comments.first?.id == "c1")
    #expect(page.nextCursor == "next")
    #expect(queryValue("resource", in: request) == "comments")
    #expect(queryValue("itemId", in: request) == "feedback-1")
    #expect(queryValue("cursor", in: request) == "cursor")
}

@Test("reviewsPage envia cursor e decodifica resposta do desenvolvedor")
func clientReviewsPageDecodesResponse() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in
        response(#"{"reviews":[{"id":"r1","rating":5,"response_body":"Obrigado!"}],"nextCursor":"next"}"#)
    }
    let page = try await client.reviewsPage(cursor: "previous")
    let request = try #require(recorder.requests.first)
    #expect(queryValue("cursor", in: request) == "previous")
    #expect(queryValue("limit", in: request) == "20")
    #expect(page.nextCursor == "next")
    #expect(page.reviews.first?.responseBody == "Obrigado!")
    #expect(page.reviews.first?.reviewedAt == nil)
}

@Test("reviewsPage propaga erros HTTP e de decodificação")
func clientReviewsPagePropagatesErrors() async {
    let httpClient = makeClient { _ in response(503, #"{"error":"Offline"}"#) }
    await #expect(throws: UAPPKitError.self) { try await httpClient.reviewsPage() }
    let invalidClient = makeClient { _ in response(#"{"reviews":[{"id":"r1"}]}"#) }
    await #expect(throws: UAPPKitError.self) { try await invalidClient.reviewsPage() }
}

@Test("reviews e about decodificam projeto e conteúdo opcional")
func clientReviewsAndAboutDecodeContent() async throws {
    let client = makeClient { request in
        if queryValue("resource", in: request) == "reviews" {
            return response("""
            {"project":{"slug":"meu-app"},"reviews":[{"id":"r1","rating":5,"title":"Ótimo","body":"Bom","reviewer_nickname":"Ana","reviewed_at":"2026-09-24T12:00:00Z"}]}
            """)
        }
        return response("""
        {"project":{"slug":"meu-app","iconUrl":"https://cdn.example/icon.png","publicBaseURL":"https://public.example"},"about":{"developer_name":"Renato","developer_image_url":null,"developer_bio":"Bio","about_apps":[],"social_links":{"youtube":"https://youtube.com/@uapp"}}}
        """)
    }

    let reviews = try await client.reviews(limit: 2)
    let about = try await client.about()
    #expect(reviews.first?.reviewerName == "Ana")
    #expect(about.developerName == "Renato")
    #expect(about.socialLinks["youtube"]?.host == "youtube.com")
    #expect(await client.currentProject()?.iconURL?.host == "cdn.example")
}

@Test("cliente encontra o link de avaliação na lista de apps do desenvolvedor")
func clientFindsAppStoreReviewInAboutApps() async throws {
    let payload = """
    {"project":{"slug":"calcjuros-dev","displayName":"CalcJuros"},"about":{"developer_name":"Renato","about_apps":[{"name":"CalcJuros","subtitle":null,"appStoreURL":"https://apps.apple.com/app/id123456789","appleAppId":123456789,"iconURL":null}],"social_links":{}}}
    """
    let envelope = try JSONDecoder().decode(UAPPAboutResponse.self, from: json(payload))
    #expect(envelope.about.apps.first?.appleAppId == "123456789")

    let client = makeClient { _ in
        response(payload)
    }

    let destination = try await client.appStoreReviewDestination()
    #expect(destination?.absoluteString == "itms-apps://itunes.apple.com/app/id123456789?action=write-review")
}

@Test("cliente usa somente o Apple App ID configurado no projeto")
func clientUsesProjectAppleAppIdWithoutStoreURL() async throws {
    let payload = """
    {"project":{"slug":"calcjuros-dev","displayName":"CalcJuros","apple_app_id":987654321},"about":{"developer_name":"Renato","about_apps":[],"social_links":{}}}
    """
    let client = makeClient { _ in response(payload) }

    let destination = try await client.appStoreReviewDestination()
    #expect(destination?.absoluteString == "itms-apps://itunes.apple.com/app/id987654321?action=write-review")
}

@Test("erro HTTP atualiza projeto e preserva mensagem")
func clientHTTPErrorUpdatesProject() async {
    let client = makeClient { _ in
        response(403, """
        {"error":"Conteúdo não público.","project":{"slug":"meu-app","primaryColor":"#2D7A52"}}
        """)
    }

    do {
        _ = try await client.feedback()
        Issue.record("era esperado um erro HTTP")
    } catch let error as UAPPKitError {
        #expect(error == .http(status: 403, message: "Conteúdo não público."))
    } catch {
        Issue.record("erro inesperado: \(error)")
    }
    #expect(await client.currentProject()?.primaryColor == "#2D7A52")
}

@Test("resposta inválida gera invalidResponse em leituras e escritas")
func clientInvalidResponsesAreTyped() async {
    let client = makeClient { _ in response("not json") }

    do {
        _ = try await client.changelog()
        Issue.record("era esperado invalidResponse")
    } catch {
        #expect(error as? UAPPKitError == .invalidResponse)
    }
    do {
        _ = try await client.submitComment(itemId: "i", body: "comentário")
        Issue.record("era esperado invalidResponse no POST")
    } catch {
        #expect(error as? UAPPKitError == .invalidResponse)
    }
}

@Test("submit feedback envia identidade, corpo e assinatura")
func clientSubmitFeedbackSendsIdentityAndBody() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder, signatureProvider: { "token" }) { _ in
        response(201, #"{"ok":true,"id":"fb-1"}"#)
    }
    await client.setIdentity(UAPPIdentity(userId: "u", email: "u@example.test", displayName: "Renato"))

    let id = try await client.submitFeedback(title: " Bug no login ", body: " Detalhes ", category: .bug)
    let request = try #require(recorder.requests.first)
    let bodyData = try #require(request.httpBody)
    let payload = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
    #expect(id == "fb-1")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "x-uapp-project") == "meu-app")
    #expect(request.value(forHTTPHeaderField: "idempotency-key") != nil)
    #expect(request.value(forHTTPHeaderField: "x-uapp-signature") == "Bearer token")
    #expect(payload["slug"] as? String == "meu-app")
    #expect(payload["title"] as? String == " Bug no login ")
    #expect(payload["body"] as? String == " Detalhes ")
    #expect(payload["category"] as? String == "bug")
    #expect(payload["email"] as? String == "u@example.test")
    #expect(payload["displayName"] as? String == "Renato")
    #expect(UUID(uuidString: payload["installationId"] as? String ?? "") != nil)
}

@Test("reação envia like e comentário opcional")
func clientReactionSendsLikeAndComment() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in
        response(#"{"ok":true,"enabled":false}"#)
    }

    try await client.setReaction(itemId: "item", commentId: "comment", kind: .vote, enabled: false)
    let request = try #require(recorder.requests.first)
    let bodyData = try #require(request.httpBody)
    let payload = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
    #expect(request.url?.path.hasSuffix("/public-feedback-interact") == true)
    #expect(payload["itemId"] as? String == "item")
    #expect(payload["commentId"] as? String == "comment")
    #expect(payload["action"] as? String == "vote")
    #expect(payload["enabled"] as? Bool == false)
}

@Test("comentário envia pai e nome de exibição e retorna id")
func clientSubmitCommentSendsParentAndDisplayName() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in
        response(#"{"ok":true,"id":"comment-1"}"#)
    }
    await client.setIdentity(UAPPIdentity(userId: "u", displayName: "Renato"))

    let id = try await client.submitComment(itemId: "item", body: "Oi", parentCommentId: "parent")
    let request = try #require(recorder.requests.first)
    let bodyData = try #require(request.httpBody)
    let payload = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
    #expect(id == "comment-1")
    #expect(payload["action"] as? String == "comment")
    #expect(payload["body"] as? String == "Oi")
    #expect(payload["parentCommentId"] as? String == "parent")
    #expect(payload["displayName"] as? String == "Renato")
}

@Test("provedor de assinatura propaga falhas")
func signatureProviderPropagatesFailure() async {
    let client = makeClient(signatureProvider: { throw TestError.expected }) { _ in
        response(#"{"ok":true,"items":[]}"#)
    }

    do {
        _ = try await client.feedback()
        Issue.record("era esperado o erro do provedor")
    } catch {
        #expect(error is TestError)
    }
}
