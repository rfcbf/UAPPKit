import Foundation
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@Test("configuração deriva a URL de functions do host")
func configurationDerivesFunctionsURL() throws {
    let configuration = try UAPPConfiguration(
        projectId: "meu-app",
        host: #require(URL(string: "https://exemplo.uapp.com/api"))
    )

    #expect(configuration.projectId == "meu-app")
    #expect(configuration.host.absoluteString == "https://exemplo.uapp.com/api")
    #expect(configuration.functionsBaseURL.absoluteString == "https://exemplo.uapp.com/api/functions/v1")
    #expect(configuration.signatureProvider == nil)
}

@Test("configuração usa o host de produção por padrão")
func configurationUsesProductionHostByDefault() {
    let configuration = UAPPConfiguration(projectId: "meu-app")

    #expect(configuration.host == UAPPConfiguration.defaultHost)
    #expect(configuration.host.absoluteString == "https://qyjxwtvfmrkfcvisipke.supabase.co")
}

@Test("APIs públicas usam sempre o servidor de produção")
func publicAPIsUseProductionServer() async throws {
    #expect(UAPPAuthenticationConfiguration(publishableKey: "chave-publica").host == UAPPConfiguration.defaultHost)
    let custom = try UAPPAuthenticationConfiguration(
        host: #require(URL(string: "https://outro.uapp.test")), publishableKey: "chave"
    )
    #expect(custom.host.host == "outro.uapp.test")

    let recorder = RequestRecorder()
    let activity = UAPPClient(accountActivityTransport: StubTransport { request in
        recorder.record(request)
        return (200, Data(#"{"items":[],"apps":[]}"#.utf8))
    })
    _ = try? await activity.userActivity(
        session: UAPPAuthenticationSession(identity: .init(userId: "conta"), accessToken: "token")
    )
    #expect(recorder.requests.first?.url?.host == UAPPConfiguration.defaultHost.host)
}

@Test("configuração preserva o locale inicial")
func configurationPreservesLocale() {
    let configuration = UAPPConfiguration(
        projectId: "meu-app",
        locale: Locale(identifier: "de")
    )

    #expect(configuration.localeIdentifier == "de")
}

@Test("idiomas suportados mantêm os identificadores públicos")
func supportedLanguagesHaveStableIdentifiers() {
    #expect(UAPPLanguage.supported.map(\.identifier) == [
        "pt-BR", "en", "de", "fr", "es", "ja", "zh-Hans", "zh-Hant",
        "pl", "hi", "vi", "it", "ko"
    ])
}

@Test("identidade preserva todos os campos ao codificar e decodificar")
func identityRoundTrips() throws {
    let identity = UAPPIdentity(
        userId: "u1",
        email: "u1@example.test",
        displayName: "Renato",
        traits: ["plan": "pro"]
    )
    let data = try JSONEncoder().encode(identity)
    let decoded = try JSONDecoder().decode(UAPPIdentity.self, from: data)

    #expect(decoded == identity)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["userId"] as? String == "u1")
    #expect((object["traits"] as? [String: String])?["plan"] == "pro")
}
