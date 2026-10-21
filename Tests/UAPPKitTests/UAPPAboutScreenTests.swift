import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@Test("UAPPAboutConfiguration mantém o conteúdo institucional do aplicativo")
func aboutConfigurationKeepsAppContent() {
    let configuration = UAPPAboutConfiguration(
        shortDescription: "Uma descrição curta",
        descriptionLanguageIdentifier: "pt-BR",
        websiteURL: URL(string: "https://example.com"),
        supportURL: URL(string: "mailto:help@example.com"),
        privacyPolicyURL: URL(string: "https://example.com/privacy"),
        termsOfUseURL: URL(string: "https://example.com/terms"),
        license: "MIT",
        showsChangelog: true,
        showsAppStoreReview: true,
        changelogConfiguration: .init(automaticallyScrolls: true, interval: 5)
    )

    #expect(configuration.shortDescription == "Uma descrição curta")
    #expect(configuration.descriptionLanguageIdentifier == "pt-BR")
    #expect(configuration.websiteURL?.absoluteString == "https://example.com")
    #expect(configuration.supportURL?.scheme == "mailto")
    #expect(configuration.privacyPolicyURL?.path == "/privacy")
    #expect(configuration.termsOfUseURL?.path == "/terms")
    #expect(configuration.license == "MIT")
    #expect(configuration.showsChangelog)
    #expect(configuration.showsAppStoreReview)
    #expect(configuration.changelogConfiguration == .init(automaticallyScrolls: true, interval: 5))
    #expect(!UAPPAboutConfiguration().changelogConfiguration.automaticallyScrolls)
}

@Test("Sobre repassa a configuração do carrossel ao changelog e exige um client")
@MainActor
func aboutScreenForwardsChangelogConfiguration() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in response(#"{"entries":[]}"#) }
    for configuration in [UAPPChangelogConfiguration(), .init(automaticallyScrolls: true, interval: 3, pageSize: 7)] {
        let about = UAPPAboutScreen(
            configuration: .init(showsChangelog: true, changelogConfiguration: configuration), client: client
        )
        let changelog = try #require(about.changelogScreen)
        #expect(changelog.mode == .changelog)
        #expect(changelog.changelogConfiguration == configuration)
        await render(NavigationStack { changelog })
        let request = try #require(recorder.requests.last)
        #expect(queryValue("limit", in: request) == String(configuration.pageSize))
    }
    #expect(UAPPAboutScreen(configuration: .init(showsChangelog: true)).changelogScreen == nil)
}

@Test("UAPPAppMetadata descobre um nome do bundle hospedeiro")
func appMetadataDiscoversBundleName() {
    let metadata = UAPPAppMetadata()

    #expect(!metadata.name.isEmpty)
}

@Test("UAPPAboutScreen constrói o Sobre do aplicativo")
@MainActor
func aboutScreenBuildsInitialView() async {
    await render(UAPPAboutScreen(configuration: UAPPAboutConfiguration(
        shortDescription: "Um app para qualquer pessoa",
        descriptionLanguageIdentifier: "pt-BR",
        websiteURL: URL(string: "https://example.com"),
        supportURL: URL(string: "mailto:help@example.com"),
        privacyPolicyURL: URL(string: "https://example.com/privacy"),
        termsOfUseURL: URL(string: "https://example.com/terms"),
        license: "MIT"
    )))
}

private let aboutWithAppsJSON = """
{"project":{"slug":"meu-app","displayName":"Meu App","apple_app_id":"123456789"},\
"about":{"developer_name":"Equipe","about_apps":[{"name":"Meu App","slug":"meu-app",\
"iconURL":"file:///nonexistent/icon.png","apple_app_id":"123456789"}]}}
"""

@Test("Sobre com cliente carrega identidade, ícone do app e avaliação")
@MainActor
func aboutScreenLoadsRemoteContent() async {
    let loaded = makeClient { _ in response(aboutWithAppsJSON) }
    await render(UAPPAboutScreen(
        configuration: .init(showsChangelog: true, showsAppStoreReview: true), client: loaded
    ), settling: true)
    let failing = makeClient { _ in response(503, "{}") }
    await render(UAPPAboutScreen(configuration: .init(), client: failing), settling: true)
    let withoutIcon = makeClient { _ in response(#"{"project":{"slug":"outro"},"about":{"about_apps":[]}}"#) }
    await render(UAPPAboutScreen(configuration: .init(), client: withoutIcon), settling: true)
}

@MainActor
private final class AboutOpener {
    var accepts = true
    var opened: [URL] = []
    func open(_ url: URL) async -> Bool {
        opened.append(url)
        return accepts
    }
}

@Test("Avaliação usa destino em cache, consulta o projeto e informa falhas")
@MainActor
func aboutScreenOpensAppStoreReview() async throws {
    let opener = AboutOpener()
    let cached = try #require(URL(string: "itms-apps://itunes.apple.com/app/id1?action=write-review"))
    let cachedResult = await UAPPAboutScreen.openAppStoreReview(cachedURL: cached, client: nil, opener: opener.open)
    #expect(cachedResult.url == cached)
    #expect(cachedResult.error == nil)

    let noClient = await UAPPAboutScreen.openAppStoreReview(cachedURL: nil, client: nil, opener: opener.open)
    #expect(noClient.url == nil && noClient.error == nil)

    let loaded = await UAPPAboutScreen.openAppStoreReview(
        cachedURL: nil, client: makeClient { _ in response(aboutWithAppsJSON) }, opener: opener.open
    )
    #expect(loaded.url?.absoluteString.contains("id123456789") == true)
    #expect(loaded.error == nil)

    let unavailable = await UAPPAboutScreen.openAppStoreReview(
        cachedURL: nil, client: makeClient { _ in response(#"{"about":{"about_apps":[]}}"#) }, opener: opener.open
    )
    #expect(unavailable.url == nil)
    #expect(unavailable.error == UAPPKitError.appStoreURLUnavailable.localizedDescription)

    let failed = await UAPPAboutScreen.openAppStoreReview(
        cachedURL: nil, client: makeClient { _ in response(500, "{}") }, opener: opener.open
    )
    #expect(failed.url == nil)
    #expect(failed.error != nil)

    opener.accepts = false
    let refused = await UAPPAboutScreen.openAppStoreReview(cachedURL: cached, client: nil, opener: opener.open)
    #expect(refused.url == cached)
    #expect(refused.error == UAPPKitError.appStoreURLCouldNotOpen.localizedDescription)
}
