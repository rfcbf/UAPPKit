import Foundation
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@Test("token da sessão acompanha leitura e todas as interações sem alterar assinatura")
func accessTokenIsAttachedToRequests() async throws {
    let recorder = RequestRecorder()
    let client = UAPPClient(
        configuration: UAPPConfiguration(
            projectId: "app",
            signatureProvider: { "signature" }
        ),
        transport: StubTransport { request in
            recorder.record(request)
            return response(#"{"ok":true,"items":[],"statuses":[],"comments":[],"id":"created"}"#)
        },
        accessTokenProvider: { "session-token" }
    )
    _ = try await client.feedback()
    _ = try await client.roadmap()
    _ = try await client.comments(itemId: "item")
    _ = try await client.submitFeedback(title: "Título", category: .feature)
    try await client.setReaction(itemId: "item", kind: .vote, enabled: true)
    _ = try await client.submitComment(itemId: "item", body: "Comentário")
    #expect(recorder.requests.count == 6)
    for request in recorder.requests {
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer session-token")
        #expect(request.value(forHTTPHeaderField: "x-uapp-signature") == "Bearer signature")
    }
}

@Test("sessão é consultada novamente depois de logout")
func accessTokenProviderReflectsLogout() async throws {
    actor Session {
        var token: String?
        func current() -> String? {
            token
        }

        func logout() {
            token = nil
        }

        func signIn() {
            token = "first-token"
        }
    }
    let session = Session()
    let recorder = RequestRecorder()
    let client = UAPPClient(
        configuration: UAPPConfiguration(projectId: "app"),
        transport: StubTransport { request in
            recorder.record(request)
            return response(#"{"items":[]}"#)
        },
        accessTokenProvider: { await session.current() }
    )
    _ = try await client.feedback()
    await session.signIn()
    _ = try await client.feedback()
    await session.logout()
    _ = try await client.feedback()
    #expect(recorder.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(recorder.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer first-token")
    #expect(recorder.requests.last?.value(forHTTPHeaderField: "Authorization") == nil)
}

@Test("falha da sessão interrompe a requisição")
func accessTokenProviderPropagatesError() async {
    let recorder = RequestRecorder()
    let client = UAPPClient(
        configuration: UAPPConfiguration(projectId: "app"),
        transport: StubTransport { request in
            recorder.record(request)
            return response(#"{"items":[]}"#)
        },
        accessTokenProvider: { throw TestError.expected }
    )
    await #expect(throws: TestError.expected) { try await client.feedback() }
    #expect(recorder.requests.isEmpty)
}

@Test("token vazio ou com quebras de linha é rejeitado", arguments: ["", "  ", "token\nother", "token\rother"])
func accessTokenRejectsInvalidValue(_ token: String) async {
    let client = UAPPClient(
        configuration: UAPPConfiguration(projectId: "app"),
        transport: StubTransport { _ in throw TestError.expected },
        accessTokenProvider: { token }
    )
    await #expect(throws: UAPPKitError.invalidResponse) { try await client.feedback() }
}

@Test("perfil com foto mantém compatibilidade com identidade anterior")
func identitySupportsAvatarWithoutAuthentication() async throws {
    let old = Data(#"{"userId":"local","displayName":"Pessoa","traits":{}}"#.utf8)
    let identity = try JSONDecoder().decode(UAPPIdentity.self, from: old)
    #expect(identity.avatarURL == nil)
    let avatar = try #require(URL(string: "https://example.com/avatar.jpg"))
    let profile = UAPPIdentity(userId: "local", avatarURL: avatar)
    #expect(try JSONDecoder().decode(UAPPIdentity.self, from: JSONEncoder().encode(profile)) == profile)
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in response(#"{"items":[]}"#) }
    await client.setIdentity(profile)
    #expect(await client.currentIdentity() == profile)
    _ = try await client.feedback()
    #expect(recorder.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
}

@Test("Changelog, Reviews e Sobre não consultam autenticação mesmo no cliente de participação")
func publicContentDoesNotConsultSession() async throws {
    let recorder = RequestRecorder()
    let client = UAPPClient(
        configuration: UAPPConfiguration(projectId: "app"),
        transport: StubTransport { request in
            recorder.record(request)
            return response(#"{"entries":[],"reviews":[],"about":{}}"#)
        },
        accessTokenProvider: { throw TestError.expected }
    )
    #expect(try await client.changelog().isEmpty)
    #expect(try await client.reviews().isEmpty)
    #expect(try await client.about().developerName == nil)
    #expect(recorder.requests.count == 3)
    #expect(recorder.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == nil })
}

@Test("sessões de participação são isoladas e preservam perfil, idioma e instalação")
func participationClientsAreIsolated() async throws {
    let recorder = RequestRecorder()
    let base = makeClient(recorder: recorder) { _ in response(#"{"items":[]}"#) }
    let original = UAPPIdentity(userId: "original")
    await base.setIdentity(original)
    await base.setLocale(Locale(identifier: "en"))
    let first = await base.withAuthentication(accessTokenProvider: { "first" })
    let secondProfile = UAPPIdentity(userId: "second")
    let second = await base.withAuthentication(identity: secondProfile, accessTokenProvider: { "second" })
    #expect(await first.currentIdentity() == original)
    #expect(await second.currentIdentity() == secondProfile)
    #expect(await base.currentIdentity() == original)
    _ = try await first.feedback()
    _ = try await second.feedback()
    _ = try await base.feedback()
    #expect(recorder.requests.map { $0.value(forHTTPHeaderField: "Authorization") } == ["Bearer first", "Bearer second", nil])
    #expect(Set(recorder.requests.compactMap { $0.value(forHTTPHeaderField: "x-uapp-installation-id") }).count == 1)
    #expect(recorder.requests.allSatisfy { $0.value(forHTTPHeaderField: "Accept-Language") == "en" })
    await first.setIdentity(nil)
    #expect(await base.currentIdentity() == original)
    #expect(await second.currentIdentity() == secondProfile)
}
