import Foundation

/// Item independente de uma versão, com imagem pública opcional.
public struct UAPPChangelogSection: Sendable, Equatable, Codable {
    public let category: UAPPChangelogCategory
    public let bodyMarkdown: String
    public let position: Int
    public let imageURL: URL?
    private let hasPosition: Bool

    public init(category: UAPPChangelogCategory, bodyMarkdown: String, position: Int, imageURL: URL? = nil) {
        self.category = category
        self.bodyMarkdown = bodyMarkdown
        self.position = position
        hasPosition = true
        self.imageURL = Self.validImageURL(imageURL?.absoluteString)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        category = try values.decode(UAPPChangelogCategory.self, forKey: .category)
        bodyMarkdown = try values.decode(String.self, forKey: .bodyMarkdown)
        let decodedPosition = try values.decodeIfPresent(Int.self, forKey: .position)
        position = decodedPosition ?? 0
        hasPosition = decodedPosition != nil
        imageURL = try Self.validImageURL(values.decodeIfPresent(String.self, forKey: .imageURL))
    }

    private static func validImageURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value), url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(category, forKey: .category)
        try values.encode(bodyMarkdown, forKey: .bodyMarkdown)
        if hasPosition {
            try values.encode(position, forKey: .position)
        }
        try values.encodeIfPresent(imageURL, forKey: .imageURL)
    }

    func sortPosition(fallback: Int) -> Int {
        hasPosition ? position : fallback
    }

    enum CodingKeys: String, CodingKey {
        case category, position
        case bodyMarkdown = "body_md"
        case imageURL = "image_url"
    }
}
