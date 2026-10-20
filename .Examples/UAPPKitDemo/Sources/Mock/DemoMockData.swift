import Foundation
import UAPPKit

/// Modo de demonstração: o Demo responde às chamadas do kit com dados
/// fictícios, sem acessar um projeto real. Ative com o argumento de
/// inicialização `--mock-data` (Scheme → Run → Arguments).
enum DemoMockData {
    static let isEnabled = CommandLine.arguments.contains("--mock-data")
    static let projectSlug = "uapp-demo"
    static let host = URL(string: "https://demo.uappkit.invalid")!

    static let profileName = "Lorem Ipsum"
    static let profileEmail = "lorem.ipsum@example.com"
    static let profileAvatarURL = URL(string: "https://i.pravatar.cc/200?img=68")

    /// Perfil local fictício, usado no lugar do perfil salvo no aparelho.
    static var identity: UAPPIdentity? {
        guard isEnabled else { return nil }
        return UAPPIdentity(
            userId: "50000000-0000-4000-8000-000000000001",
            email: profileEmail,
            displayName: profileName,
            avatarURL: profileAvatarURL
        )
    }

    /// Configuração do Sobre com texto e links fictícios.
    static var aboutConfiguration: UAPPAboutConfiguration? {
        guard isEnabled else { return nil }
        return UAPPAboutConfiguration(
            shortDescription: "Um aplicativo de exemplo para demonstrar as telas nativas do UAPPKit.",
            descriptionLanguageIdentifier: "pt-BR",
            websiteURL: URL(string: "https://example.com"),
            supportURL: URL(string: "mailto:support@example.com"),
            privacyPolicyURL: URL(string: "https://example.com/privacy"),
            termsOfUseURL: URL(string: "https://example.com/terms"),
            license: "MIT",
            showsChangelog: true,
            showsAppStoreReview: true,
            changelogConfiguration: .init(automaticallyScrolls: false, interval: 15, pageSize: 10),
            showsReviews: true,
            reviewsPageSize: 20
        )
    }

    /// Registra o servidor falso antes do `UAPPKit.setup`.
    static func activateIfNeeded() {
        guard isEnabled else { return }
        URLProtocol.registerClass(DemoMockURLProtocol.self)
    }
}

/// Intercepta as requisições ao host de demonstração feitas pela `URLSession.shared`.
final class DemoMockURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == DemoMockData.host.host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let (status, body) = Self.response(for: request)
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url, statusCode: status, httpVersion: "HTTP/1.1",
                  headerFields: ["Content-Type": "application/json", "Cache-Control": "no-store"]
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static let notFound = (404, Data(#"{"error":"not_found"}"#.utf8))

    private static func response(for request: URLRequest) -> (Int, Data) {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return notFound }
        let query = Dictionary(
            (components.queryItems ?? []).map { ($0.name, $0.value ?? "") },
            uniquingKeysWith: { first, _ in first }
        )
        let itemId = query["itemId"]

        switch url.lastPathComponent {
        case "public-feedback":
            switch query["resource"] {
            case "feedback": return (200, feedback(itemId: itemId))
            case "roadmap": return (200, Data(DemoMockData.roadmapJSON.utf8))
            case "changelog": return (200, Data(DemoMockData.changelogJSON.utf8))
            case "reviews": return (200, Data(DemoMockData.reviewsJSON.utf8))
            case "about": return (200, Data(DemoMockData.aboutJSON.utf8))
            case "comments": return (200, comments(itemId: itemId))
            default: return notFound
            }
        case "public-author-profile":
            return (200, authorProfile(itemId: itemId))
        case "public-user-activity":
            return (200, Data(DemoMockData.activityJSON.utf8))
        case "public-feedback-submit", "public-feedback-interact":
            return (200, Data(#"{"ok":true,"id":"20000000-0000-4000-8000-000000000099"}"#.utf8))
        default:
            return notFound
        }
    }

    private static func object(_ json: String) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
    }

    private static func data(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
    }

    private static func feedbackItems() -> [[String: Any]] {
        object(DemoMockData.feedbackJSON)["items"] as? [[String: Any]] ?? []
    }

    private static func feedback(itemId: String?) -> Data {
        guard let itemId else { return Data(DemoMockData.feedbackJSON.utf8) }
        var payload = object(DemoMockData.feedbackJSON)
        payload["items"] = feedbackItems().filter { ($0["id"] as? String)?.lowercased() == itemId.lowercased() }
        return data(payload)
    }

    private static func comments(itemId: String?) -> Data {
        let all = object(DemoMockData.commentsJSON)
        let key = all.keys.first { $0.lowercased() == itemId?.lowercased() }
        let comments: [Any] = key.flatMap { all[$0] as? [Any] } ?? []
        return data(["comments": comments, "nextCursor": NSNull()])
    }

    /// Perfil público do autor do feedback; sem `itemId`, o perfil local fictício.
    private static func authorProfile(itemId: String?) -> Data {
        var payload = object(DemoMockData.activityJSON)
        let item = feedbackItems().first { ($0["id"] as? String)?.lowercased() == itemId?.lowercased() }
        let name = item?["author_name"] as? String ?? DemoMockData.profileName
        let avatar = item == nil
            ? DemoMockData.profileAvatarURL?.absoluteString
            : item?["author_avatar_url"] as? String
        let author: [String: Any] = ["name": name, "avatar_url": avatar.map { $0 as Any } ?? NSNull()]
        payload["author"] = author
        return data(payload)
    }
}
