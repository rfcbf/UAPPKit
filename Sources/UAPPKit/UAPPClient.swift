import Foundation

/// Cliente de baixo nível para as Edge Functions públicas do UAPP.
/// Não guarda estado além da configuração e da identidade corrente.
public actor UAPPClient {
    private let configuration: UAPPConfiguration
    private let transport: UAPPTransport
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
    }

    public func setIdentity(_ identity: UAPPIdentity?) {
        self.identity = identity
    }

    public func currentIdentity() -> UAPPIdentity? {
        identity
    }

    // MARK: - Leitura

    public func feedback(limit: Int = 50) async throws -> [UAPPFeedbackItem] {
        let response: UAPPFeedbackResponse = try await get(
            resource: "feedback",
            limit: limit
        )
        return response.items
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
                .filter { $0.statusId == status.key || $0.statusId == status.name }
                .map {
                    UAPPFeedbackItem(
                        id: $0.id,
                        title: $0.title,
                        body: $0.body,
                        voteCount: $0.voteCount,
                        commentCount: $0.commentCount,
                        createdAt: nil
                    )
                }
            return UAPPRoadmapColumn(
                status: .init(
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

    // MARK: - Escrita

    @discardableResult
    public func submitFeedback(
        title: String,
        body: String? = nil
    ) async throws -> String? {
        var payload: [String: Any] = [
            "slug": configuration.projectId,
            "title": title,
        ]
        if let body { payload["body"] = body }
        if let identity {
            payload["externalId"] = identity.userId
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
        try await attachSignature(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, http) = try await transport.send(request)
        try Self.validate(http, data: data)
        let decoded = try decoder.decode(UAPPSubmitResponse.self, from: data)
        return decoded.id
    }

    // MARK: - Internos

    private func get<T: Decodable>(resource: String, limit: Int) async throws -> T {
        var components = URLComponents(
            url: configuration.functionsBaseURL
                .appendingPathComponent("public-feedback"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "slug", value: configuration.projectId),
            URLQueryItem(name: "resource", value: resource),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let url = components?.url else { throw UAPPKitError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(configuration.projectId, forHTTPHeaderField: "x-uapp-project")
        try await attachSignature(to: &request)

        let (data, http) = try await transport.send(request)
        try Self.validate(http, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw UAPPKitError.invalidResponse
        }
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
