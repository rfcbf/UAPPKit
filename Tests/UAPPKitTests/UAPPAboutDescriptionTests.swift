import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@Test("Descrição do Sobre ignora texto vazio e apara espaços")
func aboutDescriptionIgnoresBlankText() {
    #expect(UAPPAboutDescription(text: nil, languageIdentifier: "pt-BR") == nil)
    #expect(UAPPAboutDescription(text: "  \n ", languageIdentifier: "pt-BR") == nil)

    let description = UAPPAboutDescription(text: "  Um **app** simples. ", languageIdentifier: "en")
    #expect(description?.text == "Um **app** simples.")
    #expect(description?.languageIdentifier == "en")
}

@Test("Sobre decodifica a descrição do aplicativo quando o servidor a envia")
func aboutDecodesAppDescription() throws {
    let with = try JSONDecoder().decode(
        UAPPAbout.self,
        from: json(#"{"developer_name":"Ana","app_description":"Um **app** simples."}"#)
    )
    #expect(with.appDescription == "Um **app** simples.")

    let without = try JSONDecoder().decode(UAPPAbout.self, from: json(#"{"developer_name":"Ana"}"#))
    #expect(without.appDescription == nil)
}

@Test("Descrição do servidor tem precedência sobre a da configuração")
@MainActor
func aboutPrefersServerDescription() async {
    let palette = UAPPTheme.system.resolved(for: .light)
    let metadata = UAPPAppMetadata(name: "Agenda", version: "1.0.0", build: "1")
    let configuration = UAPPAboutConfiguration(shortDescription: "Local", descriptionLanguageIdentifier: "pt-BR")
    let server = UAPPAboutDescription(text: "- Servidor\n- **Lista**", languageIdentifier: "en")

    var identity = UAPPAboutAppIdentity(
        metadata: metadata,
        configuration: configuration,
        presentationLanguageIdentifier: "pt-BR",
        palette: palette,
        remoteIconURL: nil
    )
    #expect(identity.description?.text == "Local")
    #expect(identity.description?.languageIdentifier == "pt-BR")
    await render(identity)

    identity.serverDescription = server
    #expect(identity.description == server)
    await render(identity)

    let empty = UAPPAboutAppIdentity(
        metadata: metadata,
        configuration: UAPPAboutConfiguration(),
        presentationLanguageIdentifier: "pt-BR",
        palette: palette,
        remoteIconURL: nil
    )
    #expect(empty.description == nil)
    await render(empty)

    let client = makeClient { _ in
        response(#"{"about":{"developer_name":"Ana","app_description":"Um **app** simples."}}"#)
    }
    await render(NavigationStack {
        UAPPAboutScreen(configuration: configuration, client: client)
    })
}
