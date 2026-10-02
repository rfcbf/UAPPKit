import Foundation

/// Nome, foto, estatísticas e feedbacks públicos do autor neste aplicativo.
/// Não contém e-mail, identificador de conta ou atividade privada.
public struct UAPPPublicAuthorProfile: Decodable, Sendable, Equatable {
    public let author: Author
    public let totals: UAPPUserActivityPage.Totals?
    public let items: [UAPPUserActivityPage.Item]
    public let nextCursor: String?
    public let statuses: [UAPPRoadmapColumn.Status]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        author = try container.decode(Author.self, forKey: .author)
        totals = try container.decodeIfPresent(UAPPUserActivityPage.Totals.self, forKey: .totals)
        items = try container.decodeIfPresent([UAPPUserActivityPage.Item].self, forKey: .items) ?? []
        nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
        statuses = try container.decodeIfPresent([UAPPRoadmapColumn.Status].self, forKey: .statuses) ?? []
    }

    public struct Author: Decodable, Sendable, Equatable {
        public let name: String
        public let avatarURL: URL?
        enum CodingKeys: String, CodingKey {
            case name
            case avatarURL = "avatar_url"
        }
    }

    enum CodingKeys: String, CodingKey { case author, totals, items, nextCursor, statuses }
}
