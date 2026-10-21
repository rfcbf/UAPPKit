import Foundation

public enum UAPPFeedbackCategory: String, Sendable, Equatable, Codable, CaseIterable {
    case bug
    case feature
    case improvement
    case question
}

public enum UAPPReactionKind: String, Sendable, Equatable, Codable {
    case vote
    @available(*, deprecated, message: "Use vote. A participação é apresentada como votação.")
    case like
}

public enum UAPPChangelogCategory: String, Sendable, Equatable, Codable, CaseIterable {
    case new
    case improved
    case fixed
    case security
}

public enum UAPPChangelogPlatform: String, Sendable, Equatable, Codable, CaseIterable {
    case all
    case ios
    case ipados
    case macos
    case watchos
    case tvos
    case visionos
}

/// Item de feedback público.
public struct UAPPFeedbackItem: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let title: String
    public let body: String?
    public let voteCount: Int
    public let likeCount: Int
    public let commentCount: Int
    public let category: UAPPFeedbackCategory?
    public let priority: Int
    public let viewerVoted: Bool
    public let viewerLiked: Bool
    public let createdAt: Date?
    public let authorName: String?
    public let authorAvatarURL: URL?
    public let statusId: String?
    public let voters: [UAPPFeedbackVoter]?
    public let imageURL: URL?
    public let imageURLs: [URL]?
    /// Etiquetas aplicadas pela equipe; servidores antigos não enviam o campo e a lista fica vazia.
    public let tags: [UAPPFeedbackTag]
    public var attachmentURLs: [URL] {
        imageURLs ?? imageURL.map { [$0] } ?? []
    }

    public init(
        id: String,
        title: String,
        body: String?,
        voteCount: Int,
        likeCount: Int,
        commentCount: Int,
        category: UAPPFeedbackCategory? = nil,
        priority: Int = 0,
        viewerVoted: Bool = false,
        viewerLiked: Bool = false,
        createdAt: Date? = nil,
        authorName: String? = nil,
        authorAvatarURL: URL? = nil,
        statusId: String? = nil,
        voters: [UAPPFeedbackVoter]? = nil,
        imageURL: URL? = nil,
        imageURLs: [URL]? = nil,
        tags: [UAPPFeedbackTag] = []
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.voteCount = voteCount
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.category = category
        self.priority = priority
        self.viewerVoted = viewerVoted
        self.viewerLiked = viewerLiked
        self.createdAt = createdAt
        self.authorName = authorName
        self.authorAvatarURL = authorAvatarURL
        self.statusId = statusId
        self.voters = voters
        self.imageURL = imageURL
        self.imageURLs = imageURLs
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case voteCount = "vote_count"
        case likeCount = "like_count"
        case commentCount = "public_comment_count"
        case category, priority
        case viewerVoted = "viewer_voted"
        case viewerLiked = "viewer_liked"
        case createdAt = "created_at"
        case authorName = "author_name"
        case authorAvatarURL = "author_avatar_url"
        case statusId = "status_id"
        case voters
        case imageURL = "image_url"
        case imageURLs = "image_urls"
        case tags
    }
}

public extension UAPPFeedbackItem {
    /// Decodifica o item; `tags` ausente ou nulo, enviado por servidores antigos, vira lista vazia.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(String.self, forKey: .id),
            title: container.decode(String.self, forKey: .title),
            body: container.decodeIfPresent(String.self, forKey: .body),
            voteCount: container.decode(Int.self, forKey: .voteCount),
            likeCount: container.decode(Int.self, forKey: .likeCount),
            commentCount: container.decode(Int.self, forKey: .commentCount),
            category: container.decodeIfPresent(UAPPFeedbackCategory.self, forKey: .category),
            priority: container.decode(Int.self, forKey: .priority),
            viewerVoted: container.decode(Bool.self, forKey: .viewerVoted),
            viewerLiked: container.decode(Bool.self, forKey: .viewerLiked),
            createdAt: container.decodeIfPresent(Date.self, forKey: .createdAt),
            authorName: container.decodeIfPresent(String.self, forKey: .authorName),
            authorAvatarURL: container.decodeIfPresent(URL.self, forKey: .authorAvatarURL),
            statusId: container.decodeIfPresent(String.self, forKey: .statusId),
            voters: container.decodeIfPresent([UAPPFeedbackVoter].self, forKey: .voters),
            imageURL: container.decodeIfPresent(URL.self, forKey: .imageURL),
            imageURLs: container.decodeIfPresent([URL].self, forKey: .imageURLs),
            tags: container.decodeIfPresent([UAPPFeedbackTag].self, forKey: .tags) ?? []
        )
    }
}

extension UAPPFeedbackItem {
    func settingVote(enabled: Bool) -> UAPPFeedbackItem {
        let change = enabled == viewerVoted ? 0 : (enabled ? 1 : -1)
        return UAPPFeedbackItem(
            id: id, title: title, body: body, voteCount: max(0, voteCount + change),
            likeCount: likeCount, commentCount: commentCount,
            category: category, priority: priority, viewerVoted: enabled,
            viewerLiked: viewerLiked, createdAt: createdAt, authorName: authorName,
            authorAvatarURL: authorAvatarURL, statusId: statusId,
            voters: voters, imageURL: imageURL, imageURLs: imageURLs, tags: tags
        )
    }

    func settingLike(enabled: Bool) -> UAPPFeedbackItem {
        let change = enabled == viewerLiked ? 0 : (enabled ? 1 : -1)
        return UAPPFeedbackItem(
            id: id, title: title, body: body, voteCount: voteCount,
            likeCount: max(0, likeCount + change), commentCount: commentCount,
            category: category, priority: priority, viewerVoted: viewerVoted,
            viewerLiked: enabled, createdAt: createdAt, authorName: authorName,
            authorAvatarURL: authorAvatarURL, statusId: statusId,
            voters: voters, imageURL: imageURL, imageURLs: imageURLs, tags: tags
        )
    }
}

/// Etiqueta aplicada pela equipe a uma requisição, como aparece na gestão.
public struct UAPPFeedbackTag: Identifiable, Sendable, Equatable, Hashable, Codable {
    public let id: String
    public let name: String
    /// Cor no formato hexadecimal (`#RRGGBB`); `nil` usa a cor neutra do tema.
    public let color: String?

    public init(id: String, name: String, color: String? = nil) {
        self.id = id
        self.name = name
        self.color = color
    }

    enum CodingKeys: String, CodingKey {
        case id, name, color
    }
}

/// Perfis públicos das últimas pessoas que reagiram ao feedback.
public struct UAPPFeedbackVoter: Sendable, Equatable, Codable {
    public let displayName: String
    public let avatarURL: URL?

    public init(displayName: String, avatarURL: URL? = nil) {
        self.displayName = displayName
        self.avatarURL = avatarURL
    }

    enum CodingKeys: String, CodingKey {
        case displayName
        case avatarURL = "avatarUrl"
    }
}

public struct UAPPComment: Identifiable, Sendable, Equatable, Codable {
    public enum AuthorKind: String, Sendable, Equatable, Codable {
        case team
        case community
    }

    public let id: String
    public let body: String
    public let parentCommentId: String?
    public let likeCount: Int
    public let createdAt: Date
    public let authorKind: AuthorKind
    public let viewerLiked: Bool
    /// Votos no comentário; os campos antigos permanecem no contrato de transporte.
    public var voteCount: Int {
        likeCount
    }

    public var viewerVoted: Bool {
        viewerLiked
    }

    public let authorName: String?
    public let authorAvatarURL: URL?
    public let imageURL: URL?
    public let imageURLs: [URL]?
    public let viewerOwned: Bool?
    public var attachmentURLs: [URL] {
        imageURLs ?? imageURL.map { [$0] } ?? []
    }

    public init(
        id: String, body: String, parentCommentId: String? = nil,
        likeCount: Int, createdAt: Date, authorKind: AuthorKind,
        viewerLiked: Bool, authorName: String? = nil,
        authorAvatarURL: URL? = nil, imageURL: URL? = nil,
        moderationState: String? = nil,
        imageURLs: [URL]? = nil,
        viewerOwned: Bool? = nil
    ) {
        self.id = id
        self.body = body
        self.parentCommentId = parentCommentId
        self.likeCount = likeCount
        self.createdAt = createdAt
        self.authorKind = authorKind
        self.viewerLiked = viewerLiked
        self.authorName = authorName
        self.authorAvatarURL = authorAvatarURL
        self.imageURL = imageURL
        self.imageURLs = imageURLs
        self.moderationState = moderationState
        self.viewerOwned = viewerOwned
    }

    public let moderationState: String?

    enum CodingKeys: String, CodingKey {
        case id, body, parentCommentId, likeCount, createdAt, authorKind, viewerLiked, authorName, moderationState, viewerOwned
        case authorAvatarURL = "authorAvatarUrl"
        case imageURL = "imageUrl"
        case imageURLs = "imageUrls"
    }
}

extension UAPPComment {
    func avatarURL(viewer: UAPPIdentity?) -> URL? {
        if viewerOwned == true, let viewer {
            return viewer.avatarURL
        }
        return authorAvatarURL
    }
}

public struct UAPPFeedbackPage: Sendable, Equatable {
    public let items: [UAPPFeedbackItem]
    public let nextCursor: String?
    public let statuses: [UAPPRoadmapColumn.Status]

    public init(items: [UAPPFeedbackItem], nextCursor: String?, statuses: [UAPPRoadmapColumn.Status] = []) {
        self.items = items
        self.nextCursor = nextCursor
        self.statuses = statuses
    }
}

public struct UAPPCommentsPage: Sendable, Equatable {
    public let comments: [UAPPComment]
    public let nextCursor: String?
}

/// Avaliação publicada pelo responsável do aplicativo.
public struct UAPPReview: Identifiable, Sendable, Equatable, Decodable {
    public let id: String
    public let rating: Int
    public let title: String?
    public let body: String?
    public let reviewerName: String?
    public let reviewedAt: Date?
    public let responseBody: String?

    init(id: String, rating: Int, title: String?, body: String?, reviewerName: String?, reviewedAt: Date?, responseBody: String? = nil) {
        self.id = id
        self.rating = rating
        self.title = title
        self.body = body
        self.reviewerName = reviewerName
        self.reviewedAt = reviewedAt
        self.responseBody = responseBody
    }

    enum CodingKeys: String, CodingKey {
        case id, rating, title, body
        case reviewerName = "reviewer_nickname"
        case reviewedAt = "reviewed_at"
        case responseBody = "response_body"
    }
}

public struct UAPPAbout: Sendable, Equatable, Decodable {
    public let developerName: String?
    public let imageURL: URL?
    public let bio: String?
    public let bioDefaultLanguage: String
    public let bioTranslations: [String: String]
    public let apps: [UAPPAboutApp]
    public let socialLinks: [String: URL]
    /// E-mail de suporte configurado para o aplicativo no UAPP.
    public let supportEmail: String?
    /// Descrição do aplicativo configurada no UAPP, em Markdown e no idioma `bioDefaultLanguage`.
    public let appDescription: String?

    enum CodingKeys: String, CodingKey {
        case developerName = "developer_name"
        case imageURL = "developer_image_url"
        case bio = "developer_bio"
        case bioDefaultLanguage = "developer_bio_default_language"
        case bioTranslations = "developer_bio_translations"
        case apps = "about_apps"
        case socialLinks = "social_links"
        case supportEmail = "support_email"
        case appDescription = "app_description"
    }

    init(
        developerName: String?,
        imageURL: URL?,
        bio: String?,
        bioDefaultLanguage: String = "pt-BR",
        bioTranslations: [String: String] = [:],
        apps: [UAPPAboutApp],
        socialLinks: [String: URL],
        supportEmail: String? = nil,
        appDescription: String? = nil
    ) {
        self.developerName = developerName
        self.imageURL = imageURL
        self.bio = bio
        self.bioDefaultLanguage = bioDefaultLanguage
        self.bioTranslations = bioTranslations
        self.apps = apps
        self.socialLinks = socialLinks
        self.supportEmail = supportEmail
        self.appDescription = appDescription
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        developerName = try values.decodeIfPresent(String.self, forKey: .developerName)
        imageURL = try values.decodeIfPresent(URL.self, forKey: .imageURL)
        bio = try values.decodeIfPresent(String.self, forKey: .bio)
        bioDefaultLanguage = try values.decodeIfPresent(String.self, forKey: .bioDefaultLanguage) ?? "pt-BR"
        bioTranslations = try values.decodeIfPresent([String: String].self, forKey: .bioTranslations) ?? [:]
        apps = try values.decodeIfPresent([UAPPAboutApp].self, forKey: .apps) ?? []
        socialLinks = try values.decodeIfPresent([String: URL].self, forKey: .socialLinks) ?? [:]
        supportEmail = try values.decodeIfPresent(String.self, forKey: .supportEmail)
        appDescription = try values.decodeIfPresent(String.self, forKey: .appDescription)
    }
}

struct UAPPReviewsResponse: Decodable {
    let project: UAPPProject?
    let reviews: [UAPPReview]
    let nextCursor: String?
    let summary: UAPPReviewSummary?
}

/// Página de avaliações; `nextCursor == nil` indica o fim da lista.
public struct UAPPReviewsPage: Sendable, Equatable {
    public let reviews: [UAPPReview]
    public let nextCursor: String?
    /// Resumo de todas as avaliações publicadas, quando o servidor o informa.
    public let summary: UAPPReviewSummary?

    init(reviews: [UAPPReview], nextCursor: String?, summary: UAPPReviewSummary? = nil) {
        self.reviews = reviews
        self.nextCursor = nextCursor
        self.summary = summary
    }
}

/// Média, total e distribuição por nota das avaliações de um aplicativo.
public struct UAPPReviewSummary: Sendable, Equatable, Decodable {
    public let count: Int
    public let average: Double
    /// Quantidade de avaliações por nota, com as chaves de `"1"` a `"5"`.
    public let distribution: [String: Int]

    init(count: Int, average: Double, distribution: [String: Int]) {
        self.count = count
        self.average = average
        self.distribution = distribution
    }

    /// Resumo calculado a partir de uma lista completa de avaliações.
    init(reviews: [UAPPReview]) {
        count = reviews.count
        average = reviews.isEmpty ? 0 : Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
        distribution = Dictionary(grouping: reviews, by: { String(min(max($0.rating, 1), 5)) }).mapValues(\.count)
    }

    /// Fração de 0 a 1 das avaliações com a nota informada.
    public func share(of rating: Int) -> Double {
        count > 0 ? Double(distribution[String(rating)] ?? 0) / Double(count) : 0
    }
}

struct UAPPAboutResponse: Decodable {
    let project: UAPPProject?
    let about: UAPPAbout
}

public struct UAPPChangelogPage: Sendable, Equatable {
    public let entries: [UAPPChangelogEntry]
    public let nextCursor: String?
    public let totalCount: Int?
}

/// Filtros aceitos pelo endpoint público de Changelog.
public struct UAPPChangelogFilters: Sendable, Equatable {
    public var category: UAPPChangelogCategory?
    public var platform: UAPPChangelogPlatform?
    public var version: String?
    public var build: String?
    /// Data inclusiva no formato `YYYY-MM-DD`.
    public var from: String?
    /// Data inclusiva no formato `YYYY-MM-DD`.
    public var to: String?

    public init(
        category: UAPPChangelogCategory? = nil,
        platform: UAPPChangelogPlatform? = nil,
        version: String? = nil,
        build: String? = nil,
        from: String? = nil,
        to: String? = nil
    ) {
        self.category = category
        self.platform = platform
        self.version = version
        self.build = build
        self.from = from
        self.to = to
    }

    var queryItems: [URLQueryItem] {
        [
            category.map { URLQueryItem(name: "category", value: $0.rawValue) },
            platform.map { URLQueryItem(name: "platform", value: $0.rawValue) },
            version.map { URLQueryItem(name: "version", value: $0) },
            build.map { URLQueryItem(name: "build", value: $0) },
            from.map { URLQueryItem(name: "from", value: $0) },
            to.map { URLQueryItem(name: "to", value: $0) }
        ].compactMap(\.self)
    }
}

/// Coluna do roadmap público (status + itens).
public struct UAPPRoadmapColumn: Sendable, Equatable, Codable {
    public struct Status: Sendable, Equatable, Codable {
        public let id: String
        public let key: String
        public let name: String
        public let position: Int
        public let color: String?

        public init(id: String, key: String, name: String, position: Int, color: String? = nil) {
            self.id = id
            self.key = key
            self.name = name
            self.position = position
            self.color = color
        }

        enum CodingKeys: String, CodingKey {
            case id, key, name, position, color
        }
    }

    public let status: Status
    public let items: [UAPPFeedbackItem]
}

/// Entrada de changelog publicada.
public struct UAPPChangelogEntry: Identifiable, Sendable, Equatable, Codable {
    public var id: String {
        slug
    }

    public let title: String
    public let slug: String
    public let bodyMarkdown: String
    /// Descrição geral, separada dos itens. Ausente em respostas anteriores.
    public let descriptionMarkdown: String?
    public let version: String?
    public let build: String?
    public let platform: UAPPChangelogPlatform?
    public let sections: [UAPPChangelogSection]
    /// Data de lançamento no formato ISO `YYYY-MM-DD`, quando informada.
    public let releasedAt: String?
    public let publishedAt: Date?

    public init(
        title: String,
        slug: String,
        bodyMarkdown: String,
        version: String? = nil,
        build: String? = nil,
        platform: UAPPChangelogPlatform? = nil,
        sections: [UAPPChangelogSection] = [],
        releasedAt: String? = nil,
        publishedAt: Date? = nil,
        descriptionMarkdown: String? = nil
    ) {
        self.title = title
        self.slug = slug
        self.bodyMarkdown = bodyMarkdown
        self.descriptionMarkdown = descriptionMarkdown
        self.version = version
        self.build = build
        self.platform = platform
        self.sections = sections
        self.releasedAt = releasedAt
        self.publishedAt = publishedAt
    }

    enum CodingKeys: String, CodingKey {
        case title, slug
        case bodyMarkdown = "body_md"
        case descriptionMarkdown = "description_md"
        case version, build, platform, sections
        case releasedAt = "released_at"
        case publishedAt = "published_at"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decode(String.self, forKey: .title)
        slug = try values.decode(String.self, forKey: .slug)
        bodyMarkdown = try values.decode(String.self, forKey: .bodyMarkdown)
        descriptionMarkdown = try values.decodeIfPresent(String.self, forKey: .descriptionMarkdown)
        version = try values.decodeIfPresent(String.self, forKey: .version)
        build = try values.decodeIfPresent(String.self, forKey: .build)
        platform = try values.decodeIfPresent(UAPPChangelogPlatform.self, forKey: .platform)
        sections = try values.decodeIfPresent([UAPPChangelogSection].self, forKey: .sections) ?? []
        releasedAt = try values.decodeIfPresent(String.self, forKey: .releasedAt)
        publishedAt = try values.decodeIfPresent(Date.self, forKey: .publishedAt)
    }
}

/// Metadados públicos do projeto retornados junto das listagens.
public struct UAPPProject: Sendable, Equatable, Codable {
    public let slug: String
    public let displayName: String?
    public let iconURL: URL?
    public let publicBaseURL: URL?
    public let appStoreURL: URL?
    public let appleAppId: String?
    public let primaryColor: String?
    public let locale: String?
    /// Só no app de demonstração do UAPP: segundos até a requisição e o comentário de quem testa
    /// serem publicados sozinhos, sem moderação. Nulo nos apps comuns.
    public let autoPublishSeconds: Int?

    public init(
        slug: String,
        displayName: String?,
        iconURL: URL?,
        publicBaseURL: URL?,
        appStoreURL: URL? = nil,
        appleAppId: String? = nil,
        primaryColor: String?,
        locale: String?,
        autoPublishSeconds: Int? = nil
    ) {
        self.slug = slug
        self.displayName = displayName
        self.iconURL = iconURL
        self.publicBaseURL = publicBaseURL
        self.appStoreURL = appStoreURL
        self.appleAppId = appleAppId
        self.primaryColor = primaryColor
        self.locale = locale
        self.autoPublishSeconds = autoPublishSeconds
    }

    /// URL da página de avaliação pública do app configurado no UAPP.
    var appStoreReviewDestination: URL? {
        uappAppStoreReviewURL(
            destination: uappAppStoreDestination(
                url: appStoreURL,
                appleAppId: appleAppId
            )
        )
    }

    enum CodingKeys: String, CodingKey {
        case slug
        case displayName
        case iconURL = "iconUrl"
        case publicBaseURL
        case appStoreURL
        case appleAppId
        case primaryColor
        case locale
        case autoPublishSeconds
    }

    private enum AlternateCodingKeys: String, CodingKey {
        case iconURLSnakeCase = "icon_url"
        case appStoreURL = "appStoreUrl"
        case appStoreURLSnakeCase = "app_store_url"
        case appleAppId = "apple_app_id"
        case appStoreAppId
        case appStoreAppIdSnakeCase = "app_store_app_id"
        case appStoreId
        case appStoreIdSnakeCase = "app_store_id"
        case appId
        case appIdSnakeCase = "app_id"
        case appleId
        case appleIdSnakeCase = "apple_id"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let alternateValues = try decoder.container(keyedBy: AlternateCodingKeys.self)
        slug = try values.decode(String.self, forKey: .slug)
        displayName = try values.decodeIfPresent(String.self, forKey: .displayName)
        iconURL = try values.decodeIfPresent(URL.self, forKey: .iconURL)
            ?? alternateValues.decodeIfPresent(URL.self, forKey: .iconURLSnakeCase)
        publicBaseURL = try values.decodeIfPresent(URL.self, forKey: .publicBaseURL)
        appStoreURL = try values.decodeIfPresent(URL.self, forKey: .appStoreURL)
            ?? alternateValues.decodeIfPresent(URL.self, forKey: .appStoreURL)
            ?? alternateValues.decodeIfPresent(URL.self, forKey: .appStoreURLSnakeCase)
        appleAppId = try uappDecodeStringOrInt(from: values, forKey: .appleAppId)
            ?? uappDecodeStringOrInt(from: alternateValues, forKey: .appleAppId)
            ?? uappDecodeStringOrInt(from: alternateValues, forKey: .appStoreAppId)
            ?? uappDecodeStringOrInt(from: alternateValues, forKey: .appStoreAppIdSnakeCase)
            ?? uappDecodeStringOrInt(from: alternateValues, forKey: .appStoreId)
            ?? uappDecodeStringOrInt(from: alternateValues, forKey: .appStoreIdSnakeCase)
            ?? uappDecodeStringOrInt(from: alternateValues, forKey: .appId)
            ?? uappDecodeStringOrInt(from: alternateValues, forKey: .appIdSnakeCase)
            ?? uappDecodeStringOrInt(from: alternateValues, forKey: .appleId)
            ?? uappDecodeStringOrInt(from: alternateValues, forKey: .appleIdSnakeCase)
        primaryColor = try values.decodeIfPresent(String.self, forKey: .primaryColor)
        locale = try values.decodeIfPresent(String.self, forKey: .locale)
        autoPublishSeconds = try? values.decodeIfPresent(Int.self, forKey: .autoPublishSeconds)
    }
}

// MARK: - Envelopes de resposta das Edge Functions

struct UAPPFeedbackResponse: Decodable {
    let project: UAPPProject?
    let items: [UAPPFeedbackItem]
    let nextCursor: String?
    let statuses: [UAPPRoadmapResponse.RawStatus]?
}

struct UAPPRoadmapResponse: Decodable {
    struct RawStatus: Decodable {
        let id: String
        let key: String
        let name: String
        let position: Int
        let isRoadmapVisible: Bool?
        let color: String?

        enum CodingKeys: String, CodingKey {
            case id, key, name, position, isRoadmapVisible, color
        }
    }

    let project: UAPPProject?
    let statuses: [RawStatus]
    let items: [RawItem]

    struct RawItem: Decodable {
        let id: String
        let title: String
        let body: String?
        let statusId: String
        let voteCount: Int
        let likeCount: Int
        let commentCount: Int
        let category: UAPPFeedbackCategory?
        let priority: Int
        let viewerVoted: Bool
        let viewerLiked: Bool
        let createdAt: Date?
        let authorName: String?
        let authorAvatarURL: URL?
        let voters: [UAPPFeedbackVoter]?
        let imageURL: URL?
        let imageURLs: [URL]?
        let tags: [UAPPFeedbackTag]?

        enum CodingKeys: String, CodingKey {
            case id, title, body
            case statusId = "status_id"
            case voteCount = "vote_count"
            case likeCount = "like_count"
            case commentCount = "public_comment_count"
            case category, priority
            case viewerVoted = "viewer_voted"
            case viewerLiked = "viewer_liked"
            case createdAt = "created_at"
            case authorName = "author_name"
            case authorAvatarURL = "author_avatar_url"
            case voters
            case imageURL = "image_url"
            case imageURLs = "image_urls"
            case tags
        }
    }
}

struct UAPPChangelogResponse: Decodable {
    let project: UAPPProject?
    let entries: [UAPPChangelogEntry]
    let nextCursor: String?
    let totalCount: Int?
}

struct UAPPSubmitResponse: Decodable {
    let ok: Bool
    let id: String?
}

struct UAPPCommentsResponse: Decodable {
    let comments: [UAPPComment]
    let nextCursor: String?
}

struct UAPPErrorResponse: Decodable {
    let project: UAPPProject?
}
