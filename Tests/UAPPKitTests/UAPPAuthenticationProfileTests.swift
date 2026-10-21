import Foundation
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

private let configuration = UAPPAuthenticationConfiguration(
    host: URL(string: "https://example.test")!,
    publishableKey: "sb_publishable_example",
    callbackURL: URL(string: "demo://auth/callback")!,
    methods: UAPPLoginMethod.allCases,
    persistsSession: false
)

private func session(expiresIn: Int = 3600, metadata: String = "{}") -> String {
    #"{"access_token":"access","refresh_token":"refresh","expires_in":\#(expiresIn),"user":{"id":"verified","email":"pessoa@example.test","user_metadata":\#(metadata)}}"#
}

private let profileAvatar = "https://example.test/storage/v1/object/public/avatars/verified/web.jpg"

@Test("Login sem nome nem foto na conta usa o perfil do UAPP, o mesmo do painel web")
func signInUsesUAPPProfile() async throws {
    let recorder = RequestRecorder()
    let auth = UAPPAuthentication(configuration: configuration, transport: StubTransport(handler: { request in
        recorder.record(request)
        if request.url?.path == "/rest/v1/profiles" {
            #expect(request.httpMethod == "GET")
            #expect(request.url?.query?.contains("id=eq.verified") == true)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access")
            #expect(request.value(forHTTPHeaderField: "apikey") == "sb_publishable_example")
            return response(#"[{"display_name":"Pessoa do Painel","avatar_url":"\#(profileAvatar)"}]"#)
        }
        return response(session())
    }, handlesProfiles: true))

    let signedIn = try await auth.verifySignupCode(email: "pessoa@example.test", code: "123456")
    #expect(signedIn.identity.displayName == "Pessoa do Painel")
    #expect(signedIn.identity.avatarURL?.absoluteString == profileAvatar)
    #expect(recorder.requests.map { $0.url?.path } == ["/auth/v1/verify", "/rest/v1/profiles"])
}

@Test("Nome e foto da conta e a foto escolhida no kit prevalecem sobre o perfil do UAPP")
func accountMetadataWinsOverProfile() async throws {
    let metadata = #"{"full_name":"Nome da Conta","avatar_url":"https://example.test/social.png","uapp_avatar_url":"https://example.test/kit.jpg"}"#
    let auth = UAPPAuthentication(configuration: configuration, transport: StubTransport(handler: { request in
        if request.url?.path == "/rest/v1/profiles" {
            return response(#"[{"display_name":"Pessoa do Painel","avatar_url":"\#(profileAvatar)"}]"#)
        }
        return response(session(metadata: metadata))
    }, handlesProfiles: true))

    let signedIn = try await auth.verifyEmailCode(email: "pessoa@example.test", code: "123456")
    #expect(signedIn.identity.displayName == "Nome da Conta")
    #expect(signedIn.identity.avatarURL?.absoluteString == "https://example.test/kit.jpg")

    // Sem foto escolhida no kit, a do perfil vem antes da foto do provedor social.
    let social = UAPPAuthentication(configuration: configuration, transport: StubTransport(handler: { request in
        if request.url?.path == "/rest/v1/profiles" {
            return response(#"[{"display_name":null,"avatar_url":"\#(profileAvatar)"}]"#)
        }
        return response(session(metadata: #"{"avatar_url":"https://example.test/social.png"}"#))
    }, handlesProfiles: true))
    let socialSession = try await social.signIn(email: "pessoa@example.test", password: "Senha-forte-1")
    #expect(socialSession.identity.avatarURL?.absoluteString == profileAvatar)
    #expect(socialSession.identity.displayName == nil)
}

@Test("Nome automático do cadastro (parte do e-mail) não substitui o e-mail na conta")
func automaticProfileNameIsIgnored() {
    let row = UAPPProfileRow(displayName: "pessoa", avatarURL: nil)
    #expect(row.displayName(for: "pessoa@example.test") == nil)
    #expect(UAPPProfileRow(displayName: "  ", avatarURL: nil).displayName(for: nil) == nil)
    #expect(UAPPProfileRow(displayName: "Pessoa", avatarURL: nil).displayName(for: "pessoa@example.test") == "Pessoa")
}

@Test("Falha ao ler o perfil não impede o login e a renovação mantém o perfil anterior")
func profileFailureKeepsPreviousValues() async throws {
    let calls = RequestRecorder()
    let auth = UAPPAuthentication(
        configuration: configuration,
        transport: StubTransport(handler: { request in
            calls.record(request)
            if request.url?.path == "/rest/v1/profiles" {
                let profileCalls = calls.requests.filter { $0.url?.path == "/rest/v1/profiles" }.count
                return profileCalls == 1
                    ? response(#"[{"display_name":"Pessoa do Painel","avatar_url":"\#(profileAvatar)"}]"#)
                    : response(500, "{}")
            }
            return response(session(expiresIn: 10))
        }, handlesProfiles: true),
        oauthPresenter: { _, callback in callback },
        now: Date.init
    )

    let signedIn = try await auth.verifySignupCode(email: "pessoa@example.test", code: "123456")
    #expect(signedIn.identity.displayName == "Pessoa do Painel")

    // A sessão expira em 10 s, então a próxima leitura renova o token e tenta o perfil de novo.
    let refreshed = try #require(try await auth.currentSession())
    #expect(refreshed.identity.displayName == "Pessoa do Painel")
    #expect(refreshed.identity.avatarURL?.absoluteString == profileAvatar)
    #expect(calls.requests.contains { $0.url?.query?.contains("grant_type=refresh_token") == true })

    let offline = UAPPAuthentication(configuration: configuration, transport: StubTransport(handler: { request in
        if request.url?.path == "/rest/v1/profiles" {
            throw URLError(.notConnectedToInternet)
        }
        return response(session())
    }, handlesProfiles: true))
    let withoutProfile = try await offline.verifySignupCode(email: "pessoa@example.test", code: "123456")
    #expect(withoutProfile.identity.displayName == nil)
    #expect(withoutProfile.identity.avatarURL == nil)
}

@Test("Foto nova enviada pelo kit também vai para o perfil do UAPP")
func profilePhotoUpdatesUAPPProfile() async throws {
    let recorder = RequestRecorder()
    let auth = UAPPAuthentication(configuration: configuration, transport: StubTransport(handler: { request in
        recorder.record(request)
        let path = request.url?.path ?? ""
        if path.hasPrefix("/storage/v1/object/avatars/") {
            return response("{}")
        }
        if path == "/auth/v1/user" {
            let body = try #require(request.httpBody)
            let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: [String: String]])
            let avatar = try #require(payload["data"]?["uapp_avatar_url"])
            let user: [String: Any] = [
                "id": "verified", "email": "pessoa@example.test",
                "user_metadata": ["uapp_avatar_url": avatar]
            ]
            return try (200, JSONSerialization.data(withJSONObject: user))
        }
        if path == "/rest/v1/profiles", request.httpMethod == "PATCH" {
            #expect(request.url?.query?.contains("id=eq.verified") == true)
            #expect(request.url?.query?.contains("select=display_name,avatar_url") == true)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access")
            let body = try #require(request.httpBody)
            let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
            let avatar = try #require(payload["avatar_url"])
            #expect(avatar.hasPrefix("https://example.test/storage/v1/object/public/avatars/verified/"))
            return response(#"[{"display_name":"Pessoa do Painel","avatar_url":"\#(avatar)"}]"#)
        }
        if path == "/rest/v1/profiles" {
            return response(#"[{"display_name":"Pessoa do Painel","avatar_url":"\#(profileAvatar)"}]"#)
        }
        return response(session())
    }, handlesProfiles: true))

    _ = try await auth.verifySignupCode(email: "pessoa@example.test", code: "123456")
    let updated = try await auth.uploadProfilePhoto(Data([0xFF, 0xD8, 0xFF, 0x00]))
    let avatar = try #require(updated.identity.avatarURL?.absoluteString)
    #expect(avatar.hasPrefix("https://example.test/storage/v1/object/public/avatars/verified/"))
    #expect(avatar != profileAvatar)
    #expect(updated.identity.displayName == "Pessoa do Painel")
    #expect(recorder.requests.contains { $0.httpMethod == "PATCH" && $0.url?.path == "/rest/v1/profiles" })
}
