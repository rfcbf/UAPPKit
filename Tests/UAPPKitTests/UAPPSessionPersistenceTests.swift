import Foundation
import Testing
@testable import UAPPKit

struct UAPPSessionPersistenceTests: Sendable {
    private let json = #"{"access_token":"access","refresh_token":"refresh","expires_in":3600,"user":{"id":"user","email":"user@example.test","user_metadata":{"full_name":"Visitante","picture":"https://example.test/avatar.png"}}}"#

    private func provider(
        storage: any UAPPSessionStorage,
        date: Date = Date(),
        transport: any UAPPTransport
    ) -> UAPPAuthentication {
        UAPPAuthentication(
            configuration: .init(
                host: URL(string: "https://example.test")!,
                publishableKey: "public-key",
                callbackURL: URL(string: "demo://auth")!
            ),
            transport: transport,
            oauthPresenter: { _, _ in throw UAPPAuthenticationError.cancelled },
            now: { date }, sessionStorage: storage
        )
    }

    @Test("Conta e foto são restauradas por outro provedor sem rede e logout apaga o registro")
    func restoredSession() async throws {
        let storage = MemorySessionStorage()
        let first = provider(storage: storage, transport: StubTransport { _ in response(json) })
        let session = try await first.signIn(email: "user@example.test", password: "test-password")
        let restored = provider(storage: storage, transport: StubTransport { request in
            #expect(request.url?.lastPathComponent == "logout")
            return response("{}")
        })
        #expect(try await restored.currentSession() == session)
        #expect(try await restored.currentSession()?.identity.avatarURL?.absoluteString == "https://example.test/avatar.png")
        try await restored.signOut()
        #expect(try storage.read() == nil)
        let reopened = provider(storage: storage, transport: StubTransport { _ in throw TestError.expected })
        #expect(try await reopened.currentSession() == nil)
    }

    @Test("Sessão expirada usa refresh token salvo e conserva o registro após falha temporária")
    func expiredSession() async throws {
        let storage = MemorySessionStorage()
        let date = Date(timeIntervalSince1970: 100)
        let first = provider(storage: storage, date: date, transport: StubTransport { _ in response(json) })
        _ = try await first.signIn(email: "user@example.test", password: "test-password")
        let unavailable = provider(
            storage: storage,
            date: date.addingTimeInterval(4000),
            transport: StubTransport { _ in response(503, "{}") }
        )
        await #expect(throws: UAPPKitError.self) { try await unavailable.currentSession() }
        #expect(try storage.read() != nil)
        let refreshed = provider(storage: storage, date: date.addingTimeInterval(4000), transport: StubTransport { request in
            #expect(request.url?.query?.contains("grant_type=refresh_token") == true)
            let body = try #require(request.httpBody)
            let values = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
            #expect(values["refresh_token"] == "refresh")
            return response(json)
        })
        #expect(try await refreshed.currentSession()?.identity.displayName == "Visitante")
    }

    @Test("Renovação rejeitada remove a sessão persistida", arguments: [400, 401])
    func rejectedRefresh(_ status: Int) async throws {
        let storage = MemorySessionStorage()
        let date = Date(timeIntervalSince1970: 100)
        let first = provider(storage: storage, date: date, transport: StubTransport { _ in response(json) })
        _ = try await first.signIn(email: "user@example.test", password: "test-password")
        let restored = provider(
            storage: storage,
            date: date.addingTimeInterval(4000),
            transport: StubTransport { _ in response(status, "{}") }
        )
        await #expect(throws: UAPPKitError.self) { try await restored.currentSession() }
        #expect(try storage.read() == nil)
        #expect(try await restored.currentSession() == nil)
    }

    @Test("Provedor automático restaura a conta sem descoberta e separa projetos")
    func automaticRestore() async throws {
        let storage = MemorySessionStorage()
        let noNetwork = StubTransport { _ in throw TestError.expected }
        let first = provider(storage: storage, transport: StubTransport { _ in response(json) })
        let session = try await first.signIn(email: "user@example.test", password: "test-password")
        let restored = try UAPPAutomaticAuthentication(
            configuration: .init(projectId: "demo", host: #require(URL(string: "https://example.test"))),
            transport: noNetwork, sessionStorage: storage
        )
        #expect(try await restored.currentSession() == session)
        #expect(try UAPPKeychainSessionStorage.account(host: #require(URL(string: "https://example.test")), projectId: "one")
            != UAPPKeychainSessionStorage.account(host: #require(URL(string: "https://example.test")), projectId: "two"))
        try await UAPPAutomaticAuthentication(
            configuration: .init(projectId: "demo"), transport: noNetwork, sessionStorage: storage
        ).signOut()
        #expect(try storage.read() == nil)
    }

    @Test("Registro corrompido é removido e recuperação incompleta não persiste sessão")
    func invalidAndRecovery() async throws {
        let storage = MemorySessionStorage()
        try storage.save(Data("invalid".utf8))
        let auth = provider(storage: storage, transport: StubTransport { _ in response(json) })
        #expect(try await auth.currentSession() == nil)
        #expect(try storage.read() == nil)
        try await auth.verifyPasswordResetCode(email: "user@example.test", code: "123456")
        #expect(try storage.read() == nil)
        _ = try await auth.updatePassword("New-password")
        #expect(try storage.read() != nil)
    }
}

private final class MemorySessionStorage: UAPPSessionStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    func read() throws -> Data? {
        lock.withLock { data }
    }

    func save(_ data: Data) throws {
        lock.withLock { self.data = data }
    }

    func remove() throws {
        lock.withLock { data = nil }
    }
}
