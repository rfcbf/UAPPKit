import Foundation
import Testing
@testable import UAPPKit

@MainActor
struct UAPPAccountModelTests {
    @Test("Cadastro e recuperação bloqueiam senha fraca antes de chamar o provedor", arguments: [
        "Abcdef!", "abcdefgh!", "Abcdefgh", "Abcdefg "
    ])
    func weakPasswordCannotSubmit(_ password: String) async {
        let provider = AccountProviderStub()
        let model = UAPPAccountModel(provider: provider, minimumPasswordLength: 6) { _ in
            Issue.record("Senha fraca não deve entregar sessão")
        }
        model.navigate(to: .signup)
        model.name = "Visitante"
        model.email = "person@example.test"
        model.password = password
        model.passwordConfirmation = password
        #expect(!model.canSubmit)
        await model.submit()
        #expect(model.step == .signup)
        model.navigate(to: .recover)
        await model.submit()
        model.code = "123456"
        await model.submit()
        model.password = password
        model.passwordConfirmation = password
        #expect(!model.canSubmit)
        await model.submit()
        #expect(model.step == .newPassword)
        #expect(model.session == nil)
    }

    @Test("Cadastro confirma e-mail antes de entregar sessão e limpa senhas")
    func signup() async {
        let provider = AccountProviderStub()
        var delivered: UAPPAuthenticationSession?
        let model = UAPPAccountModel(provider: provider, minimumPasswordLength: 8) { delivered = $0 }
        model.navigate(to: .signup)
        model.email = " person@example.test "
        model.password = "Test-password"
        model.passwordConfirmation = "different"
        #expect(!model.canSubmit)
        model.passwordConfirmation = model.password
        #expect(!model.canSubmit)
        model.name = "   "
        #expect(!model.canSubmit)
        model.name = "Visitante"
        #expect(model.canSubmit)
        await model.submit()
        #expect(model.step == .confirmSignup)
        #expect(model.pendingEmail == "person@example.test")
        #expect(model.password.isEmpty)
        #expect(delivered == nil)
        model.code = "123456"
        await model.submit()
        #expect(delivered?.identity.userId == "verified")
        #expect(model.code.isEmpty)
    }

    @Test("Recuperação exige código antes de atualizar senha e entrega sessão apenas ao concluir")
    func recovery() async throws {
        let provider = AccountProviderStub()
        var delivered: UAPPAuthenticationSession?
        let model = UAPPAccountModel(provider: provider, minimumPasswordLength: 8) { delivered = $0 }
        model.email = "person@example.test"
        model.navigate(to: .recover)
        await model.submit()
        #expect(model.step == .verifyRecovery)
        model.code = "123456"
        await model.submit()
        #expect(model.step == .newPassword)
        #expect(delivered == nil)
        model.password = "New-test-password"
        model.passwordConfirmation = model.password
        await model.submit()
        #expect(delivered?.identity.userId == "verified")
        #expect(model.password.isEmpty)
        #expect(model.noticeKey == "account.password_updated")
        await model.cancelRecovery()
        #expect(try await provider.currentSession() == delivered)
    }

    @Test("Foto aguarda confirmação e falha permite repetir somente o envio")
    func signupPhotoRetry() async {
        let provider = AccountProviderStub(failsPhotoOnce: true)
        var delivered: UAPPAuthenticationSession?
        let model = UAPPAccountModel(provider: provider, minimumPasswordLength: 8) { delivered = $0 }
        model.navigate(to: .signup)
        model.name = "Visitante"
        model.email = "person@example.test"
        model.password = "Test-password"
        model.passwordConfirmation = model.password
        model.photo = Data([0xFF, 0xD8, 0xFF])
        await model.submit()
        #expect(await provider.photoAttempts == 0)
        model.code = "123456"
        await model.submit()
        #expect(delivered == nil)
        #expect(model.isCompletingSignup)
        #expect(model.canSubmit)
        #expect(model.code.isEmpty)
        #expect(model.errorKey == "photo.upload_error")
        await model.submit()
        #expect(await provider.photoAttempts == 2)
        #expect(await provider.confirmationAttempts == 1)
        #expect(delivered?.identity.avatarURL == URL(string: "https://example.test/avatar.jpg"))
        #expect(!model.isCompletingSignup)
        #expect(model.photo == nil)
    }

    @Test("Remover foto após falha conclui cadastro sem outro envio")
    func signupPhotoRemoval() async {
        let provider = AccountProviderStub(failsPhotoOnce: true)
        var delivered: UAPPAuthenticationSession?
        let model = UAPPAccountModel(provider: provider, minimumPasswordLength: 8) { delivered = $0 }
        model.navigate(to: .signup)
        model.name = "Visitante"
        model.email = "person@example.test"
        model.password = "Test-password"
        model.passwordConfirmation = model.password
        model.photo = Data([0xFF, 0xD8, 0xFF])
        await model.submit()
        model.code = "123456"
        await model.submit()
        model.photo = nil
        await model.submit()
        #expect(delivered?.identity.userId == "verified")
        #expect(await provider.photoAttempts == 1)
        #expect(await provider.confirmationAttempts == 1)
    }

    @Test("Falha de login não entrega sessão e permite tentar novamente")
    func failure() async {
        let model = UAPPAccountModel(provider: AccountProviderStub(), minimumPasswordLength: 8) { _ in
            Issue.record("Falha não deve entregar sessão")
        }
        model.email = "person@example.test"
        model.password = "wrong"
        await model.submit()
        #expect(model.session == nil)
        #expect(model.errorKey == "account.login_error")
        #expect(!model.isBusy)
        #expect(model.canSubmit)
    }

    @Test("Cancelar recuperação limpa a sessão temporária")
    func cancelRecovery() async throws {
        let provider = AccountProviderStub()
        let model = UAPPAccountModel(provider: provider, minimumPasswordLength: 8) { _ in }
        model.email = "person@example.test"
        model.navigate(to: .recover)
        await model.submit()
        model.code = "123456"
        await model.submit()
        await model.cancelRecovery()
        #expect(try await provider.currentSession() == nil)
    }

    @Test("Login social entrega sessão e sair limpa conta, foto e etapa")
    func socialSignInAndSignOut() async {
        var delivered: [UAPPAuthenticationSession?] = []
        let model = UAPPAccountModel(provider: AccountProviderStub(), minimumPasswordLength: 8) { delivered.append($0) }
        await model.refresh()
        #expect(model.session == nil)
        await model.signIn(.apple)
        #expect(model.session?.identity.userId == "verified")
        model.photo = Data([0x01])
        model.navigate(to: .signup)
        await model.signOut()
        #expect(model.session == nil)
        #expect(model.photo == nil)
        #expect(model.step == .login)
        #expect(delivered.count == 2)
        #expect(delivered.last.flatMap(\.self) == nil)
    }

    @Test("Reenvio de código vale só para confirmação e recuperação")
    func resendCode() async {
        let model = UAPPAccountModel(provider: AccountProviderStub(), minimumPasswordLength: 8) { _ in }
        await model.resendCode()
        #expect(model.noticeKey == nil)
        model.navigate(to: .signup)
        model.name = "Visitante"
        model.email = "person@example.test"
        model.password = "Test-password"
        model.passwordConfirmation = "Test-password"
        await model.submit()
        await model.resendCode()
        #expect(model.noticeKey == "account.resent")
        let recovery = UAPPAccountModel(provider: AccountProviderStub(), minimumPasswordLength: 8) { _ in }
        recovery.email = "person@example.test"
        recovery.navigate(to: .recover)
        await recovery.submit()
        await recovery.resendCode()
        #expect(recovery.noticeKey == "account.resent")
    }

    @Test("Operações sem suporte e falhas de saída informam erro sem fechar a conta")
    func unsupportedAndFailedOperations() async {
        let provider = StubAuthentication()
        let model = UAPPAccountModel(provider: provider, minimumPasswordLength: 6) { _ in }
        #expect(model.minimumPasswordLength == 8)
        model.navigate(to: .signup)
        model.name = "Visitante"
        model.email = "person@example.test"
        model.password = "Test-password"
        model.passwordConfirmation = "Test-password"
        await model.submit()
        #expect(model.errorKey == "account.unsupported")
        await provider.setError(.cancelled)
        await model.signIn(.google)
        #expect(model.errorKey == nil)
        await provider.setError(.invalidCallback)
        await model.signOut()
        #expect(model.errorKey == "auth.signout_error")
        await provider.setSessionFails(true)
        await model.refresh()
        #expect(model.errorKey == "account.operation_error")
    }
}

actor AccountProviderStub: UAPPAuthenticationProvider {
    nonisolated let methods = UAPPLoginMethod.allCases
    nonisolated let supportsProfilePhoto = true
    private var failsPhotoOnce: Bool
    private(set) var photoAttempts = 0
    private(set) var confirmationAttempts = 0
    private var session: UAPPAuthenticationSession?
    private let result = UAPPAuthenticationSession(identity: .init(userId: "verified"), accessToken: "fake-token")
    init(failsPhotoOnce: Bool = false) {
        self.failsPhotoOnce = failsPhotoOnce
    }

    func uploadProfilePhoto(_: Data) async throws -> UAPPAuthenticationSession {
        photoAttempts += 1
        if failsPhotoOnce {
            failsPhotoOnce = false
            throw UAPPKitError.invalidResponse
        }
        let updated = UAPPAuthenticationSession(
            identity: .init(userId: "verified", avatarURL: URL(string: "https://example.test/avatar.jpg")),
            accessToken: "fake-token"
        )
        session = updated
        return updated
    }

    func currentSession() async throws -> UAPPAuthenticationSession? {
        session
    }

    func signIn(method _: UAPPLoginMethod) async throws -> UAPPAuthenticationSession {
        session = result
        return result
    }

    func signIn(email _: String, password: String) async throws -> UAPPAuthenticationSession {
        guard password != "wrong" else { throw UAPPAuthenticationError.signInRequired }
        return try await signIn(method: .email)
    }

    func signUp(email _: String, password _: String, displayName _: String?) async throws -> UAPPRegistrationResult {
        .confirmationRequired
    }

    func resendSignupCode(email _: String) async throws {}
    func verifySignupCode(email _: String, code _: String) async throws -> UAPPAuthenticationSession {
        confirmationAttempts += 1
        return try await signIn(method: .email)
    }

    func requestPasswordReset(email _: String) async throws {}
    func verifyPasswordResetCode(email _: String, code _: String) async throws {
        session = result
    }

    func updatePassword(_: String) async throws -> UAPPAuthenticationSession {
        result
    }

    func signOut() async throws {
        session = nil
    }
}
