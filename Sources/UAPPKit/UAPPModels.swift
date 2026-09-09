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
    public var id: String { slug }
    public let title: String
    public let slug: String
    public let bodyMarkdown: String
    public let publishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case title, slug
        case bodyMarkdown = "body_md"
        case publishedAt = "published_at"
    }
}

/// Metadados públicos do projeto retornados junto das listagens.
public struct UAPPProject: Sendable, Equatable, Codable {
    public let slug: String
    public let displayName: String?
    public let primaryColor: String?
    public let locale: String?

    enum CodingKeys: String, CodingKey {
        case slug
        case displayName
        case primaryColor
        case locale
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
}

struct UAPPSubmitResponse: Decodable {
    let ok: Bool
    let id: String?
}

struct UAPPCommentsResponse: Decodable {
    let comments: [UAPPComment]
    let nextCursor: String?
}
