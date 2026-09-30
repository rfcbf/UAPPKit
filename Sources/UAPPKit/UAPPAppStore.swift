import Foundation

func uappDecodeStringOrInt<Key: CodingKey>(
    from container: KeyedDecodingContainer<Key>,
    forKey key: Key
) throws -> String? {
    do {
        return try container.decodeIfPresent(String.self, forKey: key)
    } catch DecodingError.typeMismatch {
        return try container.decodeIfPresent(Int.self, forKey: key).map(String.init)
    }
}

func uappNormalizedAppleAppId(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let digits = trimmed.lowercased().hasPrefix("id") ? String(trimmed.dropFirst(2)) : trimmed
    guard digits.range(of: "^[0-9]{5,20}$", options: .regularExpression) != nil else {
        return nil
    }
    return digits
}

func uappAppStoreDestination(url: URL?, appleAppId: String?) -> URL? {
    if let appleAppId = uappNormalizedAppleAppId(appleAppId) {
        return URL(string: "itms-apps://itunes.apple.com/app/id\(appleAppId)")
    }

    guard let url,
          url.scheme?.lowercased() == "https",
          ["apps.apple.com", "itunes.apple.com"].contains(url.host?.lowercased() ?? "")
    else { return nil }

    return url
}

func uappAppStoreReviewURL(destination: URL?) -> URL? {
    guard let destination else { return nil }
    var components = URLComponents(url: destination, resolvingAgainstBaseURL: false)
    var queryItems = components?.queryItems ?? []
    queryItems.removeAll { $0.name == "action" }
    queryItems.append(URLQueryItem(name: "action", value: "write-review"))
    components?.queryItems = queryItems
    return components?.url ?? destination
}

public struct UAPPAboutApp: Identifiable, Sendable, Equatable, Decodable {
    public var id: String {
        appStoreURL.isEmpty ? appleAppId ?? name : appStoreURL
    }

    public let name: String
    public let subtitle: String?
    public let appStoreURL: String
    public let appleAppId: String?
    public let iconURL: URL?
    public let slug: String?
    public let projectId: String?

    public init(
        name: String,
        subtitle: String?,
        appStoreURL: String,
        appleAppId: String?,
        iconURL: URL?,
        slug: String? = nil,
        projectId: String? = nil
    ) {
        self.name = name
        self.subtitle = subtitle
        self.appStoreURL = appStoreURL
        self.appleAppId = appleAppId
        self.iconURL = iconURL
        self.slug = slug
        self.projectId = projectId
    }

    var appStoreDestination: URL? {
        uappAppStoreDestination(url: URL(string: appStoreURL), appleAppId: appleAppId)
    }

    var appStoreReviewDestination: URL? {
        uappAppStoreReviewURL(destination: appStoreDestination)
    }

    enum CodingKeys: String, CodingKey {
        case name, subtitle, appStoreURL, appleAppId, iconURL, slug, projectId
    }

    private enum AlternateCodingKeys: String, CodingKey {
        case appleAppId = "apple_app_id"
        case iconURLSnakeCase = "icon_url"
        case appStoreURL = "appStoreUrl"
        case appStoreURLSnakeCase = "app_store_url"
        case projectId = "project_id"
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
        name = try values.decode(String.self, forKey: .name)
        subtitle = try values.decodeIfPresent(String.self, forKey: .subtitle)
        let decodedAppStoreURL = try values.decodeIfPresent(String.self, forKey: .appStoreURL)
            ?? alternateValues.decodeIfPresent(String.self, forKey: .appStoreURL)
            ?? alternateValues.decodeIfPresent(String.self, forKey: .appStoreURLSnakeCase)
            ?? ""
        appStoreURL = decodedAppStoreURL
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
        iconURL = try values.decodeIfPresent(URL.self, forKey: .iconURL)
            ?? alternateValues.decodeIfPresent(URL.self, forKey: .iconURLSnakeCase)
        slug = try values.decodeIfPresent(String.self, forKey: .slug)
        projectId = try values.decodeIfPresent(String.self, forKey: .projectId)
            ?? alternateValues.decodeIfPresent(String.self, forKey: .projectId)
    }
}
