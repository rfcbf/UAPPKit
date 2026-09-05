import Foundation

/// Item de feedback público.
public struct UAPPFeedbackItem: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let title: String
    public let body: String?
    public let voteCount: Int
    public let commentCount: Int
    public let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case voteCount = "vote_count"
        case commentCount = "comment_count"
        case createdAt = "created_at"
    }
}

/// Coluna do roadmap público (status + itens).
public struct UAPPRoadmapColumn: Sendable, Equatable, Codable {
    public struct Status: Sendable, Equatable, Codable {
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
}

struct UAPPRoadmapResponse: Decodable {
    struct RawStatus: Decodable {
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
        let commentCount: Int

        enum CodingKeys: String, CodingKey {
            case id, title, body
            case statusId = "status_id"
            case voteCount = "vote_count"
            case commentCount = "comment_count"
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
