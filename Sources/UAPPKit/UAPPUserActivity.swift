import Foundation

/// Participação da conta em todos os aplicativos associados no mesmo serviço.
public struct UAPPUserActivityPage: Decodable, Sendable, Equatable {
    public let totals: Totals
    public let items: [Item]
    public let nextCursor: String?

    public struct Totals: Decodable, Sendable, Equatable {
        public let likes: Int
        public let votes: Int
        public let comments: Int
        public let feedbacks: Int
        enum CodingKeys: String, CodingKey { case likes, votes, comments, feedbacks }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            likes = try values.decodeIfPresent(Int.self, forKey: .likes) ?? 0
            votes = try values.decodeIfPresent(Int.self, forKey: .votes) ?? 0
            comments = try values.decode(Int.self, forKey: .comments)
            feedbacks = try values.decode(Int.self, forKey: .feedbacks)
        }
    }

    public struct Item: Decodable, Identifiable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let appName: String?
        public let appSlug: String?
        public let state: String
        public let statusKey: String?
        public let statusName: String?
        public let statusId: String?
        public let statusColor: String?
        public let body: String?
        public let likeCount: Int?
        public let voteCount: Int?
        public let commentCount: Int?
        public let createdAt: Date
        enum CodingKeys: String, CodingKey {
            case id, title, state
            case appName = "app_name", appSlug = "app_slug"
            case statusKey = "status_key", statusName = "status_name", createdAt = "created_at"
            case statusId = "status_id", statusColor = "status_color", body
            case likeCount = "like_count", commentCount = "public_comment_count"
            case voteCount = "vote_count"
        }
    }

    enum CodingKeys: String, CodingKey { case totals, items, nextCursor }
}
