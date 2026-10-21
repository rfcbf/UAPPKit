import SwiftUI
import UAPPKit

/// O modelo de conta compartilhado com o app do iPhone usa `DemoSettings`.
typealias DemoSettings = DemoMacSettings

/// Configuração salva do Demo para Mac: a mesma chave do Demo do iPhone e do iPad. O kit acessa
/// sempre o servidor de produção do UAPP.
enum DemoMacSettings {
    static let projectSlug = "UAPPKitDemo.projectSlug"
    static let defaultProjectSlug = "app-demo"
    static let callbackURL = URL(string: "uappkit://authentication")!

    /// Sobre com todas as opções ligadas e conteúdo fictício, para ver a tela completa.
    static let aboutConfiguration = UAPPAboutConfiguration(
        shortDescription: """
        Aplicativo de exemplo do UAPPKit. Reúne feedback, roadmap, novidades e avaliações \
        em telas nativas, no idioma e nas cores do aplicativo.
        """,
        descriptionLanguageIdentifier: "pt-BR",
        websiteURL: URL(string: "https://example.com"),
        supportURL: URL(string: "mailto:suporte@example.com"),
        privacyPolicyURL: URL(string: "https://example.com/privacidade"),
        termsOfUseURL: URL(string: "https://example.com/termos"),
        license: "MIT",
        showsChangelog: true,
        showsAppStoreReview: true,
        changelogConfiguration: .init(automaticallyScrolls: true, interval: 15, pageSize: 10),
        showsReviews: true,
        reviewsPageSize: 20
    )

    static var savedSlug: String {
        UserDefaults.standard.string(forKey: projectSlug) ?? defaultProjectSlug
    }
}

@main
struct UAPPKitDemoMacApp: App {
    init() {
        DemoMockData.activateIfNeeded()
        // O kit começa no idioma do sistema; o globo das telas troca só a apresentação.
        let locale = Locale(identifier: Locale.preferredLanguages.first ?? "pt-BR")
        UAPPKit.setup(
            projectId: DemoMockData.isEnabled ? DemoMockData.projectSlug : DemoMacSettings.savedSlug,
            locale: locale
        )
    }

    var body: some Scene {
        WindowGroup("UAPPKit Demo") {
            DemoMacContentView()
        }
        .defaultSize(width: 860, height: 600)
        // Feedback, Roadmap, Novidades e avaliação no menu Ajuda; "Sobre" abre a tela do kit.
        .commands {
            UAPPKitCommands(
                items: [.feedback, .roadmap, .changelog, .reviews, .rateOnAppStore, .developerAbout],
                aboutConfiguration: DemoMacSettings.aboutConfiguration
            )
        }
    }
}
