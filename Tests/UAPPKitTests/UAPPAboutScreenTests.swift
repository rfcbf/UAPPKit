import SwiftUI
import Testing
@testable import UAPPKit

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
