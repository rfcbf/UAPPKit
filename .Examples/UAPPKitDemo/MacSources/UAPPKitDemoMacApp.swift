import SwiftUI
import UAPPKit

/// O modelo de conta compartilhado com o app do iPhone usa `DemoSettings`.
typealias DemoSettings = DemoMacSettings

/// Configuração salva do Demo para Mac: as mesmas chaves do Demo do iPhone e do iPad.
enum DemoMacSettings {
    static let projectSlug = "calcjuros-dev"
    static let supabaseServer = "UAPPKitDemo.supabaseServer"
    static let defaultProjectSlug = "calcjuros-dev"
    static let defaultSupabaseServer = "https://zmmdvtykqbpwkwddjeyb.supabase.co"
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

    static var savedServer: String {
        let saved = UserDefaults.standard.string(forKey: supabaseServer)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return saved.flatMap { $0.isEmpty ? nil : $0 } ?? defaultSupabaseServer
    }
}

@main
struct UAPPKitDemoMacApp: App {
    init() {
        DemoMockData.activateIfNeeded()
        // O kit começa no idioma do sistema; o globo das telas troca só a apresentação.
        let locale = Locale(identifier: Locale.preferredLanguages.first ?? "pt-BR")
        if DemoMockData.isEnabled {
            UAPPKit.setup(projectId: DemoMockData.projectSlug, host: DemoMockData.host, locale: locale)
        } else {
            UAPPKit.setup(
                projectId: DemoMacSettings.savedSlug,
                host: URL(string: DemoMacSettings.savedServer) ?? UAPPConfiguration.defaultHost,
                locale: locale
            )
        }
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
