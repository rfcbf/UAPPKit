import Foundation

/// Conteúdo institucional opcional exibido na tela Sobre do aplicativo.
///
/// O nome, o ícone e a versão são descobertos automaticamente pelo bundle do
/// aplicativo hospedeiro. Estes campos representam somente o conteúdo que
/// varia de aplicativo para aplicativo. Quando a descrição é informada, o
/// idioma original pode ser passado em `descriptionLanguageIdentifier` para
/// permitir a tradução automática dentro da sheet.
public struct UAPPAboutConfiguration: Sendable, Equatable {
    public let shortDescription: String?
    public let descriptionLanguageIdentifier: String?
    public let websiteURL: URL?
    /// Link de suporte. Um e-mail de suporte configurado no UAPP para o projeto tem precedência.
    public let supportURL: URL?
    public let privacyPolicyURL: URL?
    public let termsOfUseURL: URL?
    public let license: String?
    public let showsChangelog: Bool
    public let showsAppStoreReview: Bool
    /// Mostra a ação que abre a lista de avaliações do aplicativo dentro da tela Sobre.
    public let showsReviews: Bool
    /// Tamanho das páginas da lista de avaliações aberta pela tela Sobre.
    public let reviewsPageSize: Int
    /// Opções do carrossel ao abrir o changelog pela tela Sobre.
    public let changelogConfiguration: UAPPChangelogConfiguration

    public init(
        shortDescription: String? = nil,
        descriptionLanguageIdentifier: String? = nil,
        websiteURL: URL? = nil,
        supportURL: URL? = nil,
        privacyPolicyURL: URL? = nil,
        termsOfUseURL: URL? = nil,
        license: String? = nil,
        showsChangelog: Bool = false,
        showsAppStoreReview: Bool = false,
        changelogConfiguration: UAPPChangelogConfiguration = .init(),
        showsReviews: Bool = false,
        reviewsPageSize: Int = 10
    ) {
        self.shortDescription = shortDescription
        self.descriptionLanguageIdentifier = descriptionLanguageIdentifier
        self.websiteURL = websiteURL
        self.supportURL = supportURL
        self.privacyPolicyURL = privacyPolicyURL
        self.termsOfUseURL = termsOfUseURL
        self.license = license
        self.showsChangelog = showsChangelog
        self.showsAppStoreReview = showsAppStoreReview
        self.changelogConfiguration = changelogConfiguration
        self.showsReviews = showsReviews
        self.reviewsPageSize = reviewsPageSize
    }
}

/// Metadados descobertos automaticamente no bundle do aplicativo hospedeiro.
public struct UAPPAppMetadata: Sendable, Equatable {
    public let name: String
    public let version: String?
    public let build: String?

    public init(bundle: Bundle = .main) {
        name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "App"
        version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    public var versionText: String? {
        guard let version, !version.isEmpty else { return nil }
        guard let build, !build.isEmpty, build != version else { return version }
        return String(format: "%@ (%@)", version, build)
    }
}
