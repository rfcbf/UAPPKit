import Foundation
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

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
            let query = try URLComponents(url: #require(request.url), resolvingAgainstBaseURL: false)?.queryItems
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

    @Test("Trocar a foto envia ao provedor, atualiza a sessão e mantém a última foto")
    func updateProfilePhoto() async {
        let provider = AccountProviderStub()
        let session = UAPPAuthenticationSession(
            identity: .init(userId: "verified", displayName: "Pessoa"),
            accessToken: "fake-token"
        )
        var delivered: [UAPPAuthenticationSession?] = []
        let model = UAPPUserModel(session: session, authentication: provider) { delivered.append($0) }
        #expect(model.supportsProfilePhoto)
        #expect(model.avatarURL == nil)
        let photo = Data([0xFF, 0xD8, 0xFF, 0x01])
        await model.updateProfilePhoto(photo)
        #expect(await provider.photoAttempts == 1)
        #expect(model.profilePhoto == photo)
        #expect(model.avatarURL == URL(string: "https://example.test/avatar.jpg"))
        #expect(model.session?.identity.avatarURL == model.avatarURL)
        #expect(delivered.count == 1)
        #expect(delivered.first??.identity.avatarURL == model.avatarURL)
        #expect(model.errorKey == nil)
        #expect(!model.isUploadingPhoto)
        await model.signOut()
        #expect(model.profilePhoto == nil)
    }

    @Test("Sessão editada pelo aplicativo substitui a atual só para a mesma conta")
    func adoptSessionFromHost() {
        let session = UAPPAuthenticationSession(
            identity: .init(userId: "verified", displayName: "Pessoa"),
            accessToken: "fake-token"
        )
        var delivered = 0
        let model = UAPPUserModel(session: session, authentication: AccountProviderStub()) { _ in delivered += 1 }
        let renamed = UAPPAuthenticationSession(
            identity: .init(userId: "verified", displayName: "Pessoa Renomeada"),
            accessToken: "fake-token"
        )
        model.adoptSession(renamed)
        #expect(model.session?.identity.displayName == "Pessoa Renomeada")
        let otherAccount = UAPPAuthenticationSession(
            identity: .init(userId: "other", displayName: "Outra"),
            accessToken: "other-token"
        )
        model.adoptSession(otherAccount)
        #expect(model.session == renamed)
        #expect(delivered == 0)

        let publicModel = UAPPUserModel()
        publicModel.adoptSession(renamed)
        #expect(publicModel.session == nil)
    }

    @Test("Falha ao trocar a foto preserva a anterior e permite nova tentativa")
    func updateProfilePhotoFailure() async {
        let provider = AccountProviderStub(failsPhotoOnce: true)
        let session = UAPPAuthenticationSession(identity: .init(userId: "verified"), accessToken: "fake-token")
        var delivered = 0
        let model = UAPPUserModel(session: session, authentication: provider) { _ in delivered += 1 }
        await model.updateProfilePhoto(Data([0x01]))
        #expect(model.profilePhoto == nil)
        #expect(model.session == session)
        #expect(model.errorKey == "photo.update_error")
        #expect(delivered == 0)
        #expect(!model.isUploadingPhoto)
        await model.updateProfilePhoto(Data([0x02]))
        #expect(model.profilePhoto == Data([0x02]))
        #expect(model.errorKey == nil)
        #expect(delivered == 1)
        #expect(await provider.photoAttempts == 2)
    }

    @Test("Provedor sem foto e perfil público não enviam imagem")
    func updateProfilePhotoUnsupported() async throws {
        let provider = UserProviderStub(mode: .success)
        let session = try #require(await provider.currentSession())
        let model = UAPPUserModel(session: session, authentication: provider) { _ in
            Issue.record("A sessão não deveria mudar")
        }
        #expect(!model.supportsProfilePhoto)
        await model.updateProfilePhoto(Data([0x01]))
        #expect(model.profilePhoto == nil)
        #expect(model.errorKey == nil)
        let publicModel = UAPPUserModel()
        #expect(!publicModel.supportsProfilePhoto)
        await publicModel.updateProfilePhoto(Data([0x01]))
        #expect(publicModel.profilePhoto == nil)
        #expect(publicModel.avatarURL == nil)
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

    @Test("Excluir conta mantém o aviso final e só depois avisa o aplicativo", arguments: [false, true])
    func deleteAccount(requiresAppleAccessRemoval: Bool) async throws {
        let provider = DeletionProviderStub(outcome: .success(
            UAPPAccountDeletion(requiresAppleAccessRemoval: requiresAppleAccessRemoval)
        ))
        let session = try #require(await provider.currentSession())
        var delivered: [UAPPAuthenticationSession?] = []
        let model = UAPPUserModel(session: session, authentication: provider) { delivered.append($0) }
        #expect(model.supportsAccountDeletion)
        await model.deleteAccount()
        #expect(model.accountDeletion?.requiresAppleAccessRemoval == requiresAppleAccessRemoval)
        #expect(model.session == session)
        #expect(delivered.isEmpty)
        #expect(!model.isBusy)
        #expect(!model.isDeletingAccount)
        #expect(model.errorKey == nil)
        await model.deleteAccount()
        #expect(await provider.deletionAttempts == 1)
        model.finishAccountDeletion()
        #expect(model.accountDeletion == nil)
        #expect(model.session == nil)
        #expect(!model.supportsAccountDeletion)
        #expect(delivered.count == 1)
        #expect(delivered.first == .some(nil))
        model.finishAccountDeletion()
        #expect(delivered.count == 1)
    }

    @Test("Recusas e falhas da exclusão mantêm a conta e explicam o motivo", arguments: [
        (UAPPAccountDeletionError.activeAppStoreSubscription as any Error, "user.delete_account.subscription_error"),
        (UAPPAccountDeletionError.organizationOwnershipTransferRequired as any Error, "user.delete_account.owner_error"),
        (UAPPKitError.http(status: 500, message: nil) as any Error, "user.delete_account.error")
    ])
    func deleteAccountFailure(error: any Error, key: String) async throws {
        let provider = DeletionProviderStub(outcome: .failure(error))
        let session = try #require(await provider.currentSession())
        var delivered = false
        let model = UAPPUserModel(session: session, authentication: provider) { _ in delivered = true }
        await model.deleteAccount()
        #expect(model.errorKey == key)
        #expect(model.session == session)
        #expect(model.accountDeletion == nil)
        #expect(!model.isBusy)
        #expect(!delivered)
        #expect(await provider.currentSession() == session)
        await provider.setOutcome(.success(UAPPAccountDeletion()))
        await model.deleteAccount()
        #expect(model.errorKey == nil)
        #expect(model.accountDeletion != nil)
    }

    @Test("Tela fechada durante a exclusão avisa o aplicativo assim que o servidor confirma")
    func deleteAccountAfterScreenClosed() async throws {
        let provider = DeletionProviderStub()
        let session = try #require(await provider.currentSession())
        var delivered: [UAPPAuthenticationSession?] = []
        let model = UAPPUserModel(session: session, authentication: provider) { delivered.append($0) }
        model.screenDidDisappear()
        #expect(delivered.isEmpty)
        await model.deleteAccount()
        #expect(model.accountDeletion == nil)
        #expect(model.session == nil)
        #expect(delivered.count == 1)
    }

    @Test("Provedor do aplicativo sem exclusão não mostra nem executa a ação")
    func deleteAccountUnsupported() async throws {
        let provider = UserProviderStub(mode: .success)
        let session = try #require(await provider.currentSession())
        let model = UAPPUserModel(session: session, authentication: provider) { _ in }
        #expect(!model.supportsAccountDeletion)
        await model.deleteAccount()
        #expect(model.session == session)
        #expect(model.errorKey == nil)
        #expect(model.accountDeletion == nil)
        #expect(!UAPPUserModel().supportsAccountDeletion)
        await #expect(throws: UAPPAuthenticationError.unsupportedMethod) {
            try await provider.deleteAccount()
        }
    }
}

private actor UserProviderStub: UAPPAuthenticationProvider {
    enum Mode: Sendable { case success, keepSession, clearThenFail }
    nonisolated let methods: [UAPPLoginMethod] = [.email]
    private var mode: Mode
    private var session: UAPPAuthenticationSession? = .init(
        identity: .init(userId: "test-user", displayName: "Visitante"), accessToken: "fake-token"
    )

    init(mode: Mode) {
        self.mode = mode
    }

    func setMode(_ mode: Mode) {
        self.mode = mode
    }

    func currentSession() async -> UAPPAuthenticationSession? {
        session
    }

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
