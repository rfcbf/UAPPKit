import Foundation
import Testing
@testable import UAPPKit

private let sessionJSON = #"{"access_token":"access","refresh_token":"refresh","expires_in":3600,"user":{"id":"verified","email":"person@example.test","user_metadata":{"full_name":"Pessoa","avatar_url":"https://example.test/avatar.png","email_verified":true}}}"#

private func authConfiguration(methods: [UAPPLoginMethod] = UAPPLoginMethod.allCases) -> UAPPAuthenticationConfiguration {
    .init(host: URL(string: "https://example.test")!, publishableKey: "sb_publishable_example", callbackURL: URL(string: "demo://auth/callback")!, methods: methods, persistsSession: false)
}

@Test("Foto usa diretório do usuário, atualiza metadados e mantém a sessão")
func profilePhotoUpload() async throws {
    let recorder = RequestRecorder()
    let photo = Data([0xFF, 0xD8, 0xFF, 0x00])
    let auth = UAPPAuthentication(configuration: authConfiguration(), transport: StubTransport { request in
        recorder.record(request)
        if request.url?.path.hasPrefix("/storage/v1/object/avatars/") == true {
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path.contains("/avatars/verified/") == true)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access")
            #expect(request.value(forHTTPHeaderField: "apikey") == "sb_publishable_example")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "image/jpeg")
            #expect(request.httpBody == photo)
            return response("{}")
        }
        if request.url?.lastPathComponent == "user" {
            #expect(request.httpMethod == "PUT")
            let body = try #require(request.httpBody)
            let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: [String: String]])
            let avatar = try #require(payload["data"]?["avatar_url"])
            #expect(avatar.hasPrefix("https://example.test/storage/v1/object/public/avatars/verified/"))
            #expect(payload["data"]?["uapp_avatar_url"] == avatar)
            // O provedor social pode manter a própria foto em `avatar_url`; a escolhida prevalece.
            let user: [String: Any] = ["id": "verified", "email": "person@example.test",
                                      "user_metadata": ["full_name": "Pessoa", "avatar_url": "https://example.test/social.png",
                                                        "uapp_avatar_url": avatar]]
            return (200, try JSONSerialization.data(withJSONObject: user))
        }
        return response(sessionJSON)
    })
    _ = try await auth.verifySignupCode(email: "person@example.test", code: "123456")
    let updated = try await auth.uploadProfilePhoto(photo)
    #expect(updated.identity.displayName == "Pessoa")
    #expect(updated.identity.avatarURL?.absoluteString.contains("/public/avatars/verified/") == true)
    #expect(updated.accessToken == "access")
    #expect(try await auth.currentSession() == updated)
    #expect(recorder.requests.count == 3)
}

@Test("Foto escolhida no kit prevalece sobre a foto do provedor em novos logins")
func chosenAvatarWinsOverProviderPicture() async throws {
    let json = #"{"access_token":"access","refresh_token":"refresh","expires_in":3600,"user":{"id":"verified","user_metadata":{"avatar_url":"https://example.test/social.png","picture":"https://example.test/picture.png","uapp_avatar_url":"https://example.test/chosen.jpg"}}}"#
    let auth = UAPPAuthentication(configuration: authConfiguration(), transport: StubTransport { _ in response(json) })
    let session = try await auth.verifySignupCode(email: "person@example.test", code: "123456")
    #expect(session.identity.avatarURL == URL(string: "https://example.test/chosen.jpg"))
    let fallback = UAPPAuthentication(configuration: authConfiguration(), transport: StubTransport { _ in
        response(#"{"access_token":"access","refresh_token":"refresh","expires_in":3600,"user":{"id":"verified","user_metadata":{"picture":"https://example.test/picture.png"}}}"#)
    })
    let social = try await fallback.verifySignupCode(email: "person@example.test", code: "123456")
    #expect(social.identity.avatarURL == URL(string: "https://example.test/picture.png"))
}

@Test("Erro ao associar foto remove o arquivo novo e preserva o avatar anterior")
func profilePhotoFailure() async throws {
    let recorder = RequestRecorder()
    let auth = UAPPAuthentication(configuration: authConfiguration(), transport: StubTransport { request in
        recorder.record(request)
        if request.url?.lastPathComponent == "user" { return response(400, "{}") }
        if request.url?.path.contains("/storage/") == true { return response("{}") }
        return response(sessionJSON)
    })
    let initial = try await auth.verifySignupCode(email: "person@example.test", code: "123456")
    await #expect(throws: UAPPKitError.self) { try await auth.uploadProfilePhoto(Data([0xFF, 0xD8, 0xFF])) }
    #expect(try await auth.currentSession() == initial)
    let removal = try #require(recorder.requests.last)
    #expect(removal.httpMethod == "DELETE")
    let body = try #require(removal.httpBody)
    let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: [String]])
    #expect(payload["prefixes"]?.first?.hasPrefix("verified/") == true)
}

@Test("Envio rejeita imagem inválida e exige uma sessão")
func profilePhotoValidation() async {
    let auth = UAPPAuthentication(configuration: authConfiguration(), transport: StubTransport { _ in
        Issue.record("Imagem inválida ou sessão ausente não deve acessar a rede")
        return response(500, "{}")
    })
    await #expect(throws: UAPPKitError.invalidResponse) { try await auth.uploadProfilePhoto(Data()) }
    await #expect(throws: UAPPAuthenticationError.signInRequired) {
        try await auth.uploadProfilePhoto(Data([0xFF, 0xD8, 0xFF]))
    }
}

@Test("Cadastro trata confirmação obrigatória, sessão imediata e nome opcional", arguments: [true, false])
func registrationResponse(_ confirmed: Bool) async throws {
    let auth = UAPPAuthentication(configuration: authConfiguration(), transport: StubTransport { request in
        #expect(request.url?.lastPathComponent == "signup")
        let data = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["password"] as? String == "test-password")
        #expect(body["data"] == nil)
        return response(confirmed ? sessionJSON : #"{"id":"pending-user","email":"person@example.test"}"#)
    })
    let result = try await auth.signUp(email: "person@example.test", password: "test-password")
    if confirmed {
        let current = try await auth.currentSession()
        #expect(result == .signedIn(try #require(current)))
    } else {
        #expect(result == .confirmationRequired)
        #expect(try await auth.currentSession() == nil)
    }
}

@Test("Recuperação usa tipo recovery e atualiza senha com PUT autenticado")
func passwordRecoveryRequests() async throws {
    let recorder = RequestRecorder()
    let auth = UAPPAuthentication(configuration: authConfiguration(), transport: StubTransport { request in
        recorder.record(request)
        if request.url?.lastPathComponent == "verify" {
            let data = try #require(request.httpBody)
            let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
            #expect(body["type"] == "recovery")
            return response(sessionJSON)
        }
        if request.url?.lastPathComponent == "user" {
            #expect(request.httpMethod == "PUT")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access")
        }
        return response("{}")
    })
    await #expect(throws: UAPPAuthenticationError.signInRequired) { try await auth.updatePassword("test-password") }
    try await auth.requestPasswordReset(email: "person@example.test")
    try await auth.verifyPasswordResetCode(email: "person@example.test", code: "123456")
    let result = try await auth.updatePassword("test-password")
    #expect(result.identity.userId == "verified")
    #expect(recorder.requests.map { $0.url?.lastPathComponent } == ["recover", "verify", "user"])
}

@Test("Falha de cadastro ou recuperação preserva sessão ausente", arguments: ["signup", "recover", "verify"])
func accountRequestFailures(_ path: String) async throws {
    let auth = UAPPAuthentication(configuration: authConfiguration(), transport: StubTransport { _ in response(400, "{}") })
    await #expect(throws: UAPPKitError.self) {
        switch path {
        case "signup": _ = try await auth.signUp(email: "person@example.test", password: "test-password", displayName: "Person")
        case "recover": try await auth.requestPasswordReset(email: "person@example.test")
        default: try await auth.verifyPasswordResetCode(email: "person@example.test", code: "123456")
        }
    }
    #expect(try await auth.currentSession() == nil)
}

@Test("Login por senha usa grant correto, compartilha sessão e propaga erros", arguments: [200, 401, 503])
func emailPasswordSession(_ status: Int) async throws {
    let auth = UAPPAuthentication(configuration: authConfiguration(), transport: StubTransport { request in
        #expect(queryValue("grant_type", in: request) == "password")
        #expect(request.url?.lastPathComponent == "token")
        let data = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(body["email"] == "person@example.test")
        #expect(body["password"] == "test-password")
        return response(status, sessionJSON)
    })
    if status == 200 {
        let result = try await auth.signIn(email: "person@example.test", password: "test-password")
        #expect(result.identity.userId == "verified")
        #expect(try await auth.currentSession() == result)
    } else {
        await #expect(throws: UAPPKitError.self) {
            try await auth.signIn(email: "person@example.test", password: "test-password")
        }
        #expect(try await auth.currentSession() == nil)
    }
}

@Test("Senha respeita métodos permitidos e perfil opcional")
func passwordMethodsAndOptionalProfile() async throws {
    let auth = UAPPAuthentication(configuration: authConfiguration(methods: [.github]), transport: StubTransport { _ in
        Issue.record("Método desabilitado não deve iniciar rede")
        return response("{}")
    })
    await #expect(throws: UAPPAuthenticationError.unsupportedMethod) {
        try await auth.signIn(email: "person@example.test", password: "test-password")
    }
    let minimal = UAPPAuthentication(configuration: authConfiguration(), transport: StubTransport { _ in
        response(#"{"access_token":"access","refresh_token":"refresh","expires_in":3600,"user":{"id":"verified"}}"#)
    })
    let session = try await minimal.signIn(email: "person@example.test", password: "test-password")
    #expect(session.identity.email == nil)
    #expect(session.identity.displayName == nil)
    #expect(session.identity.avatarURL == nil)
}

@Test("OTP obtém sessão, extrai perfil e faz logout sem persistir tokens")
func supabaseEmailSessionAndLogout() async throws {
    let recorder = RequestRecorder()
    let auth = UAPPAuthentication(configuration: authConfiguration(), transport: StubTransport { request in
        recorder.record(request)
        return response(request.url?.lastPathComponent == "verify" ? sessionJSON : "{}")
    })
    #expect(try await auth.currentSession() == nil)
    try await auth.requestEmailCode(email: "person@example.test")
    let session = try await auth.verifyEmailCode(email: "person@example.test", code: "123456")
    #expect(session.accessToken == "access")
    #expect(session.identity.userId == "verified")
    #expect(session.identity.displayName == "Pessoa")
    #expect(session.identity.avatarURL?.host == "example.test")
    #expect(try await auth.currentSession() == session)
    try await auth.signOut()
    #expect(try await auth.currentSession() == nil)
    #expect(recorder.requests.map { $0.url?.lastPathComponent } == ["otp", "verify", "logout"])
    #expect(recorder.requests.allSatisfy { $0.value(forHTTPHeaderField: "apikey") == "sb_publishable_example" })
    #expect(recorder.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer access")
}

@Test("OAuth usa PKCE e troca código apenas após callback esperado", arguments: [UAPPLoginMethod.apple, .google, .github])
func supabaseOAuthPKCE(_ method: UAPPLoginMethod) async throws {
    let recorder = RequestRecorder()
    let auth = UAPPAuthentication(
        configuration: authConfiguration(),
        transport: StubTransport { request in
            recorder.record(request)
            #expect(queryValue("grant_type", in: request) == "pkce")
            let data = try #require(request.httpBody)
            let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
            #expect(body["auth_code"] == "code")
            #expect(body["code_verifier"]?.count == 64)
            return response(sessionJSON)
        },
        oauthPresenter: { url, callback in
            let values = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(values.first { $0.name == "provider" }?.value == method.rawValue)
            #expect(values.first { $0.name == "code_challenge" }?.value?.count == 43)
            #expect(values.first { $0.name == "code_challenge_method" }?.value == "s256")
            return try #require(URL(string: callback.absoluteString + "?code=code"))
        }
    )
    #expect(try await auth.signIn(method: method).identity.email == "person@example.test")
    #expect(recorder.requests.count == 1)
}

@Test("refresh é compartilhado e logout impede recuperar sessão antiga")
func supabaseRefreshAndConcurrentLogout() async throws {
    let clock = AuthenticationClock()
    let gate = RequestGate()
    let recorder = RequestRecorder()
    let auth = UAPPAuthentication(
        configuration: authConfiguration(),
        transport: StubTransport { request in
            recorder.record(request)
            if request.url?.lastPathComponent == "token" {
                await gate.suspend()
            }
            return response(sessionJSON)
        },
        oauthPresenter: { _, _ in throw UAPPAuthenticationError.cancelled },
        now: clock.now
    )
    _ = try await auth.verifyEmailCode(email: "person@example.test", code: "123456")
    clock.advance()
    let first = Task { try await auth.currentSession() }
    await gate.waitUntilStarted()
    let second = Task { try await auth.currentSession() }
    await Task.yield()
    try await auth.signOut()
    await gate.resume()
    #expect(try await first.value == nil)
    #expect(try await second.value == nil)
    #expect(try await auth.currentSession() == nil)
    #expect(recorder.requests.filter { $0.url?.lastPathComponent == "token" }.count == 1)
}

@Test("refresh bem-sucedido renova sessão e falha terminal limpa credenciais", arguments: [200, 400, 401, 503])
func supabaseRefreshResponse(_ status: Int) async throws {
    let clock = AuthenticationClock()
    let auth = UAPPAuthentication(
        configuration: authConfiguration(),
        transport: StubTransport { request in
            response(request.url?.lastPathComponent == "token" ? status : 200, sessionJSON)
        },
        oauthPresenter: { _, _ in throw UAPPAuthenticationError.cancelled },
        now: clock.now
    )
    _ = try await auth.verifyEmailCode(email: "person@example.test", code: "123456")
    clock.advance()
    if status == 200 {
        #expect(try await auth.currentSession()?.accessToken == "access")
    } else {
        await #expect(throws: UAPPKitError.self) { try await auth.currentSession() }
        if status != 503 {
            #expect(try await auth.currentSession() == nil)
        }
    }
}

@Test("configuração insegura, método ausente, callback incorreto e sessão inválida são rejeitados")
func supabaseRejectsInvalidFlows() async throws {
    let noNetwork = StubTransport { _ in throw TestError.expected }
    let auth = UAPPAuthentication(configuration: authConfiguration(methods: []), transport: noNetwork)
    await #expect(throws: UAPPAuthenticationError.unsupportedMethod) { try await auth.requestEmailCode(email: "email") }
    await #expect(throws: UAPPAuthenticationError.unsupportedMethod) { try await auth.verifyEmailCode(email: "email", code: "code") }
    await #expect(throws: UAPPAuthenticationError.unsupportedMethod) { try await auth.signIn(method: .email) }
    let invalidConfig = try UAPPAuthenticationConfiguration(host: #require(URL(string: "http://example.test")), publishableKey: "sb_secret_example", callbackURL: #require(URL(string: "https://example.test")))
    let invalid = UAPPAuthentication(configuration: invalidConfig, transport: noNetwork)
    await #expect(throws: UAPPAuthenticationError.invalidConfiguration) { try await invalid.requestEmailCode(email: "email") }
    let expected = authConfiguration().callbackURL
    for text in ["wrong://auth/callback?code=x", "demo://other/callback?code=x", "demo://auth/wrong?code=x", "demo://auth/callback?error=denied", "demo://auth/callback?code=", "demo://auth/callback?code=x&code=y"] {
        #expect(throws: UAPPAuthenticationError.invalidCallback) { try UAPPAuthentication.callbackCode(#require(URL(string: text)), expected: expected) }
    }
    let malformed = UAPPAuthentication(configuration: authConfiguration(), transport: StubTransport { _ in
        response(#"{"access_token":"","refresh_token":"","expires_in":0,"user":{"id":"user"}}"#)
    })
    await #expect(throws: UAPPKitError.invalidResponse) { try await malformed.verifyEmailCode(email: "email", code: "code") }
}

@Test("logout limpa sessão local mesmo quando servidor falha")
func supabaseLogoutClearsSessionOnFailure() async throws {
    let auth = UAPPAuthentication(configuration: authConfiguration(), transport: StubTransport { request in
        response(request.url?.lastPathComponent == "logout" ? 503 : 200, sessionJSON)
    })
    _ = try await auth.verifyEmailCode(email: "email", code: "code")
    await #expect(throws: UAPPKitError.self) { try await auth.signOut() }
    #expect(try await auth.currentSession() == nil)
    try await auth.signOut()
}
