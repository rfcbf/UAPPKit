import Foundation

/// Cliente de baixo nível para as Edge Functions públicas do UAPP.
/// Não guarda estado além da configuração e da identidade corrente.
public actor UAPPClient {
    private let configuration: UAPPConfiguration
    private let transport: UAPPTransport
    private let installationId: String
    private var identity: UAPPIdentity?

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // Cada modelo declara CodingKeys explícitas (snake_case da Data API
        // ou camelCase dos envelopes das Edge Functions), então não usamos
        // conversão automática de chaves.
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public init(
        configuration: UAPPConfiguration,
        transport: UAPPTransport = URLSessionTransport()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.installationId = Self.loadInstallationId(projectId: configuration.projectId)
    }

    public func setIdentity(_ identity: UAPPIdentity?) {
        self.identity = identity
    }

    public func currentIdentity() -> UAPPIdentity? {
        identity
    }

    // MARK: - Leitura

    public func feedback(limit: Int = 50) async throws -> [UAPPFeedbackItem] {
        try await feedbackPage(limit: limit).items
    }

    public func feedbackPage(
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> UAPPFeedbackPage {
        let response: UAPPFeedbackResponse = try await get(
            resource: "feedback",
            limit: limit,
            cursor: cursor
        )
        return UAPPFeedbackPage(items: response.items, nextCursor: response.nextCursor)
    }

    public func roadmap(limit: Int = 50) async throws -> [UAPPRoadmapColumn] {
        let response: UAPPRoadmapResponse = try await get(
            resource: "roadmap",
            limit: limit
        )
        let visible = response.statuses
            .filter { $0.isRoadmapVisible ?? true }
            .sorted { $0.position < $1.position }

        return visible.map { status in
            let items = response.items
                .filter { $0.statusId == status.id }
                .map {
                    UAPPFeedbackItem(
                        id: $0.id,
                        title: $0.title,
                        body: $0.body,
                        voteCount: $0.voteCount,
                        likeCount: $0.likeCount,
                        commentCount: $0.commentCount,
                        category: $0.category,
                        priority: $0.priority,
                        viewerVoted: $0.viewerVoted,
                        viewerLiked: $0.viewerLiked,
                        createdAt: nil
                    )
                }
            return UAPPRoadmapColumn(
                status: .init(
                    id: status.id,
                    key: status.key,
                    name: status.name,
                    position: status.position
                ),
                items: items
            )
        }
    }

    public func changelog(limit: Int = 50) async throws -> [UAPPChangelogEntry] {
        let response: UAPPChangelogResponse = try await get(
            resource: "changelog",
            limit: limit
        )
        return response.entries
    }

    public func comments(
        itemId: String,
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> UAPPCommentsPage {
        let response: UAPPCommentsResponse = try await get(
            resource: "comments",
            limit: limit,
            cursor: cursor,
            itemId: itemId
        )
        return UAPPCommentsPage(
            comments: response.comments,
            nextCursor: response.nextCursor
        )
    }

    // MARK: - Escrita

    @discardableResult
    public func submitFeedback(
        title: String,
        body: String? = nil,
        category: UAPPFeedbackCategory = .feature
    ) async throws -> String? {
        var payload: [String: Any] = [
            "slug": configuration.projectId,
            "title": title,
            "category": category.rawValue,
            "installationId": installationId,
        ]
        if let body { payload["body"] = body }
        if let identity {
            if let email = identity.email { payload["email"] = email }
            if let name = identity.displayName { payload["displayName"] = name }
        }

        var request = URLRequest(
            url: configuration.functionsBaseURL
                .appendingPathComponent("public-feedback-submit")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.projectId, forHTTPHeaderField: "x-uapp-project")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "idempotency-key")
        try await attachSignature(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, http) = try await transport.send(request)
        try Self.validate(http, data: data)
        let decoded = try decoder.decode(UAPPSubmitResponse.self, from: data)
        return decoded.id
    }

    public func setReaction(
        itemId: String,
        commentId: String? = nil,
        kind: UAPPReactionKind,
        enabled: Bool
    ) async throws {
        var payload: [String: Any] = [
            "slug": configuration.projectId,
            "installationId": installationId,
            "itemId": itemId,
            "action": kind.rawValue,
            "enabled": enabled,
        ]
        if let commentId { payload["commentId"] = commentId }
        _ = try await postInteraction(payload)
    }

    @discardableResult
    public func submitComment(
        itemId: String,
        body: String,
        parentCommentId: String? = nil
    ) async throws -> String? {
        var payload: [String: Any] = [
            "slug": configuration.projectId,
            "installationId": installationId,
            "itemId": itemId,
            "action": "comment",
            "body": body,
        ]
        if let parentCommentId { payload["parentCommentId"] = parentCommentId }
        if let name = identity?.displayName { payload["displayName"] = name }
        let decoded = try await postInteraction(payload)
        return decoded.id
    }

    // MARK: - Internos

    private func get<T: Decodable>(
        resource: String,
        limit: Int,
        cursor: String? = nil,
        itemId: String? = nil
    ) async throws -> T {
        var components = URLComponents(
            url: configuration.functionsBaseURL
                .appendingPathComponent("public-feedback"),
            resolvingAgainstBaseURL: false
        )
        var queryItems = [
            URLQueryItem(name: "slug", value: configuration.projectId),
            URLQueryItem(name: "resource", value: resource),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let itemId { queryItems.append(URLQueryItem(name: "itemId", value: itemId)) }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw UAPPKitError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(configuration.projectId, forHTTPHeaderField: "x-uapp-project")
        request.setValue(installationId, forHTTPHeaderField: "x-uapp-installation-id")
        try await attachSignature(to: &request)

        let (data, http) = try await transport.send(request)
        try Self.validate(http, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw UAPPKitError.invalidResponse
        }
    }

    private func postInteraction(_ payload: [String: Any]) async throws -> UAPPSubmitResponse {
        var request = URLRequest(
            url: configuration.functionsBaseURL
                .appendingPathComponent("public-feedback-interact")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.projectId, forHTTPHeaderField: "x-uapp-project")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "idempotency-key")
        try await attachSignature(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, http) = try await transport.send(request)
        try Self.validate(http, data: data)
        do {
            return try decoder.decode(UAPPSubmitResponse.self, from: data)
        } catch {
            throw UAPPKitError.invalidResponse
        }
    }

    private static func loadInstallationId(projectId: String) -> String {
        let key = "uapp.installation.\(projectId)"
        if let stored = UserDefaults.standard.string(forKey: key), UUID(uuidString: stored) != nil {
            return stored
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: key)
        return created
    }

    private func attachSignature(to request: inout URLRequest) async throws {
        guard let provider = configuration.signatureProvider else { return }
        let token = try await provider()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "x-uapp-signature")
    }

    static func validate(_ http: HTTPURLResponse, data: Data) throws {
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data))
                .flatMap { $0 as? [String: Any] }?["error"] as? String
            throw UAPPKitError.http(status: http.statusCode, message: message)
        }
    }
}
