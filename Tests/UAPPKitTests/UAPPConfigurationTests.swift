import Foundation
import Testing
@testable import UAPPKit

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
