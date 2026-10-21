import Foundation
import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

private let profileFeedbackId = "7C4D1A52-0D6B-4E8B-9A3C-1F2E3D4C5B6A"
private let profileStatusId = "2B5E8F11-6C3A-4D7E-8F90-A1B2C3D4E5F6"

private let profileJSON = """
{"author":{"name":"Pessoa Pública","avatar_url":null},\
"totals":{"likes":3,"votes":5,"comments":2,"feedbacks":2},\
"statuses":[{"id":"\(profileStatusId)","key":"planned","name":"Planejado","position":1,"color":"#3366FF"}],\
"items":[\
{"id":"\(profileFeedbackId)","title":"Modo escuro","app_name":"App","state":"published","status_key":"planned",\
"status_id":"\(profileStatusId)","body":"Descrição pública","vote_count":4,"public_comment_count":2,\
"created_at":"2026-10-01T12:00:00Z"},\
{"id":"second","title":"Exportar dados","app_slug":"app","state":"pending","status_key":"custom",\
"status_name":"Personalizado","status_color":"#FF0000","created_at":"2026-09-30T12:00:00Z"},\
{"id":"third","title":"Sem status","state":"published","created_at":"2026-09-29T12:00:00Z"}],\
"nextCursor":"next"}
"""

private func profileClient(status: Int = 200, body: String = profileJSON) -> UAPPClient {
    makeClient { _ in response(status, body) }
}

@MainActor
struct UAPPUserScreenTests {
    @Test("Perfil público carrega estatísticas, histórico, filtros e paginação")
    func publicProfileRendersHistory() async {
        await render(UAPPUserScreen(
            publicIdentity: UAPPIdentity(userId: "author", displayName: "Pessoa Pública"),
            theme: .init(light: .init(accent: .purple), dark: .init(accent: .indigo)),
            client: profileClient(), feedbackId: profileFeedbackId
        ), settling: true)
        await render(UAPPUserScreen(
            publicIdentity: UAPPIdentity(
                userId: "author", displayName: nil, avatarURL: URL(fileURLWithPath: "/nonexistent/avatar.jpg")
            )
        ), settling: true)
    }

    @Test("Perfil público mostra vazio e erro com opção de repetir")
    func publicProfileEmptyAndError() async {
        await render(UAPPUserScreen(
            publicIdentity: UAPPIdentity(userId: "author", displayName: "Pessoa"),
            client: profileClient(body: #"{"author":{"name":"Pessoa"},"totals":{"comments":0,"feedbacks":0},"items":[]}"#),
            feedbackId: profileFeedbackId
        ), settling: true)
        await render(UAPPUserScreen(
            publicIdentity: UAPPIdentity(userId: "author", displayName: "Pessoa"),
            client: profileClient(status: 503, body: "{}"), feedbackId: profileFeedbackId
        ), settling: true)
    }

    @Test("Perfil local da instalação usa a identidade informada")
    func localProfileRenders() async {
        await render(UAPPUserScreen(
            profile: UAPPIdentity(userId: "local", displayName: "Visitante", avatarURL: URL(fileURLWithPath: "/nonexistent/local.jpg")),
            client: profileClient()
        ), settling: true)
    }

    @Test("Conta conectada mostra e-mail, histórico de apps e falhas")
    func accountRendersActivity() async {
        let authentication = StubAuthentication()
        let session = UAPPAuthenticationSession(
            identity: UAPPIdentity(userId: "verified", email: "person@example.test", displayName: "Pessoa Conectada"),
            accessToken: "token"
        )
        await authentication.setSession(session)
        await render(UAPPUserScreen(
            session: session, authentication: authentication, client: profileClient()
        ), settling: true)
        await render(UAPPUserScreen(
            session: session, authentication: authentication,
            client: profileClient(body: #"{"totals":{"comments":0,"feedbacks":0},"items":[],"nextCursor":null}"#)
        ), settling: true)
        await render(UAPPUserScreen(
            session: session, authentication: authentication, client: profileClient(status: 500, body: "{}")
        ), settling: true)
        await render(UAPPUserScreen(session: session, authentication: authentication), settling: true)
        let emailOnly = UAPPAuthenticationSession(
            identity: UAPPIdentity(userId: "verified", email: "person@example.test"), accessToken: "token"
        )
        await render(UAPPUserScreen(session: emailOnly, authentication: authentication), settling: true)
    }

    @Test("Conta com suporte a foto mostra o avatar editável com a foto atual")
    func accountRendersEditablePhoto() async {
        let session = UAPPAuthenticationSession(
            identity: UAPPIdentity(
                userId: "verified",
                email: "person@example.test",
                displayName: "Pessoa Conectada",
                avatarURL: URL(string: "https://example.test/avatar.jpg")
            ),
            accessToken: "fake-token"
        )
        await render(UAPPUserScreen(
            session: session,
            authentication: AccountProviderStub(),
            client: profileClient()
        ), settling: true)
        let withoutPhoto = UAPPAuthenticationSession(identity: UAPPIdentity(userId: "verified"), accessToken: "fake-token")
        await render(UAPPUserScreen(session: withoutPhoto, authentication: AccountProviderStub()), settling: true)
    }

    @Test("Botão de editar perfil só aparece na conta conectada com ação do aplicativo")
    func editProfileButtonVisibility() async {
        let session = UAPPAuthenticationSession(
            identity: UAPPIdentity(userId: "verified", email: "person@example.test", displayName: "Pessoa Conectada"),
            accessToken: "fake-token"
        )
        let authentication = StubAuthentication()
        await authentication.setSession(session)
        let withAction = UAPPUserScreen(
            session: session, authentication: authentication, client: profileClient(),
            onSessionChange: { _ in }, onEditProfile: {}
        )
        #expect(withAction.showsEditProfile)
        await render(withAction, settling: true)

        // A closure final continua indo para `onSessionChange`, como antes da nova ação.
        let withoutAction = UAPPUserScreen(session: session, authentication: authentication) { _ in }
        #expect(!withoutAction.showsEditProfile)

        let publicProfile = UAPPUserScreen(publicIdentity: UAPPIdentity(userId: "author", displayName: "Pessoa"))
        #expect(!publicProfile.showsEditProfile)
        let localProfile = UAPPUserScreen(profile: UAPPIdentity(userId: "local"), client: profileClient())
        #expect(!localProfile.showsEditProfile)
    }

    @Test("Estatísticas e histórico usam o termo requisições em todos os idiomas")
    func requestTermsInEveryLanguage() {
        #expect(uappLocalized("user.requests", languageIdentifier: "pt-BR") == "Requisições")
        #expect(uappLocalized("user.history", languageIdentifier: "pt-BR") == "Histórico de requisições")
        #expect(uappLocalized("user.history_empty", languageIdentifier: "pt-BR") == "Você ainda não enviou requisições.")
        #expect(uappLocalized("user.requests", languageIdentifier: "en") == "Requests")
        #expect(uappLocalized("user.history", languageIdentifier: "en") == "Request history")
        #expect(uappLocalized("user.edit_profile", languageIdentifier: "pt-BR") == "Editar perfil")
        for language in UAPPLanguage.supported.map(\.identifier) {
            #expect(uappLocalized("user.edit_profile", languageIdentifier: language) != "user.edit_profile")
            for key in ["user.requests", "user.history", "user.history_empty"] {
                #expect(!uappLocalized(key, languageIdentifier: language).localizedCaseInsensitiveContains("feedback"))
            }
        }
    }

    @Test("Destino do perfil carrega o item, informa falha e item ausente")
    func profileFeedbackDestination() async {
        let item = #"{"id":"\#(profileFeedbackId)","title":"Modo escuro","body":"Detalhes","vote_count":1,"like_count":0,"public_comment_count":0,"priority":0,"viewer_voted":false,"viewer_liked":false,"created_at":"2026-10-01T12:00:00Z"}"#
        let loaded = UAPPUserModel(client: makeClient { request in
            queryValue("resource", in: request) == "comments"
                ? response(#"{"comments":[],"nextCursor":null}"#)
                : response(#"{"items":[\#(item)],"statuses":[],"nextCursor":null}"#)
        }, feedbackId: profileFeedbackId)
        await renderInNavigationStack(
            UAPPProfileFeedbackDestination(model: loaded, itemId: profileFeedbackId, accentColor: .blue),
            settling: true
        )
        let missing = UAPPUserModel(
            client: makeClient { _ in response(#"{"items":[],"nextCursor":null}"#) },
            feedbackId: profileFeedbackId
        )
        await renderInNavigationStack(
            UAPPProfileFeedbackDestination(model: missing, itemId: profileFeedbackId, accentColor: .blue),
            settling: true
        )
        let failing = UAPPUserModel(client: makeClient { _ in response(503, "{}") }, feedbackId: profileFeedbackId)
        await renderInNavigationStack(
            UAPPProfileFeedbackDestination(model: failing, itemId: profileFeedbackId, accentColor: .blue),
            settling: true
        )
        let page = try? await loaded.feedbackPage(itemId: profileFeedbackId)
        #expect(page?.items.first?.id == profileFeedbackId)
    }
}
