import Foundation
import Testing
import UAPPKit
@testable import UAPPKitDemo

@MainActor
struct DemoAccountModelTests {
    @Test("Foto salva é entregue ao kit e muda de URL quando alterada")
    func localProfilePhoto() throws {
        let suite = "demo-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = DemoAccountModel(defaults: defaults)
        model.name = "Visitante"
        model.photo = Data(UUID().uuidString.utf8)
        model.saveProfile()
        let first = try #require(model.identity?.avatarURL)
        defer { try? FileManager.default.removeItem(at: first) }
        #expect(first.isFileURL)
        #expect(model.identity?.avatarData == model.photo)
        #expect(try Data(contentsOf: first) == model.photo)
        #expect(DemoAccountModel(defaults: defaults).identity?.avatarURL == first)
        model.photo = Data(UUID().uuidString.utf8)
        model.saveProfile()
        let second = try #require(model.identity?.avatarURL)
        defer { try? FileManager.default.removeItem(at: second) }
        #expect(second != first)
        model.photo = nil
        model.saveProfile()
        #expect(model.identity?.avatarURL == nil)
        #expect(model.identity?.avatarData == nil)
    }

    @Test("Perfil local persiste sem autenticar e pode ser apagado")
    func localProfile() throws {
        let suite = "demo-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = DemoAccountModel(defaults: defaults)
        #expect(model.identity == nil)
        model.name = "  Visitante  "
        model.email = " visitante@example.test "
        model.saveProfile()
        let restored = DemoAccountModel(defaults: defaults)
        #expect(restored.identity?.displayName == "Visitante")
        #expect(restored.identity?.email == "visitante@example.test")
        #expect(restored.identity?.userId == model.identity?.userId)
        #expect(restored.session == nil)
        #expect(restored.identity?.avatarURL == nil)
        restored.name = "Rascunho não salvo"
        #expect(restored.identity?.displayName == "Visitante")
        restored.removeProfile()
        #expect(DemoAccountModel(defaults: defaults).identity == nil)
    }

    @Test("Conta do app compartilha sessão, erro e saída com participação")
    func sharedSession() async throws {
        let suite = "demo-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let provider = DemoAuthenticationStub()
        let model = DemoAccountModel(defaults: defaults, authentication: provider)
        _ = try await provider.signIn(method: .github)
        await model.refreshSession()
        #expect(model.session?.identity.userId == "verified-user")
        #expect(try await model.authentication.currentSession() == model.session)
        await model.signOut()
        #expect(!model.isSigningOut)
        #expect(model.session == nil)
        #expect(try await model.authentication.currentSession() == nil)
        let session = try await provider.verifyEmailCode(email: "visitor@example.test", code: "123456")
        model.updateSession(session)
        #expect(model.session?.identity.userId == "verified-user")
        model.configure(projectId: "another-app")
        #expect(model.session == nil)
    }
}

private actor DemoAuthenticationStub: UAPPAuthenticationProvider {
    nonisolated let methods = UAPPLoginMethod.allCases
    private var session: UAPPAuthenticationSession?

    func currentSession() async throws -> UAPPAuthenticationSession? {
        session
    }

    func signIn(method _: UAPPLoginMethod) async throws -> UAPPAuthenticationSession {
        let result = UAPPAuthenticationSession(identity: .init(userId: "verified-user"), accessToken: "fake-token")
        session = result
        return result
    }

    func requestEmailCode(email _: String) async throws {}

    func signIn(email: String, password: String) async throws -> UAPPAuthenticationSession {
        #expect(email == "visitor@example.test")
        guard password == "test-password" else { throw UAPPAuthenticationError.signInRequired }
        return try await signIn(method: .email)
    }

    func verifyEmailCode(email _: String, code: String) async throws -> UAPPAuthenticationSession {
        guard code == "123456" else { throw UAPPAuthenticationError.signInRequired }
        return try await signIn(method: .email)
    }

    func signOut() async throws {
        session = nil
    }
}
