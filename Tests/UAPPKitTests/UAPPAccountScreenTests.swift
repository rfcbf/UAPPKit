import Foundation
import SwiftUI
import Testing
@testable import UAPPKit

@MainActor
struct UAPPAccountScreenTests {
    private func model(
        provider: any UAPPAuthenticationProvider = AccountProviderStub()
    ) -> UAPPAccountModel {
        UAPPAccountModel(provider: provider, minimumPasswordLength: 8) { _ in }
    }

    private func renderStep(_ model: UAPPAccountModel, path: [UAPPAccountModel.Step]) async {
        await render(UAPPAccountScreen(
            model: model, appName: "Aplicativo",
            theme: .init(light: .init(accent: .orange)),
            termsURL: URL(string: "https://example.test/terms"),
            privacyURL: URL(string: "https://example.test/privacy"),
            testingPath: path
        ))
    }

    @Test("Boas-vindas e cada etapa da conta constroem a interface")
    func everyStepRenders() async {
        await renderStep(model(), path: [])
        for step: UAPPAccountModel.Step in [.login, .signup, .recover, .confirmSignup, .verifyRecovery, .newPassword] {
            let model = model()
            model.navigate(to: step)
            model.email = "person@example.test"
            model.password = "test-password"
            model.passwordConfirmation = "test-password"
            model.code = "123456"
            await renderStep(model, path: [step])
        }
    }

    @Test("Avisos, erros e conclusão do cadastro com foto aparecem na tela")
    func statusAndPhotoCompletionRender() async {
        let recovery = model()
        recovery.email = "person@example.test"
        recovery.navigate(to: .recover)
        await recovery.submit()
        #expect(recovery.noticeKey == "account.recovery_sent")
        await renderStep(recovery, path: [.recover, .verifyRecovery])

        let failing = model()
        failing.email = "person@example.test"
        failing.password = "wrong"
        await failing.submit()
        #expect(failing.errorKey == "account.login_error")
        await renderStep(failing, path: [.login])

        let photo = model(provider: AccountProviderStub(failsPhotoOnce: true))
        photo.navigate(to: .signup)
        photo.name = "Visitante"
        photo.email = "person@example.test"
        photo.password = "test-password"
        photo.passwordConfirmation = "test-password"
        photo.photo = Data([0xFF, 0xD8, 0xFF])
        await photo.submit()
        photo.code = "123456"
        await photo.submit()
        #expect(photo.isCompletingSignup)
        await renderStep(photo, path: [.signup, .confirmSignup])
    }

    @Test("Provedor somente social não exibe campos de e-mail")
    func socialOnlyProviderRenders() async {
        await renderStep(model(provider: SocialOnlyProvider()), path: [.login])
    }

    @Test("Tela pública carrega identidade do app e encerra se já houver sessão")
    func publicInitializerLoadsIdentity() async {
        let client = makeClient { _ in
            response(#"{"project":{"slug":"meu-app","displayName":"Aplicativo Remoto"},"about":{}}"#)
        }
        await render(UAPPAccountScreen(
            authentication: AccountProviderStub(), client: client, appName: "Aplicativo"
        ), settling: true)
        let connected = StubAuthentication()
        await connected.setSession(UAPPAuthenticationSession(identity: .init(userId: "verified"), accessToken: "token"))
        await render(UAPPAccountScreen(authentication: connected), settling: true)
    }

    @Test("Ícones de login cobrem todos os provedores")
    func loginServiceIconsRender() async {
        for method in UAPPLoginMethod.allCases {
            await render(UAPPLoginServiceIcon(method: method))
        }
    }

    @Test("Operações opcionais do provedor informam ausência de suporte")
    func providerDefaultsAreUnsupported() async {
        let provider = SocialOnlyProvider()
        #expect(!provider.supportsProfilePhoto)
        await #expect(throws: UAPPAuthenticationError.unsupportedMethod) {
            try await provider.uploadProfilePhoto(Data())
        }
        await #expect(throws: UAPPAuthenticationError.unsupportedMethod) {
            try await provider.signIn(email: "person@example.test", password: "test-password")
        }
        await #expect(throws: UAPPAuthenticationError.unsupportedMethod) {
            try await provider.signUp(email: "person@example.test", password: "test-password", displayName: nil)
        }
        await #expect(throws: UAPPAuthenticationError.unsupportedMethod) {
            try await provider.resendSignupCode(email: "person@example.test")
        }
        await #expect(throws: UAPPAuthenticationError.unsupportedMethod) {
            try await provider.verifySignupCode(email: "person@example.test", code: "123456")
        }
        await #expect(throws: UAPPAuthenticationError.unsupportedMethod) {
            try await provider.requestPasswordReset(email: "person@example.test")
        }
        await #expect(throws: UAPPAuthenticationError.unsupportedMethod) {
            try await provider.verifyPasswordResetCode(email: "person@example.test", code: "123456")
        }
        await #expect(throws: UAPPAuthenticationError.unsupportedMethod) {
            try await provider.updatePassword("test-password")
        }
        await #expect(throws: UAPPAuthenticationError.unsupportedMethod) {
            try await provider.requestEmailCode(email: "person@example.test")
        }
        await #expect(throws: UAPPAuthenticationError.unsupportedMethod) {
            try await provider.verifyEmailCode(email: "person@example.test", code: "123456")
        }
    }
}

/// Provedor mínimo: somente métodos sociais, usando as implementações padrão.
private struct SocialOnlyProvider: UAPPAuthenticationProvider {
    let methods: [UAPPLoginMethod] = [.apple, .google]
    func currentSession() async throws -> UAPPAuthenticationSession? { nil }
    func signIn(method _: UAPPLoginMethod) async throws -> UAPPAuthenticationSession {
        throw UAPPAuthenticationError.cancelled
    }
    func signOut() async throws {}
}
