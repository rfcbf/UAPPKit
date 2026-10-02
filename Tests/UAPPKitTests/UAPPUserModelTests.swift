import Foundation
import Testing
@testable import UAPPKit

@MainActor
struct UAPPUserModelTests {
    @Test("Perfil local da toolbar carrega votos, comentários e feedbacks sem conta")
    func installationProfileLoadsParticipation() async throws {
        let recorder = RequestRecorder()
        let client = makeClient(recorder: recorder) { _ in
            response(#"{"author":{"name":"Visitante"},"totals":{"votes":4,"comments":2,"feedbacks":1},"items":[{"id":"first","title":"Meu feedback","state":"published","created_at":"2026-10-02T12:00:00Z"}]}"#)
        }
        let model = UAPPUserModel(client: client, usesInstallationProfile: true)
        await model.loadPublicProfile()
        #expect(model.publicProfile?.totals?.votes == 4)
        #expect(model.publicProfile?.totals?.comments == 2)
        #expect(model.publicProfile?.totals?.feedbacks == 1)
        #expect(model.history.first?.title == "Meu feedback")
        let request = try #require(recorder.requests.first)
        #expect(queryValue("viewer", in: request) == "installation")
        #expect(queryValue("itemId", in: request) == nil)
        #expect(request.value(forHTTPHeaderField: "x-uapp-installation-id") != nil)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        await model.reconcileActivity()
        #expect(recorder.requests.count == 2)
        #expect(model.history.count == 1)
    }

    @Test("Perfil local sem participação mostra zeros e falhas não inventam histórico")
    func installationProfileEmptyAndError() async {
        let empty = UAPPUserModel(client: makeClient { _ in
            response(#"{"author":{"name":"Comunidade"},"totals":{"votes":0,"comments":0,"feedbacks":0},"items":[]}"#)
        }, usesInstallationProfile: true)
        await empty.loadPublicProfile()
        #expect(empty.publicProfile?.totals?.votes == 0)
        #expect(empty.history.isEmpty)
        let failing = UAPPUserModel(client: makeClient { _ in response(503, "{}") }, usesInstallationProfile: true)
        await failing.loadPublicProfile()
        #expect(failing.activityErrorKey == "user.activity_error")
        #expect(failing.publicProfile == nil)
        #expect(failing.history.isEmpty)
    }

    @Test("Perfil público não consulta atividade privada nem encerra sessões")
    func publicProfileHasNoAccountActions() async {
        let model = UAPPUserModel()
        await model.loadActivity()
        await model.signOut()
        #expect(model.session == nil)
        #expect(model.activity == nil)
        #expect(model.history.isEmpty)
        #expect(model.errorKey == nil)
        #expect(model.activityErrorKey == nil)
        #expect(!model.isBusy)
    }

    @Test("Histórico carrega totais globais e não duplica itens ao paginar")
    func activityPagination() async throws {
        let provider = UserProviderStub(mode: .success)
        let session = try #require(await provider.currentSession())
        let client = UAPPClient(configuration: .init(projectId: "demo-app"), transport: StubTransport { request in
            let query = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems
            if query?.contains(where: { $0.name == "cursor" && $0.value == "next" }) == true {
                return response(#"{"totals":{"likes":2,"comments":1,"feedbacks":2},"items":[{"id":"first","title":"First","app_name":"First app","state":"published","created_at":"2026-10-01T12:00:00Z"},{"id":"second","title":"Second","app_name":"Second app","state":"pending","created_at":"2026-10-01T10:00:00Z"}],"nextCursor":null}"#)
            }
            return response(#"{"totals":{"likes":2,"comments":1,"feedbacks":2},"items":[{"id":"first","title":"First","app_name":"First app","state":"published","created_at":"2026-10-01T12:00:00Z"}],"nextCursor":"next"}"#)
        })
        let model = UAPPUserModel(session: session, authentication: provider, client: client) { _ in }
        await model.loadActivity()
        #expect(model.activity?.totals.likes == 2)
        #expect(model.history.count == 1)
        await model.loadActivity(loadMore: true)
        #expect(model.history.map(\.id) == ["first", "second"])
        #expect(model.activity?.nextCursor == nil)
        #expect(!model.isLoadingActivity)
    }

    @Test("Falha de atividade preserva a conta e não inventa totais")
    func activityFailure() async throws {
        let provider = UserProviderStub(mode: .success)
        let session = try #require(await provider.currentSession())
        let client = UAPPClient(configuration: .init(projectId: "demo-app"), transport: StubTransport { _ in response(503, "{}") })
        let model = UAPPUserModel(session: session, authentication: provider, client: client) { _ in }
        await model.loadActivity()
        #expect(model.session == session)
        #expect(model.activity == nil)
        #expect(model.activityErrorKey == "user.activity_error")
        #expect(!model.isLoadingActivity)
    }

    @Test("Sair limpa a sessão compartilhada e informa o aplicativo")
    func signOut() async throws {
        let provider = UserProviderStub(mode: .success)
        let session = try #require(await provider.currentSession())
        var delivered = false
        let model = UAPPUserModel(session: session, authentication: provider) {
            #expect($0 == nil)
            delivered = true
        }
        await model.signOut()
        #expect(model.session == nil)
        #expect(await provider.currentSession() == nil)
        #expect(delivered)
        #expect(!model.isBusy)
        #expect(model.errorKey == nil)
    }

    @Test("Falha que preserva a sessão mantém a conta e permite nova tentativa")
    func failure() async throws {
        let provider = UserProviderStub(mode: .keepSession)
        let session = try #require(await provider.currentSession())
        var delivered = false
        let model = UAPPUserModel(session: session, authentication: provider) { _ in delivered = true }
        await model.signOut()
        #expect(model.session == session)
        #expect(model.errorKey == "auth.signout_error")
        #expect(!delivered)
        #expect(!model.isBusy)
        await provider.setMode(.success)
        await model.signOut()
        #expect(model.session == nil)
        #expect(model.errorKey == nil)
        #expect(delivered)
    }

    @Test("Falha de rede após saída local também atualiza o aplicativo")
    func locallySignedOut() async throws {
        let provider = UserProviderStub(mode: .clearThenFail)
        let session = try #require(await provider.currentSession())
        var delivered = false
        let model = UAPPUserModel(session: session, authentication: provider) { _ in delivered = true }
        await model.signOut()
        #expect(model.session == nil)
        #expect(model.errorKey == nil)
        #expect(delivered)
    }
}

private actor UserProviderStub: UAPPAuthenticationProvider {
    enum Mode: Sendable { case success, keepSession, clearThenFail }
    nonisolated let methods: [UAPPLoginMethod] = [.email]
    private var mode: Mode
    private var session: UAPPAuthenticationSession? = .init(
        identity: .init(userId: "test-user", displayName: "Visitante"), accessToken: "fake-token"
    )

    init(mode: Mode) { self.mode = mode }
    func setMode(_ mode: Mode) { self.mode = mode }
    func currentSession() async -> UAPPAuthenticationSession? { session }
    func signOut() async throws {
        switch mode {
        case .success: session = nil
        case .keepSession: throw UAPPAuthenticationError.invalidConfiguration
        case .clearThenFail:
            session = nil
            throw UAPPAuthenticationError.invalidConfiguration
        }
    }
    func signIn(method _: UAPPLoginMethod) async throws -> UAPPAuthenticationSession {
        throw UAPPAuthenticationError.unsupportedMethod
    }
    func signIn(email _: String, password _: String) async throws -> UAPPAuthenticationSession {
        throw UAPPAuthenticationError.unsupportedMethod
    }
    func requestEmailCode(email _: String) async throws {
        throw UAPPAuthenticationError.unsupportedMethod
    }
    func verifyEmailCode(email _: String, code _: String) async throws -> UAPPAuthenticationSession {
        throw UAPPAuthenticationError.unsupportedMethod
    }
}
