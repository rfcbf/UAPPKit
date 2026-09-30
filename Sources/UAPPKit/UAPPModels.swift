import Foundation

public enum UAPPFeedbackCategory: String, Sendable, Equatable, Codable, CaseIterable {
    case bug
    case feature
    case improvement
    case question
}

public enum UAPPReactionKind: String, Sendable, Equatable, Codable {
    case vote
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
        createdAt: Date? = nil
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
}

public struct UAPPFeedbackPage: Sendable, Equatable {
    public let items: [UAPPFeedbackItem]
    public let nextCursor: String?
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

    enum CodingKeys: String, CodingKey {
        case developerName = "developer_name"
        case imageURL = "developer_image_url"
        case bio = "developer_bio"
        case bioDefaultLanguage = "developer_bio_default_language"
        case bioTranslations = "developer_bio_translations"
        case apps = "about_apps"
        case socialLinks = "social_links"
    }

    init(
        developerName: String?,
        imageURL: URL?,
        bio: String?,
        bioDefaultLanguage: String = "pt-BR",
        bioTranslations: [String: String] = [:],
        apps: [UAPPAboutApp],
        socialLinks: [String: URL]
    ) {
        self.developerName = developerName
        self.imageURL = imageURL
        self.bio = bio
        self.bioDefaultLanguage = bioDefaultLanguage
        self.bioTranslations = bioTranslations
        self.apps = apps
        self.socialLinks = socialLinks
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
    }
}

struct UAPPReviewsResponse: Decodable {
    let project: UAPPProject?
    let reviews: [UAPPReview]
    let nextCursor: String?
}

/// Página de avaliações; `nextCursor == nil` indica o fim da lista.
public struct UAPPReviewsPage: Sendable, Equatable {
    public let reviews: [UAPPReview]
    public let nextCursor: String?
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

    public init(
        slug: String,
        displayName: String?,
        iconURL: URL?,
        publicBaseURL: URL?,
        appStoreURL: URL? = nil,
        appleAppId: String? = nil,
        primaryColor: String?,
        locale: String?
    ) {
        self.slug = slug
        self.displayName = displayName
        self.iconURL = iconURL
        self.publicBaseURL = publicBaseURL
        self.appStoreURL = appStoreURL
        self.appleAppId = appleAppId
        self.primaryColor = primaryColor
        self.locale = locale
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
    }
}

// MARK: - Envelopes de resposta das Edge Functions

struct UAPPFeedbackResponse: Decodable {
    let project: UAPPProject?
    let items: [UAPPFeedbackItem]
    let nextCursor: String?
}

struct UAPPRoadmapResponse: Decodable {
    struct RawStatus: Decodable {
        let id: String
        let key: String
        let name: String
        let position: Int
        let isRoadmapVisible: Bool?
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

        enum CodingKeys: String, CodingKey {
            case id, title, body
            case statusId = "status_id"
            case voteCount = "vote_count"
            case likeCount = "like_count"
            case commentCount = "public_comment_count"
            case category, priority
            case viewerVoted = "viewer_voted"
            case viewerLiked = "viewer_liked"
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
