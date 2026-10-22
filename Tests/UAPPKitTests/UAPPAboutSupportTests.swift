import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@Test("Suporte do Sobre usa o e-mail do servidor antes do link da configuração")
func aboutSupportPrefersServerEmail() {
    let link = URL(string: "https://example.com/suporte")
    let configuration = UAPPAboutConfiguration(supportURL: link)

    #expect(
        UAPPAboutScreen.supportURL(configuration: configuration, serverEmail: " suporte@example.com ")?
            .absoluteString == "mailto:suporte@example.com"
    )
    #expect(UAPPAboutScreen.supportURL(configuration: configuration, serverEmail: nil) == link)
    #expect(UAPPAboutScreen.supportURL(configuration: configuration, serverEmail: "  ") == link)
    #expect(UAPPAboutScreen.supportURL(configuration: configuration, serverEmail: "sem-arroba") == link)
    #expect(UAPPAboutScreen.supportURL(configuration: configuration, serverEmail: "a b@example.com") == link)
    #expect(UAPPAboutScreen.supportURL(configuration: .init(), serverEmail: nil) == nil)
}

@Test("Sobre do desenvolvedor decodifica o e-mail de suporte quando o servidor o envia")
func aboutDecodesSupportEmail() throws {
    let with = try JSONDecoder().decode(
        UAPPAbout.self,
        from: json(#"{"developer_name":"Ana","support_email":"suporte@example.com"}"#)
    )
    #expect(with.supportEmail == "suporte@example.com")

    let without = try JSONDecoder().decode(UAPPAbout.self, from: json(#"{"developer_name":"Ana"}"#))
    #expect(without.supportEmail == nil)
}

@Test("Configuração do Sobre guarda a opção de avaliações")
func aboutConfigurationKeepsReviewOptions() {
    let standard = UAPPAboutConfiguration()
    #expect(!standard.showsReviews && standard.reviewsPageSize == 10)

    let custom = UAPPAboutConfiguration(showsReviews: true, reviewsPageSize: 25)
    #expect(custom.showsReviews && custom.reviewsPageSize == 25)
    #expect(custom != standard)
}

@Test("Sobre mostra a versão do UAPPKit só quando a configuração pede")
@MainActor
func aboutConfigurationKeepsKitVersionOption() async {
    let standard = UAPPAboutConfiguration()
    #expect(!standard.showsKitVersion)

    let withKit = UAPPAboutConfiguration(showsKitVersion: true)
    #expect(withKit.showsKitVersion)
    #expect(withKit != standard)
    #expect(UAPPAboutAppIdentity.kitVersionText.contains(UAPPKit.version))

    await render(UAPPAboutScreen(configuration: withKit))
}

@Test("Sobre monta a ação de avaliações e o suporte por e-mail")
@MainActor
func aboutRendersReviewsAndSupportRows() async {
    let palette = UAPPTheme.system.resolved(for: .light)
    await render(UAPPAboutResources(
        configuration: UAPPAboutConfiguration(showsReviews: true),
        palette: palette,
        isOpeningAppStoreReview: false,
        onOpenAppStoreReview: nil,
        onOpenChangelog: nil,
        supportURL: URL(string: "mailto:suporte@example.com"),
        onOpenReviews: {}
    ))
    await render(UAPPAboutResources(
        configuration: UAPPAboutConfiguration(showsReviews: true),
        palette: palette,
        isOpeningAppStoreReview: false,
        onOpenAppStoreReview: nil,
        onOpenChangelog: nil
    ))

    let client = makeClient { _ in
        response(#"{"about":{"developer_name":"Ana","support_email":"suporte@example.com"}}"#)
    }
    await render(NavigationStack {
        UAPPAboutScreen(configuration: UAPPAboutConfiguration(showsReviews: true), client: client)
    })
}

@Test("Mensagem de suporte leva o nome do app no assunto e os dados do aparelho no corpo")
func supportMailCarriesSubjectAndDeviceInformation() throws {
    let metadata = UAPPAppMetadata(name: "Agenda", version: "1.2.0", build: "34")
    let device = UAPPSupportDevice(system: "iOS 18.2", model: "iPhone17,1")

    #expect(
        UAPPSupportMail.subject(appName: "Agenda", topic: .question, languageIdentifier: "pt-BR")
            == "[Agenda] [Dúvida] - "
    )
    #expect(
        UAPPSupportMail.subject(appName: "Agenda", topic: .problem, languageIdentifier: "en")
            == "[Agenda] [Problem] - "
    )

    let body = UAPPSupportMail.body(metadata: metadata, device: device, languageIdentifier: "pt-BR")
    #expect(body.hasPrefix("\r\n\r\n----------"))
    #expect(body.contains("App: Agenda 1.2.0 (34)"))
    #expect(body.contains("Sistema: iOS 18.2"))
    #expect(body.contains("Aparelho: iPhone17,1"))
    #expect(body.contains("Idioma: pt-BR"))

    let noModel = UAPPSupportMail.body(
        metadata: metadata,
        device: UAPPSupportDevice(system: "macOS 15.0.0", model: ""),
        languageIdentifier: "en"
    )
    #expect(!noModel.contains("Device:"))

    let url = try #require(UAPPSupportMail.url(
        email: " suporte@example.com ",
        metadata: metadata,
        topic: .suggestion,
        device: device,
        languageIdentifier: "pt-BR"
    ))
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    #expect(components.scheme == "mailto")
    #expect(components.path == "suporte@example.com")
    let subject = components.queryItems?.first { $0.name == "subject" }?.value
    #expect(subject == "[Agenda] [Sugestão] - ")
    #expect(components.queryItems?.first { $0.name == "body" }?.value == body)
    #expect(!url.absoluteString.contains(" "))

    #expect(UAPPSupportMail.address("sem-arroba") == nil)
    #expect(UAPPSupportMail.address("a b@example.com") == nil)
    #expect(UAPPSupportMail.address(nil) == nil)
    #expect(
        UAPPSupportMail.url(
            email: "sem-arroba", metadata: metadata, topic: .question, device: device, languageIdentifier: "en"
        ) == nil
    )
    #expect(Set(UAPPSupportTopic.allCases.map(\.systemImage)).count == 3)
}

@Test("Sem app de e-mail, o suporte informa o endereço para a pessoa escrever")
@MainActor
func supportMailReportsWhenNoMailAppOpens() async throws {
    let url = try #require(URL(string: "mailto:suporte@example.com"))

    #expect(await UAPPAboutScreen.openSupportMail(url, email: "suporte@example.com") { _ in true } == nil)
    let refused = await UAPPAboutScreen.openSupportMail(url, email: "suporte@example.com") { _ in false }
    #expect(refused?.contains("suporte@example.com") == true)
    let missing = await UAPPAboutScreen.openSupportMail(nil, email: "suporte@example.com") { _ in true }
    #expect(missing?.contains("suporte@example.com") == true)

    let device = UAPPSupportDevice.current()
    #expect(!device.system.isEmpty)
}

@Test("Sobre monta o menu de motivos quando há e-mail de suporte")
@MainActor
func aboutRendersSupportTopicMenu() async {
    await render(UAPPAboutResources(
        configuration: UAPPAboutConfiguration(),
        palette: UAPPTheme.system.resolved(for: .light),
        isOpeningAppStoreReview: false,
        onOpenAppStoreReview: nil,
        onOpenChangelog: nil,
        supportURL: URL(string: "mailto:suporte@example.com"),
        onContactSupport: { _ in }
    ))
    await render(UAPPSupportTopicSheet(palette: UAPPTheme.system.resolved(for: .dark)) { _ in })
}
