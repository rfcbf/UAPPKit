import Foundation
import SwiftUI
import Testing
@testable import UAPPKit

@Test("perfil local preserva identidade e participa sem abrir autenticação")
@MainActor
func participationUsesLocalProfile() async {
    let client = makeClient { _ in response(#"{"items":[]}"#) }
    let identity = UAPPIdentity(userId: "local-profile", email: "visitor@example.test",
                                displayName: "Visitante", avatarURL: URL(fileURLWithPath: "/tmp/profile.jpg"))
    await client.setIdentity(identity)
    let model = UAPPParticipationModel(client: client)
    await model.refresh()
    #expect(model.identity == identity)
    #expect(model.session == nil)
    var performed = false
    await model.perform { performed = true }
    #expect(performed)
    #expect(!model.showsAccount)
    #expect(await client.currentIdentity() == identity)
    await client.setIdentity(nil)
    await model.refresh()
    #expect(model.identity == nil)
}

@Test("participação pede login, retoma ação e respeita cancelamento")
@MainActor
func participationLoginResumesAction() async {
    let provider = StubAuthentication()
    let client = await makeClient { _ in response(#"{"items":[]}"#) }.withAuthentication(provider: provider)
    let model = UAPPParticipationModel(client: client)
    var count = 0
    #expect(model.isEnabled)
    #expect(model.methods.count == 4)
    await model.perform { count += 1 }
    #expect(model.showsAccount)
    #expect(count == 0)
    await model.finishPresentation()
    #expect(count == 0)
    await model.perform { count += 1 }
    await model.signIn(.apple)
    #expect(model.session?.identity.userId == "verified")
    #expect(!model.showsAccount)
    await model.finishPresentation()
    #expect(count == 1)
    await model.perform { count += 1 }
    #expect(count == 2)
    await model.signOut()
    #expect(model.session == nil)
    #expect(await client.currentIdentity() == nil)
}

@Test("participação trata falhas, cancelamento OAuth e sessão perdida")
@MainActor
func participationHandlesAuthenticationErrors() async {
    let provider = StubAuthentication()
    let client = UAPPClient(configuration: .init(projectId: "app"), authentication: provider)
    let model = UAPPParticipationModel(client: client)
    await provider.setSessionFails(true)
    await model.refresh()
    #expect(model.errorKey == "auth.session_error")
    await provider.setSessionFails(false)
    await provider.setError(.cancelled)
    await model.signIn(.google)
    #expect(model.errorKey == nil)
    await provider.setError(.unsupportedMethod)
    await model.signIn(.google)
    #expect(model.errorKey == "auth.signin_error")
    await model.signOut()
    #expect(model.errorKey == "auth.signout_error")
    await provider.setError(nil)
    await model.signIn(.github)
    await provider.setError(.unsupportedMethod)
    await model.signOut()
    #expect(model.session != nil)
    await model.refresh()
    #expect(model.session != nil)
}

@Test("formulário OTP fixa e-mail de verificação e limpa código ao entrar")
@MainActor
func participationEmailFlow() async {
    let provider = StubAuthentication()
    let client = UAPPClient(configuration: .init(projectId: "app"), authentication: provider)
    let model = UAPPParticipationModel(client: client)
    #expect(!model.canRequestCode)
    await model.verifyEmailCode()
    await model.requestEmailCode()
    model.email = " person@example.test "
    #expect(model.canRequestCode)
    await provider.setError(.unsupportedMethod)
    await model.requestEmailCode()
    #expect(model.errorKey == "auth.email_error")
    await provider.setError(nil)
    await model.requestEmailCode()
    #expect(await provider.requestedEmail == "person@example.test")
    #expect(model.emailCodeSent)
    await model.verifyEmailCode()
    #expect(model.session == nil)
    model.changeEmail()
    #expect(!model.emailCodeSent)
    await model.requestEmailCode()
    model.code = "123456"
    await model.verifyEmailCode()
    #expect(model.session != nil)
    #expect(model.code.isEmpty)
    #expect(!model.emailCodeSent)
}

@Test("cliente sem autenticação mantém comportamento anterior")
@MainActor
func participationWithoutAdapterIsCompatible() async {
    let model = UAPPParticipationModel(client: makeClient { _ in response(#"{"items":[]}"#) })
    var performed = false
    await model.refresh()
    await model.signIn(.apple)
    await model.signOut()
    await model.requestEmailCode()
    await model.verifyEmailCode()
    await model.perform { performed = true }
    #expect(performed)
    #expect(!model.isEnabled)
}

@Test("tela de conta renderiza formulário, OTP e perfil conectado")
@MainActor
func authenticationScreenRendersStates() async {
    let provider = StubAuthentication()
    let client = UAPPClient(configuration: .init(projectId: "app"), authentication: provider)
    let model = UAPPParticipationModel(client: client)
    await render(UAPPAuthenticationScreen(model: model, accentColor: .blue))
    model.email = "person@example.test"
    await model.requestEmailCode()
    await render(UAPPAuthenticationScreen(model: model, accentColor: .blue))
    await provider.setError(.unsupportedMethod)
    model.code = "123456"
    await model.verifyEmailCode()
    await render(UAPPAuthenticationScreen(model: model, accentColor: .blue))
    await provider.setError(nil)
    await model.signIn(.apple)
    await render(UAPPAuthenticationScreen(model: model, accentColor: .blue))
}

@Test("cliente gerenciado permite leitura pública mas impede escrita sem sessão")
func managedClientRequiresSessionOnlyForParticipation() async throws {
    let provider = StubAuthentication()
    let recorder = RequestRecorder()
    let base = makeClient(recorder: recorder) { _ in response(#"{"items":[],"entries":[],"reviews":[],"about":{},"ok":true}"#) }
    let client = await base.withAuthentication(provider: provider)
    await provider.setSessionFails(true)
    _ = try await client.feedback()
    _ = try await client.changelog()
    _ = try await client.reviews()
    _ = try await client.about()
    await provider.setSessionFails(false)
    await #expect(throws: UAPPAuthenticationError.signInRequired) { try await client.submitFeedback(title: "Novo") }
    await #expect(throws: UAPPAuthenticationError.signInRequired) { try await client.submitComment(itemId: "item", body: "Mensagem") }
    await #expect(throws: UAPPAuthenticationError.signInRequired) { try await client.setReaction(itemId: "item", kind: .vote, enabled: true) }
    #expect(recorder.requests.count == 4)
    _ = try await provider.signIn(method: .apple)
    _ = try await client.submitFeedback(title: "Novo")
    _ = try await client.submitComment(itemId: "item", body: "Mensagem")
    try await client.setReaction(itemId: "item", kind: .vote, enabled: true)
    #expect(recorder.requests.suffix(3).allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer verified-token" })
    let data = try #require(recorder.requests[4].httpBody)
    let payload = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
    #expect(payload["email"] == "person@example.test")
    #expect(payload["displayName"] == "Pessoa")
    #expect(await base.currentIdentity() == nil)
}
