import Foundation

/// Cliente de baixo nível para as Edge Functions públicas do UAPP.
/// Não guarda estado além da configuração e da identidade corrente.
// swiftlint:disable type_body_length
public actor UAPPClient {
    private let configuration: UAPPConfiguration
    private let transport: UAPPTransport
    private let installationId: String
    private let accessTokenProvider: UAPPAccessTokenProvider?
    nonisolated let isAccountActivityOnly: Bool
    nonisolated let authentication: (any UAPPAuthenticationProvider)?
    private var identity: UAPPIdentity?
    private var project: UAPPProject?
    private var localeIdentifier: String?

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // Cada modelo declara CodingKeys explícitas (snake_case da Data API
        // ou camelCase dos envelopes das Edge Functions), então não usamos
        // conversão automática de chaves.
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Data ISO 8601 inválida: \(value)"
            )
        }
        return decoder
    }()

    public init(
        configuration: UAPPConfiguration,
        transport: UAPPTransport = URLSessionTransport(),
        accessTokenProvider: UAPPAccessTokenProvider? = nil,
        authentication: (any UAPPAuthenticationProvider)? = nil
    ) {
        self.configuration = configuration
        self.transport = transport
        self.accessTokenProvider = accessTokenProvider
        self.authentication = authentication
        installationId = Self.loadInstallationId(projectId: configuration.projectId)
        isAccountActivityOnly = false
        localeIdentifier = configuration.localeIdentifier
    }

    /// Creates a client for global signed-in account activity, without an app slug.
    /// This client is intended for `userActivity(session:limit:cursor:)` only.
    public init(accountActivityHost host: URL, transport: UAPPTransport = URLSessionTransport()) {
        configuration = UAPPConfiguration(projectId: "", host: host)
        self.transport = transport
        accessTokenProvider = nil
        authentication = nil
        installationId = ""
        isAccountActivityOnly = true
        localeIdentifier = nil
    }

    /// Atualiza o idioma preferido para as próximas requisições.
    public func setLocale(_ locale: Locale?) {
        localeIdentifier = locale?.identifier
    }

    public func setIdentity(_ identity: UAPPIdentity?) {
        self.identity = identity
    }

    public func currentIdentity() -> UAPPIdentity? {
        identity
    }

    /// Cria um cliente isolado para participação, sem alterar o cliente público.
    /// Copia o perfil/idioma atuais; o provider acompanha a sessão a cada operação.
    public func withAuthentication(
        identity: UAPPIdentity? = nil,
        accessTokenProvider: UAPPAccessTokenProvider?
    ) async -> UAPPClient {
        let client = UAPPClient(
            configuration: configuration, transport: transport,
            accessTokenProvider: accessTokenProvider
        )
        let profile = identity ?? self.identity
        let locale = localeIdentifier.map { Locale(identifier: $0) }
        await client.setIdentity(profile)
        await client.setLocale(locale)
        return client
    }

    /// Integra a sessão/login completo somente ao cliente de participação.
    public func withAuthentication(
        identity: UAPPIdentity? = nil,
        provider: any UAPPAuthenticationProvider
    ) async -> UAPPClient {
        let client = UAPPClient(configuration: configuration, transport: transport, authentication: provider)
        let profile = identity ?? self.identity
        let locale = localeIdentifier.map { Locale(identifier: $0) }
        await client.setIdentity(profile)
        await client.setLocale(locale)
        return client
    }

    /// Metadados públicos recebidos na última resposta do serviço.
    public func currentProject() -> UAPPProject? {
        project
    }

    // MARK: - Leitura

    func feedbackLiveConfiguration(itemId: String? = nil) async throws -> UAPPFeedbackLiveConfiguration {
        if let itemId, UUID(uuidString: itemId) == nil {
            throw UAPPKitError.invalidResponse
        }
        var components = URLComponents(
            url: configuration.functionsBaseURL.appendingPathComponent("public-feedback-live"), resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "slug", value: configuration.projectId)]
        if let itemId {
            components?.queryItems?.append(URLQueryItem(name: "itemId", value: itemId))
        }
        guard let url = components?.url else { throw UAPPKitError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(configuration.projectId, forHTTPHeaderField: "x-uapp-project")
        request.setValue(installationId, forHTTPHeaderField: "x-uapp-installation-id")
        try await attachSignature(to: &request, includesAuthentication: false)
        let (data, response) = try await transport.send(request)
        try Self.validate(response, data: data)
        let live = try decoder.decode(UAPPFeedbackLiveConfiguration.self, from: data)
        guard live.websocketURL.scheme == "wss", live.websocketURL.host == configuration.host.host,
              live.websocketURL.port == configuration.host.port,
              live.websocketURL.path == "/realtime/v1/websocket",
              live.websocketURL.user == nil, live.websocketURL.password == nil,
              !live.apiKey.isEmpty,
              live.topic == (itemId.map { "uapp-feedback:\($0.lowercased())" }
                  ?? "uapp-feedback-app:\(configuration.projectId)")
        else {
            throw UAPPKitError.invalidResponse
        }
        return live
    }

    /// Histórico global da conta; o servidor identifica o usuário pelo token da sessão.
    public func userActivity(
        session: UAPPAuthenticationSession, limit: Int = 20, cursor: String? = nil
    ) async throws -> UAPPUserActivityPage {
        guard !session.accessToken.isEmpty, !session.accessToken.contains("\r"),
              !session.accessToken.contains("\n") else { throw UAPPAuthenticationError.signInRequired }
        var components = URLComponents(
            url: configuration.functionsBaseURL.appendingPathComponent("public-user-activity"),
            resolvingAgainstBaseURL: false
        )
        var query = [URLQueryItem(name: "limit", value: String(max(1, min(50, limit))))]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components?.queryItems = query
        guard let url = components?.url else { throw UAPPKitError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        attachLocale(to: &request)
        try await attachSignature(to: &request, participationToken: session.accessToken)
        let (data, response) = try await transport.send(request)
        try Self.validate(response, data: data)
        do { return try decoder.decode(UAPPUserActivityPage.self, from: data) }
        catch { throw UAPPKitError.invalidResponse }
    }

    public func feedback(limit: Int = 50) async throws -> [UAPPFeedbackItem] {
        try await feedbackPage(limit: limit).items
    }

    /// Consulta somente o perfil público do autor de um feedback publicado neste projeto.
    public func authorProfile(for feedbackId: String, cursor: String? = nil, statusId: String? = nil) async throws -> UAPPPublicAuthorProfile {
        guard UUID(uuidString: feedbackId) != nil else { throw UAPPKitError.invalidResponse }
        return try await publicProfile(feedbackId: feedbackId, cursor: cursor, statusId: statusId)
    }

    /// Participação pública do perfil local desta instalação, sem exigir uma conta.
    public func participationProfile(cursor: String? = nil, statusId: String? = nil) async throws -> UAPPPublicAuthorProfile {
        try await publicProfile(feedbackId: nil, cursor: cursor, statusId: statusId)
    }

    private func publicProfile(feedbackId: String?, cursor: String?, statusId: String?) async throws -> UAPPPublicAuthorProfile {
        if let statusId, UUID(uuidString: statusId) == nil {
            throw UAPPKitError.invalidResponse
        }
        var components = URLComponents(
            url: configuration.functionsBaseURL.appendingPathComponent("public-author-profile"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "slug", value: configuration.projectId)]
        if let feedbackId {
            components?.queryItems?.append(URLQueryItem(name: "itemId", value: feedbackId))
        } else {
            components?.queryItems?.append(URLQueryItem(name: "viewer", value: "installation"))
        }
        if let cursor {
            components?.queryItems?.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let statusId {
            components?.queryItems?.append(URLQueryItem(name: "statusId", value: statusId))
        }
        guard let url = components?.url else { throw UAPPKitError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(configuration.projectId, forHTTPHeaderField: "x-uapp-project")
        request.setValue(installationId, forHTTPHeaderField: "x-uapp-installation-id")
        attachLocale(to: &request)
        try await attachSignature(to: &request, includesAuthentication: false)
        let (data, response) = try await transport.send(request)
        try Self.validate(response, data: data)
        do { return try decoder.decode(UAPPPublicAuthorProfile.self, from: data) }
        catch { throw UAPPKitError.invalidResponse }
    }

    public func feedbackPage(
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> UAPPFeedbackPage {
        try await feedbackPage(limit: limit, cursor: cursor, itemId: nil)
    }

    public func feedbackPage(
        limit: Int = 50,
        cursor: String? = nil,
        itemId: String?
    ) async throws -> UAPPFeedbackPage {
        let response: UAPPFeedbackResponse = try await get(
            resource: "feedback",
            limit: limit,
            cursor: cursor,
            itemId: itemId
        )
        project = response.project ?? project
        let statuses = (response.statuses ?? []).sorted { $0.position < $1.position }.map {
            UAPPRoadmapColumn.Status(id: $0.id, key: $0.key, name: $0.name, position: $0.position, color: $0.color)
        }
        return UAPPFeedbackPage(items: response.items, nextCursor: response.nextCursor, statuses: statuses)
    }

    public func roadmap(limit: Int = 50) async throws -> [UAPPRoadmapColumn] {
        let response: UAPPRoadmapResponse = try await get(
            resource: "roadmap",
            limit: limit
        )
        project = response.project ?? project
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
                        createdAt: $0.createdAt,
                        authorName: $0.authorName,
                        authorAvatarURL: $0.authorAvatarURL,
                        statusId: $0.statusId,
                        voters: $0.voters,
                        imageURL: $0.imageURL,
                        imageURLs: $0.imageURLs
                    )
                }
            return UAPPRoadmapColumn(
                status: .init(
                    id: status.id,
                    key: status.key,
                    name: status.name,
                    position: status.position,
                    color: status.color
                ),
                items: items
            )
        }
    }

    public func changelog(
        limit: Int = 50,
        filters: UAPPChangelogFilters = .init()
    ) async throws -> [UAPPChangelogEntry] {
        try await changelogPage(limit: limit, filters: filters).entries
    }

    public func changelogPage(
        limit: Int = 50,
        cursor: String? = nil,
        filters: UAPPChangelogFilters = .init()
    ) async throws -> UAPPChangelogPage {
        let response: UAPPChangelogResponse = try await get(
            resource: "changelog",
            limit: limit,
            cursor: cursor,
            filters: filters
        )
        project = response.project ?? project
        return UAPPChangelogPage(
            entries: response.entries,
            nextCursor: response.nextCursor,
            totalCount: response.totalCount
        )
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
        try await submitFeedback(title: title, body: body, category: category, imageData: nil)
    }

    @discardableResult
    public func submitFeedback(
        title: String,
        body: String? = nil,
        category: UAPPFeedbackCategory = .feature,
        imageData: Data?
    ) async throws -> String? {
        let imagePayload = try Self.feedbackImagePayload(imageData)
        return try await submitFeedbackWithImages(
            title: title,
            body: body,
            category: category,
            images: imagePayload.map { [$0] } ?? [],
            legacy: true
        )
    }

    /// Envia até duas imagens compactadas, de no máximo 512 KiB cada.
    @discardableResult
    public func submitFeedback(
        title: String,
        body: String? = nil,
        category: UAPPFeedbackCategory = .feature,
        imagesData: [Data]
    ) async throws -> String? {
        let images = try Self.feedbackImagesPayload(imagesData)
        return try await submitFeedbackWithImages(title: title, body: body, category: category, images: images, legacy: false)
    }

    private func submitFeedbackWithImages(
        title: String, body: String?, category: UAPPFeedbackCategory,
        images: [[String: String]], legacy: Bool
    ) async throws -> String? {
        let session = try await prepareParticipation()
        let profile = session?.identity ?? identity
        var payload: [String: Any] = [
            "slug": configuration.projectId,
            "title": title,
            "category": category.rawValue,
            "installationId": installationId
        ]
        if let body {
            payload["body"] = body
        }
        if legacy {
            if let image = images.first {
                payload["image"] = image
            }
        } else if !images.isEmpty {
            payload["images"] = images
        }
        if let profile {
            if let email = profile.email {
                payload["email"] = email
            }
            if let name = profile.displayName {
                payload["displayName"] = name
            }
            if session == nil {
                var photo = profile.avatarData
                if photo == nil, let url = profile.avatarURL, url.isFileURL {
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size > 0, size <= 512 * 1024 else { throw UAPPKitError.invalidResponse }
                    photo = try Data(contentsOf: url)
                }
                if let data = photo {
                    guard !data.isEmpty, data.count <= 512 * 1024 else { throw UAPPKitError.invalidResponse }
                    let jpeg = data.starts(with: [0xFF, 0xD8, 0xFF])
                    let png = data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
                    guard jpeg || png else { throw UAPPKitError.invalidResponse }
                    let mimeType = jpeg ? "image/jpeg" : "image/png"
                    payload["profilePhoto"] = ["mimeType": mimeType, "base64": data.base64EncodedString()]
                } else if profile.avatarURL == nil {
                    payload["profilePhoto"] = NSNull()
                }
            }
        }

        var request = URLRequest(
            url: configuration.functionsBaseURL
                .appendingPathComponent("public-feedback-submit")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.projectId, forHTTPHeaderField: "x-uapp-project")
        attachLocale(to: &request)
        request.setValue(UUID().uuidString, forHTTPHeaderField: "idempotency-key")
        try await attachSignature(to: &request, participationToken: session?.accessToken)
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
        let session = try await prepareParticipation()
        var payload: [String: Any] = [
            "slug": configuration.projectId,
            "installationId": installationId,
            "itemId": itemId,
            "action": kind.rawValue == "like" ? UAPPReactionKind.vote.rawValue : kind.rawValue,
            "enabled": enabled
        ]
        if let commentId {
            payload["commentId"] = commentId
        }
        _ = try await postInteraction(payload, participationToken: session?.accessToken)
    }

    @discardableResult
    public func submitComment(
        itemId: String,
        body: String,
        parentCommentId: String? = nil
    ) async throws -> String? {
        try await submitComment(itemId: itemId, body: body, parentCommentId: parentCommentId, imageData: nil)
    }

    @discardableResult
    public func submitComment(
        itemId: String,
        body: String,
        parentCommentId: String? = nil,
        imageData: Data?
    ) async throws -> String? {
        let imagePayload = try Self.feedbackImagePayload(imageData)
        return try await submitCommentWithImages(
            itemId: itemId,
            body: body,
            parentCommentId: parentCommentId,
            images: imagePayload.map { [$0] } ?? [],
            legacy: true
        )
    }

    /// Envia até duas imagens compactadas, de no máximo 512 KiB cada.
    @discardableResult
    public func submitComment(
        itemId: String,
        body: String,
        parentCommentId: String? = nil,
        imagesData: [Data]
    ) async throws -> String? {
        let images = try Self.feedbackImagesPayload(imagesData)
        return try await submitCommentWithImages(itemId: itemId, body: body, parentCommentId: parentCommentId, images: images, legacy: false)
    }

    private func submitCommentWithImages(
        itemId: String, body: String, parentCommentId: String?,
        images: [[String: String]], legacy: Bool
    ) async throws -> String? {
        let session = try await prepareParticipation()
        let profile = session?.identity ?? identity
        var payload: [String: Any] = [
            "slug": configuration.projectId,
            "installationId": installationId,
            "itemId": itemId,
            "action": "comment",
            "body": body
        ]
        if let parentCommentId {
            payload["parentCommentId"] = parentCommentId
        }
        if legacy {
            if let image = images.first {
                payload["image"] = image
            }
        } else if !images.isEmpty {
            payload["images"] = images
        }
        if let name = profile?.displayName {
            payload["displayName"] = name
        }
        let decoded = try await postInteraction(payload, participationToken: session?.accessToken)
        return decoded.id
    }

    // MARK: - Internos

    private static func feedbackImagesPayload(_ images: [Data]) throws -> [[String: String]] {
        guard images.count <= 2 else { throw UAPPKitError.invalidResponse }
        return try images.map { data in
            guard data.count <= 512 * 1024, let payload = try feedbackImagePayload(data) else {
                throw UAPPKitError.invalidResponse
            }
            return payload
        }
    }

    /// Uma imagem JPEG ou PNG de até 2 MiB por feedback/comentário.
    private static func feedbackImagePayload(_ data: Data?) throws -> [String: String]? {
        guard let data else { return nil }
        guard !data.isEmpty, data.count <= 2 * 1024 * 1024 else {
            throw UAPPKitError.invalidResponse
        }
        let mimeType: String
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            mimeType = "image/jpeg"
        } else if data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            mimeType = "image/png"
        } else {
            throw UAPPKitError.invalidResponse
        }
        return ["mimeType": mimeType, "base64": data.base64EncodedString()]
    }

    /// Recarrega todas as páginas para incluir comentários recém-publicados.
    func allComments(itemId: String) async throws -> [UAPPComment] {
        var result: [UAPPComment] = []
        var cursor: String?
        var seenCursors: Set<String> = []
        repeat {
            try Task.checkCancellation()
            let page = try await comments(itemId: itemId, limit: 100, cursor: cursor)
            result.append(contentsOf: page.comments)
            cursor = page.nextCursor
            if let cursor, !seenCursors.insert(cursor).inserted {
                throw UAPPKitError.invalidResponse
            }
        } while cursor != nil
        var seenIds: Set<String> = []
        return result.filter { seenIds.insert($0.id).inserted }
    }

    private func get<T: Decodable>(
        resource: String,
        limit: Int,
        cursor: String? = nil,
        itemId: String? = nil,
        filters: UAPPChangelogFilters? = nil
    ) async throws -> T {
        var components = URLComponents(
            url: configuration.functionsBaseURL
                .appendingPathComponent("public-feedback"),
            resolvingAgainstBaseURL: false
        )
        var queryItems = [
            URLQueryItem(name: "slug", value: configuration.projectId),
            URLQueryItem(name: "resource", value: resource),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let itemId {
            queryItems.append(URLQueryItem(name: "itemId", value: itemId))
        }
        if let filters {
            queryItems.append(contentsOf: filters.queryItems)
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw UAPPKitError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(configuration.projectId, forHTTPHeaderField: "x-uapp-project")
        request.setValue(installationId, forHTTPHeaderField: "x-uapp-installation-id")
        attachLocale(to: &request)
        try await attachSignature(
            to: &request,
            includesAuthentication: ["feedback", "roadmap", "comments"].contains(resource)
        )

        let (data, http) = try await transport.send(request)
        if !(200 ..< 300).contains(http.statusCode),
           let errorResponse = try? decoder.decode(UAPPErrorResponse.self, from: data),
           let responseProject = errorResponse.project
        {
            project = responseProject
        }
        try Self.validate(http, data: data)
        do {
            let response = try decoder.decode(T.self, from: data)
            if let responseProject = (response as? UAPPFeedbackResponse)?.project
                ?? (response as? UAPPRoadmapResponse)?.project
                ?? (response as? UAPPChangelogResponse)?.project
                ?? (response as? UAPPReviewsResponse)?.project
                ?? (response as? UAPPAboutResponse)?.project
            {
                project = responseProject
            }
            return response
        } catch {
            throw UAPPKitError.invalidResponse
        }
    }

    private func postInteraction(
        _ payload: [String: Any],
        participationToken: String? = nil
    ) async throws -> UAPPSubmitResponse {
        var request = URLRequest(
            url: configuration.functionsBaseURL
                .appendingPathComponent("public-feedback-interact")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.projectId, forHTTPHeaderField: "x-uapp-project")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "idempotency-key")
        attachLocale(to: &request)
        try await attachSignature(to: &request, participationToken: participationToken)
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

    private func attachSignature(
        to request: inout URLRequest,
        includesAuthentication: Bool = true,
        participationToken: String? = nil
    ) async throws {
        if let participationToken {
            request.setValue("Bearer \(participationToken)", forHTTPHeaderField: "Authorization")
        } else if includesAuthentication, let authentication,
                  let session = try? await authentication.currentSession()
        {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
        if includesAuthentication, authentication == nil, let provider = accessTokenProvider,
           let token = try await provider()
        {
            let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty, !token.contains("\r"), !token.contains("\n") else {
                throw UAPPKitError.invalidResponse
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let provider = configuration.signatureProvider {
            let token = try await provider()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "x-uapp-signature")
        }
    }

    private func prepareParticipation() async throws -> UAPPAuthenticationSession? {
        guard let authentication else { return nil }
        guard let session = try await authentication.currentSession() else {
            throw UAPPAuthenticationError.signInRequired
        }
        guard !session.accessToken.isEmpty, !session.accessToken.contains("\n"), !session.accessToken.contains("\r") else {
            throw UAPPKitError.invalidResponse
        }
        identity = session.identity
        return session
    }

    private func attachLocale(to request: inout URLRequest) {
        guard let localeIdentifier else { return }
        request.setValue(localeIdentifier, forHTTPHeaderField: "Accept-Language")
    }

    static func validate(_ http: HTTPURLResponse, data: Data) throws {
        guard (200 ..< 300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data))
                .flatMap { $0 as? [String: Any] }?["error"] as? String
            throw UAPPKitError.http(status: http.statusCode, message: message)
        }
    }
}

// swiftlint:enable type_body_length

public extension UAPPClient {
    /// Avaliações da App Store/TestFlight sincronizadas e expostas pelo UAPP.
    func reviews(limit: Int = 50) async throws -> [UAPPReview] {
        let response: UAPPReviewsResponse = try await get(resource: "reviews", limit: limit)
        project = response.project ?? project
        return response.reviews
    }

    /// Carrega uma página sem alterar o método `reviews(limit:)` existente.
    func reviewsPage(limit: Int = 20, cursor: String? = nil) async throws -> UAPPReviewsPage {
        let response: UAPPReviewsResponse = try await get(resource: "reviews", limit: limit, cursor: cursor)
        project = response.project ?? project
        return UAPPReviewsPage(reviews: response.reviews, nextCursor: response.nextCursor)
    }

    /// Informações públicas opcionais do desenvolvedor e seus outros apps.
    func about() async throws -> UAPPAbout {
        let response: UAPPAboutResponse = try await get(resource: "about", limit: 1)
        project = response.project ?? project
        return response.about
    }

    /// Retorna o destino de avaliação do projeto configurado.
    ///
    /// O UAPP pode publicar o destino diretamente nos metadados do projeto ou
    /// dentro da lista de aplicativos do desenvolvedor; as duas formas são
    /// aceitas para manter compatibilidade entre versões do backend.
    func appStoreReviewDestination() async throws -> URL? {
        if let destination = currentProject()?.appStoreReviewDestination {
            return destination
        }

        let about = try await about()
        let project = currentProject()

        if let destination = project?.appStoreReviewDestination {
            return destination
        }

        let projectIdentifier = project?.slug ?? configuration.projectId
        let displayName = project?.displayName
        return about.apps.first { app in
            if app.slug == projectIdentifier || app.projectId == projectIdentifier {
                return true
            }
            guard let displayName else { return false }
            return normalizedAppName(app.name) == normalizedAppName(displayName)
        }?.appStoreReviewDestination
    }

    private func normalizedAppName(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
