import Foundation
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

private let publicFeedbackId = "00000000-0000-4000-8000-000000000001"
private let publicProfileJSON = #"{"author":{"name":"Ana Maria Silva","avatar_url":"https://example.test/photo.jpg"},"totals":{"likes":3,"comments":2,"feedbacks":1}}"#

@Test("reconciliação live preserva páginas carregadas e o filtro de status")
@MainActor
func livePublicProfilePreservesLoadedHistory() async throws {
    let recorder = RequestRecorder()
    let first = #"{"author":{"name":"Ana"},"totals":{"likes":2,"comments":3,"feedbacks":2},"items":[{"id":"first","title":"Feedback atualizado","state":"published","created_at":"2026-10-01T12:00:00Z"}],"nextCursor":"1"}"#
    let next = #"{"author":{"name":"Ana"},"totals":{"likes":2,"comments":3,"feedbacks":2},"items":[{"id":"second","title":"Outro feedback","state":"published","created_at":"2026-09-01T12:00:00Z"}],"nextCursor":null}"#
    let client = makeClient(recorder: recorder) { request in
        response(queryValue("cursor", in: request) == "1" ? next : first)
    }
    let model = UAPPUserModel(client: client, feedbackId: publicFeedbackId)
    let statusId = "00000000-0000-4000-8000-000000000002"
    await model.filterPublicHistory(statusId: statusId)
    await model.loadPublicProfile(loadMore: true)
    await model.reconcileActivity()
    #expect(model.history.map(\.id) == ["first", "second"])
    #expect(model.publicProfile?.totals?.comments == 3)
    #expect(model.publicProfile?.nextCursor == nil)
    #expect(try queryValue("statusId", in: #require(recorder.requests.last)) == statusId)
    #expect(recorder.requests.count == 4)
}

@Test("perfil do autor usa o request público, sem token pessoal ou e-mail")
func authorProfileUsesPublicRequest() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in response(publicProfileJSON) }
    await client.setIdentity(.init(userId: "viewer", email: "private@example.test"))
    let profile = try await client.authorProfile(for: publicFeedbackId)
    let request = try #require(recorder.requests.first)
    #expect(request.url?.lastPathComponent == "public-author-profile")
    #expect(queryValue("itemId", in: request) == publicFeedbackId)
    #expect(queryValue("slug", in: request) == "meu-app")
    #expect(request.value(forHTTPHeaderField: "x-uapp-project") == "meu-app")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(request.httpBody == nil)
    #expect(profile.author.name == "Ana Maria Silva")
    #expect(profile.author.avatarURL?.host == "example.test")
    #expect(profile.totals?.likes == 3)
    #expect(profile.totals?.comments == 2)
    #expect(profile.totals?.feedbacks == 1)
}

@Test("perfil público aceita foto ausente e totais indisponíveis sem fabricar zeros")
func authorProfileHandlesOptionalData() async throws {
    let client = makeClient { _ in response(#"{"author":{"name":"Comunidade"},"totals":null}"#) }
    let profile = try await client.authorProfile(for: publicFeedbackId)
    #expect(profile.author.avatarURL == nil)
    #expect(profile.totals == nil)
    #expect(profile.items.isEmpty)
    #expect(profile.nextCursor == nil)
    #expect(profile.statuses.isEmpty)
}

@Test("filtro público reinicia a paginação e mantém as estatísticas do autor")
@MainActor
func publicProfileFiltersHistoryByStatus() async throws {
    let recorder = RequestRecorder()
    let statusId = "00000000-0000-4000-8000-000000000002"
    let fixture = #"{"author":{"name":"Ana"},"totals":{"likes":1,"comments":2,"feedbacks":8},"items":[{"id":"filtered","title":"Feedback","body":"Descrição pública","state":"published","status_id":"00000000-0000-4000-8000-000000000002","status_key":"reviewing","like_count":3,"public_comment_count":4,"created_at":"2026-10-01T12:00:00Z"}],"statuses":[{"id":"00000000-0000-4000-8000-000000000002","key":"reviewing","name":"Em análise","position":1}],"nextCursor":null}"#
    let client = makeClient(recorder: recorder) { _ in response(fixture) }
    let model = UAPPUserModel(client: client, feedbackId: publicFeedbackId)
    await model.loadPublicProfile()
    await model.filterPublicHistory(statusId: statusId)
    let request = try #require(recorder.requests.last)
    #expect(queryValue("statusId", in: request) == statusId)
    #expect(queryValue("cursor", in: request) == nil)
    #expect(model.publicStatusId == statusId)
    #expect(model.publicProfile?.totals?.feedbacks == 8)
    #expect(model.publicProfile?.statuses.first?.position == 1)
    #expect(model.history.first?.body == "Descrição pública")
    #expect(model.history.first?.likeCount == 3)
    #expect(model.history.first?.commentCount == 4)
    await model.filterPublicHistory(statusId: nil)
    #expect(try queryValue("statusId", in: #require(recorder.requests.last)) == nil)
}

@Test("perfil público rejeita filtro de status inválido antes da consulta")
func publicProfileRejectsInvalidStatus() async {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in response(publicProfileJSON) }
    await #expect(throws: UAPPKitError.invalidResponse) {
        try await client.authorProfile(for: publicFeedbackId, statusId: "invalid")
    }
    #expect(recorder.requests.isEmpty)
}

@Test("perfil público acumula feedbacks paginados sem duplicar itens")
@MainActor
func publicProfileModelLoadsFeedbackHistory() async throws {
    let recorder = RequestRecorder()
    let first = #"{"author":{"name":"Ana"},"totals":{"likes":0,"comments":0,"feedbacks":2},"items":[{"id":"first","title":"Primeiro feedback","state":"published","status_key":"planned","status_name":"Planejado","created_at":"2026-10-01T12:00:00Z"}],"nextCursor":"1"}"#
    let next = #"{"author":{"name":"Ana"},"totals":{"likes":0,"comments":0,"feedbacks":2},"items":[{"id":"first","title":"Primeiro feedback","state":"published","created_at":"2026-10-01T12:00:00Z"},{"id":"second","title":"Segundo feedback","state":"published","created_at":"2026-09-01T12:00:00Z"}],"nextCursor":null}"#
    let client = makeClient(recorder: recorder) { request in
        response(queryValue("cursor", in: request) == "1" ? next : first)
    }
    let model = UAPPUserModel(client: client, feedbackId: publicFeedbackId)
    await model.loadPublicProfile()
    #expect(model.history.map(\.id) == ["first"])
    #expect(model.history.first?.statusName == "Planejado")
    await model.loadPublicProfile(loadMore: true)
    #expect(model.history.map(\.id) == ["first", "second"])
    #expect(try queryValue("cursor", in: #require(recorder.requests.last)) == "1")
    #expect(model.publicProfile?.nextCursor == nil)
    await model.loadPublicProfile(loadMore: true)
    #expect(recorder.requests.count == 2)
}

@Test("falha na próxima página mantém os feedbacks públicos já carregados")
@MainActor
func publicProfilePaginationKeepsHistoryOnFailure() async {
    let client = makeClient { request in
        if queryValue("cursor", in: request) != nil {
            throw UAPPKitError.transport("offline")
        }
        return response(#"{"author":{"name":"Ana"},"totals":{"likes":0,"comments":0,"feedbacks":2},"items":[{"id":"first","title":"Feedback","state":"published","created_at":"2026-10-01T12:00:00Z"}],"nextCursor":"1"}"#)
    }
    let model = UAPPUserModel(client: client, feedbackId: publicFeedbackId)
    await model.loadPublicProfile()
    await model.loadPublicProfile(loadMore: true)
    #expect(model.history.map(\.id) == ["first"])
    #expect(model.publicProfile?.nextCursor == "1")
    #expect(model.activityErrorKey == "user.activity_error")
}

@Test("perfil rejeita ID inválido antes de consultar a API")
func authorProfileRejectsInvalidId() async {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in response(publicProfileJSON) }
    await #expect(throws: UAPPKitError.invalidResponse) {
        try await client.authorProfile(for: "not-an-id")
    }
    #expect(recorder.requests.isEmpty)
}

@Test("perfil público propaga falhas HTTP e rejeita resposta inválida")
func authorProfileHandlesErrors() async {
    let unavailable = makeClient { _ in response(503, #"{"error":"Unavailable"}"#) }
    await #expect(throws: UAPPKitError.self) { try await unavailable.authorProfile(for: publicFeedbackId) }
    let invalid = makeClient { _ in response(#"{"author":{"name":123},"totals":null}"#) }
    await #expect(throws: UAPPKitError.invalidResponse) { try await invalid.authorProfile(for: publicFeedbackId) }
}

@Test("modelo do perfil público carrega estatísticas e nome completo sem sessão")
@MainActor
func publicProfileModelLoadsStatistics() async {
    let client = makeClient { _ in response(publicProfileJSON) }
    let model = UAPPUserModel(client: client, feedbackId: publicFeedbackId)
    await model.loadPublicProfile()
    #expect(model.publicProfile?.author.name == "Ana Maria Silva")
    #expect(model.publicProfile?.totals?.feedbacks == 1)
    #expect(model.session == nil)
    #expect(model.activity == nil)
    #expect(model.activityErrorKey == nil)
    #expect(!model.isLoadingActivity)
}

@Test("modelo público informa erro sem expor atividade da conta conectada")
@MainActor
func publicProfileModelHandlesFailure() async {
    let client = makeClient { _ in throw UAPPKitError.transport("offline") }
    let model = UAPPUserModel(client: client, feedbackId: publicFeedbackId)
    await model.loadPublicProfile()
    #expect(model.publicProfile == nil)
    #expect(model.activityErrorKey == "user.activity_error")
    #expect(model.session == nil)
    #expect(!model.isLoadingActivity)
}
