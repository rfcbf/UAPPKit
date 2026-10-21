import CryptoKit
import Foundation

/// Login próprio opcional, configurado ao entrar em Feedback/Roadmap.
/// Usa somente chave pública; nunca informar service_role ou chave secreta.
public struct UAPPAuthenticationConfiguration: Sendable {
    public let host: URL
    public let publishableKey: String
    public let callbackURL: URL
    public let methods: [UAPPLoginMethod]
    public let persistsSession: Bool

    /// Login no servidor de produção do UAPP, com a chave pública desse servidor.
    public init(
        publishableKey: String,
        callbackURL: URL = UAPPAuthentication.defaultCallbackURL,
        methods: [UAPPLoginMethod] = UAPPLoginMethod.allCases,
        persistsSession: Bool = true
    ) {
        self.init(
            host: UAPPConfiguration.defaultHost, publishableKey: publishableKey,
            callbackURL: callbackURL, methods: methods, persistsSession: persistsSession
        )
    }

    /// Variante interna para outro servidor do UAPP (ferramentas da equipe e testes).
    @_spi(UAPPInternal)
    public init(
        host: URL,
        publishableKey: String,
        callbackURL: URL = UAPPAuthentication.defaultCallbackURL,
        methods: [UAPPLoginMethod] = UAPPLoginMethod.allCases,
        persistsSession: Bool = true
    ) {
        self.persistsSession = persistsSession
        self.host = host
        self.publishableKey = publishableKey
        self.callbackURL = callbackURL
        self.methods = methods
    }
}

/// O app pode fornecer uma apresentação OAuth própria; a padrão usa AuthenticationServices.
public typealias UAPPOAuthPresenter = @MainActor @Sendable (URL, URL) async throws -> URL

/// Autenticação do UAPP por código de e-mail e OAuth/PKCE, sem dependências externas.
/// A sessão é mantida no Keychain e restaurada ao reutilizar a configuração.
public actor UAPPAuthentication: UAPPAuthenticationProvider {
    /// Endereço de retorno do login com Apple, Google e GitHub, o mesmo para todos os aplicativos.
    ///
    /// O retorno é capturado pela própria sessão de login (`ASWebAuthenticationSession`), sem
    /// passar pelo sistema: o aplicativo não registra esquema em URL Types e vários aplicativos
    /// podem usar o mesmo endereço sem conflito. O código devolvido só vale com o verificador
    /// PKCE guardado por quem iniciou o login. O serviço de autenticação habilita este endereço
    /// uma única vez para todos os aplicativos.
    public static let defaultCallbackURL = URL(string: "uappkit://authentication")!

    /// Login gerenciado pelo kit, com configuração pública descoberta sob demanda.
    /// Conserve este provedor para reutilizar a sessão. Use o `callbackURL` padrão; um endereço
    /// próprio só funciona se também for habilitado no serviço de autenticação.
    public nonisolated static func automatic(
        configuration: UAPPConfiguration,
        callbackURL: URL = defaultCallbackURL,
        methods: [UAPPLoginMethod] = UAPPLoginMethod.allCases
    ) -> any UAPPAuthenticationProvider {
        UAPPAutomaticAuthentication(
            configuration: configuration, callbackURL: callbackURL, methods: methods,
            sessionStorage: UAPPKeychainSessionStorage(account: UAPPKeychainSessionStorage.account(
                host: configuration.host, projectId: configuration.projectId
            ))
        )
    }

    public nonisolated let methods: [UAPPLoginMethod]
    public nonisolated let supportsProfilePhoto = true
    public nonisolated let supportsAccountDeletion = true
    private let configuration: UAPPAuthenticationConfiguration
    private let transport: UAPPTransport
    private let oauthPresenter: UAPPOAuthPresenter
    private let now: @Sendable () -> Date
    private let sessionStorage: any UAPPSessionStorage
    private var didRestoreSession = false
    private var isRecoverySession = false
    private var storedSession: SessionResponse?
    private var expiresAt: Date?
    private var refreshTask: Task<SessionResponse, Error>?
    private var generation = 0

    public init(
        configuration: UAPPAuthenticationConfiguration,
        transport: UAPPTransport = URLSessionTransport(),
        oauthPresenter: @escaping UAPPOAuthPresenter = UAPPOAuthBrowser.present
    ) {
        self.configuration = configuration
        self.transport = transport
        self.oauthPresenter = oauthPresenter
        if configuration.persistsSession {
            sessionStorage = UAPPKeychainSessionStorage(
                account: UAPPKeychainSessionStorage.account(host: configuration.host)
            )
        } else {
            sessionStorage = UAPPTransientSessionStorage()
        }
        methods = configuration.methods
        now = Date.init
    }

    init(
        configuration: UAPPAuthenticationConfiguration,
        transport: UAPPTransport,
        oauthPresenter: @escaping UAPPOAuthPresenter,
        now: @escaping @Sendable () -> Date,
        sessionStorage: any UAPPSessionStorage = UAPPTransientSessionStorage()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.oauthPresenter = oauthPresenter
        self.now = now
        self.sessionStorage = sessionStorage
        methods = configuration.methods
    }

    public func currentSession() async throws -> UAPPAuthenticationSession? {
        try restoreSession()
        guard let storedSession else { return nil }
        if let expiresAt, expiresAt > now().addingTimeInterval(30) {
            return storedSession.session
        }
        let capturedGeneration = generation
        let task: Task<SessionResponse, Error>
        if let refreshTask {
            task = refreshTask
        } else {
            task = Task {
                let response = try await self.token(
                    grant: "refresh_token",
                    body: ["refresh_token": storedSession.refreshToken]
                )
                return await self.withProfile(response, previous: storedSession.user)
            }
            refreshTask = task
        }
        do {
            let response = try await task.value
            guard capturedGeneration == generation else { return nil }
            refreshTask = nil
            return try store(response)
        } catch {
            if capturedGeneration == generation {
                refreshTask = nil
                if case UAPPKitError.http(status: 400, _) = error {
                    try clear()
                }
                if case UAPPKitError.http(status: 401, _) = error {
                    try clear()
                }
            }
            throw error
        }
    }

    public func signIn(email: String, password: String) async throws -> UAPPAuthenticationSession {
        guard methods.contains(.email) else { throw UAPPAuthenticationError.unsupportedMethod }
        let capturedGeneration = generation
        let response = try await withProfile(token(grant: "password", body: ["email": email, "password": password]))
        guard capturedGeneration == generation else { throw UAPPAuthenticationError.cancelled }
        return try store(response, recovery: false)
    }

    public func requestEmailCode(email: String) async throws {
        guard methods.contains(.email) else { throw UAPPAuthenticationError.unsupportedMethod }
        _ = try await request(path: "otp", body: ["email": email, "create_user": true])
    }

    public func signUp(email: String, password: String, displayName: String? = nil) async throws -> UAPPRegistrationResult {
        guard methods.contains(.email) else { throw UAPPAuthenticationError.unsupportedMethod }
        guard UAPPPasswordPolicy.isValid(password) else { throw UAPPAuthenticationError.weakPassword }
        let capturedGeneration = generation
        var body: [String: Any] = ["email": email, "password": password]
        if let displayName, !displayName.isEmpty {
            body["data"] = ["full_name": displayName]
        }
        let data = try await request(path: "signup", body: body)
        guard capturedGeneration == generation else { throw UAPPAuthenticationError.cancelled }
        let result = try JSONDecoder().decode(RegistrationResponse.self, from: data)
        if let token = result.accessToken, !token.isEmpty {
            let response = try await withProfile(decodeSession(data))
            guard capturedGeneration == generation else { throw UAPPAuthenticationError.cancelled }
            return try .signedIn(store(response, recovery: false))
        }
        guard let userId = result.id ?? result.user?.id, !userId.isEmpty else { throw UAPPKitError.invalidResponse }
        return .confirmationRequired
    }

    public func resendSignupCode(email: String) async throws {
        guard methods.contains(.email) else { throw UAPPAuthenticationError.unsupportedMethod }
        _ = try await request(path: "resend", body: ["email": email, "type": "signup"])
    }

    public func verifySignupCode(email: String, code: String) async throws -> UAPPAuthenticationSession {
        try await verify(email: email, code: code, type: "signup")
    }

    public func requestPasswordReset(email: String) async throws {
        guard methods.contains(.email) else { throw UAPPAuthenticationError.unsupportedMethod }
        _ = try await request(path: "recover", body: ["email": email])
    }

    public func verifyPasswordResetCode(email: String, code: String) async throws {
        _ = try await verify(email: email, code: code, type: "recovery")
    }

    public func updatePassword(_ password: String) async throws -> UAPPAuthenticationSession {
        guard let session = try await currentSession() else { throw UAPPAuthenticationError.signInRequired }
        guard UAPPPasswordPolicy.isValid(password) else { throw UAPPAuthenticationError.weakPassword }
        let capturedGeneration = generation
        _ = try await request(path: "user", body: ["password": password], accessToken: session.accessToken, method: "PUT")
        guard capturedGeneration == generation else { throw UAPPAuthenticationError.cancelled }
        try persistSession()
        isRecoverySession = false
        return session
    }

    /// Associa um JPEG já recortado à conta autenticada e persiste a sessão atualizada.
    public func uploadProfilePhoto(_ data: Data) async throws -> UAPPAuthenticationSession {
        guard data.starts(with: [0xFF, 0xD8, 0xFF]), data.count <= 512 * 1024 else {
            throw UAPPKitError.invalidResponse
        }
        guard let session = try await currentSession(),
              !session.identity.userId.isEmpty,
              !session.identity.userId.contains("/"), !isRecoverySession
        else { throw UAPPAuthenticationError.signInRequired }
        try validateConfiguration()
        let capturedGeneration = generation
        let path = session.identity.userId + "/" + UUID().uuidString.lowercased() + ".jpg"
        let storageURL = configuration.host.appendingPathComponent("storage/v1/object/avatars")
            .appendingPathComponent(path)
        var upload = URLRequest(url: storageURL)
        upload.httpMethod = "POST"
        upload.httpBody = data
        upload.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        upload.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        upload.setValue("Bearer " + session.accessToken, forHTTPHeaderField: "Authorization")
        let (body, response) = try await transport.send(upload)
        try UAPPClient.validate(response, data: body)
        let avatarURL = configuration.host.appendingPathComponent("storage/v1/object/public/avatars")
            .appendingPathComponent(path)
        do {
            guard capturedGeneration == generation else { throw UAPPAuthenticationError.cancelled }
            let userData = try await request(
                path: "user", body: ["data": [
                    "avatar_url": avatarURL.absoluteString,
                    SessionResponse.User.chosenAvatarKey: avatarURL.absoluteString
                ]],
                accessToken: session.accessToken, method: "PUT"
            )
            guard capturedGeneration == generation, let current = storedSession else {
                throw UAPPAuthenticationError.cancelled
            }
            let decoded = try JSONDecoder().decode(SessionResponse.User.self, from: userData)
            guard decoded.id == session.identity.userId,
                  decoded.metadata[SessionResponse.User.chosenAvatarKey] == avatarURL.absoluteString
            else {
                throw UAPPKitError.invalidResponse
            }
            // O perfil do UAPP é o mesmo do painel web: a foto nova vale nos dois lugares.
            let savedInProfile = await saveProfileAvatar(avatarURL, userId: decoded.id, accessToken: session.accessToken)
            var metadata = decoded.metadata
            metadata[SessionResponse.User.profileNameKey] = current.user.metadata[SessionResponse.User.profileNameKey]
            if savedInProfile {
                metadata[SessionResponse.User.profileAvatarKey] = avatarURL.absoluteString
            }
            let user = SessionResponse.User(id: decoded.id, email: decoded.email, metadata: metadata)
            let updated = SessionResponse(
                accessToken: current.accessToken, refreshToken: current.refreshToken,
                expiresIn: current.expiresIn, user: user
            )
            storedSession = updated
            try persistSession()
            return updated.session
        } catch {
            // Evita deixar um arquivo novo sem vínculo quando a atualização do perfil falha.
            if storedSession?.user.metadata[SessionResponse.User.chosenAvatarKey] != avatarURL.absoluteString {
                var removal = URLRequest(url: configuration.host.appendingPathComponent("storage/v1/object/avatars"))
                removal.httpMethod = "DELETE"
                removal.setValue("application/json", forHTTPHeaderField: "Content-Type")
                removal.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
                removal.setValue("Bearer " + session.accessToken, forHTTPHeaderField: "Authorization")
                removal.httpBody = try? JSONSerialization.data(withJSONObject: ["prefixes": [path]])
                _ = try? await transport.send(removal)
            }
            throw error
        }
    }

    private func verify(email: String, code: String, type: String) async throws -> UAPPAuthenticationSession {
        guard methods.contains(.email) else { throw UAPPAuthenticationError.unsupportedMethod }
        let capturedGeneration = generation
        let data = try await request(path: "verify", body: ["email": email, "token": code, "type": type])
        let session = try decodeSession(data)
        let result = type == "recovery" ? session : await withProfile(session)
        guard capturedGeneration == generation else { throw UAPPAuthenticationError.cancelled }
        return try store(result, recovery: type == "recovery")
    }

    private struct RegistrationResponse: Decodable {
        let accessToken: String?
        let id: String?
        let user: RegisteredUser?
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case id, user
        }

        struct RegisteredUser: Decodable {
            let id: String
            enum CodingKeys: String, CodingKey { case id }
        }
    }

    public func verifyEmailCode(email: String, code: String) async throws -> UAPPAuthenticationSession {
        guard methods.contains(.email) else { throw UAPPAuthenticationError.unsupportedMethod }
        let capturedGeneration = generation
        let data = try await request(path: "verify", body: ["email": email, "token": code, "type": "email"])
        let response = try await withProfile(decodeSession(data))
        guard capturedGeneration == generation else { throw UAPPAuthenticationError.cancelled }
        return try store(response, recovery: false)
    }

    public func signIn(method: UAPPLoginMethod) async throws -> UAPPAuthenticationSession {
        guard method != .email, methods.contains(method) else { throw UAPPAuthenticationError.unsupportedMethod }
        try validateConfiguration()
        let capturedGeneration = generation
        // Two UUIDs supply more than 128 bits of entropy; verifier is 64 RFC 7636 characters.
        let verifier = (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        var components = URLComponents(url: authURL(path: "authorize"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "provider", value: method.rawValue),
            URLQueryItem(name: "redirect_to", value: configuration.callbackURL.absoluteString),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "s256")
        ]
        guard let url = components?.url else { throw UAPPAuthenticationError.invalidConfiguration }
        let callback = try await oauthPresenter(url, configuration.callbackURL)
        let code = try Self.callbackCode(callback, expected: configuration.callbackURL)
        let data = try await request(
            path: "token",
            body: ["auth_code": code, "code_verifier": verifier],
            query: [URLQueryItem(name: "grant_type", value: "pkce")]
        )
        let response = try await withProfile(decodeSession(data))
        guard capturedGeneration == generation else { throw UAPPAuthenticationError.cancelled }
        let session = try store(response, recovery: false)
        if method == .apple, let refreshToken = Self.providerRefreshToken(in: data) {
            await storeAppleRefreshToken(refreshToken, accessToken: response.accessToken)
        }
        return session
    }

    /// Refresh token da Apple devolvido pela troca do código. Não entra na sessão guardada no Keychain:
    /// só segue para o servidor, que o confere e guarda cifrado.
    static func providerRefreshToken(in data: Data) -> String? {
        struct ProviderTokens: Decodable {
            let providerRefreshToken: String?
            enum CodingKeys: String, CodingKey { case providerRefreshToken = "provider_refresh_token" }
        }
        let value = (try? JSONDecoder().decode(ProviderTokens.self, from: data))?.providerRefreshToken?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    /// Envia o refresh token da Apple à função `apple-signin-token` do UAPP, que o usa para revogar o acesso
    /// quando a conta for excluída, como a Apple exige. Melhor esforço: uma falha não impede o login.
    private func storeAppleRefreshToken(_ refreshToken: String, accessToken: String) async {
        var request = URLRequest(
            url: configuration.host.appendingPathComponent("functions/v1/apple-signin-token")
        )
        request.httpMethod = "POST"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refreshToken": refreshToken])
        _ = try? await transport.send(request)
    }

    public func signOut() async throws {
        try restoreSession()
        let token = storedSession?.accessToken
        // Clear local state first, including in-flight refresh/login, even if the network fails.
        try clear()
        if let token {
            _ = try await request(path: "logout", body: [:], accessToken: token, query: [URLQueryItem(name: "scope", value: "local")])
        }
    }

    /// Completa a sessão com o nome e a foto do perfil do UAPP (`profiles`), os mesmos do painel
    /// web. Melhor esforço: sem resposta, mantém o que a sessão anterior já tinha.
    private func withProfile(
        _ response: SessionResponse,
        previous: SessionResponse.User? = nil
    ) async -> SessionResponse {
        var metadata = response.user.metadata
        let nameKey = SessionResponse.User.profileNameKey
        let avatarKey = SessionResponse.User.profileAvatarKey
        if let profile = await fetchProfile(userId: response.user.id, accessToken: response.accessToken) {
            metadata[nameKey] = profile.displayName(for: response.user.email)
            metadata[avatarKey] = profile.avatarURL
        } else if previous?.id == response.user.id {
            metadata[nameKey] = previous?.metadata[nameKey]
            metadata[avatarKey] = previous?.metadata[avatarKey]
        }
        return SessionResponse(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresIn: response.expiresIn,
            user: SessionResponse.User(id: response.user.id, email: response.user.email, metadata: metadata)
        )
    }

    private func fetchProfile(userId: String, accessToken: String) async -> UAPPProfileRow? {
        guard !userId.isEmpty,
              var components = URLComponents(
                  url: configuration.host.appendingPathComponent("rest/v1/profiles"),
                  resolvingAgainstBaseURL: false
              )
        else { return nil }
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq." + userId),
            URLQueryItem(name: "select", value: "display_name,avatar_url")
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await transport.send(request),
              (200 ..< 300).contains(response.statusCode),
              let rows = try? JSONDecoder().decode([UAPPProfileRow].self, from: data)
        else { return nil }
        return rows.first ?? UAPPProfileRow(displayName: nil, avatarURL: nil)
    }

    /// Grava a foto escolhida no kit também no perfil do UAPP. Devolve se o perfil aceitou.
    private func saveProfileAvatar(_ avatarURL: URL, userId: String, accessToken: String) async -> Bool {
        guard var components = URLComponents(
            url: configuration.host.appendingPathComponent("rest/v1/profiles"),
            resolvingAgainstBaseURL: false
        ) else { return false }
        // A resposta traz só as colunas que o kit usa: o telefone do perfil não é legível.
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq." + userId),
            URLQueryItem(name: "select", value: "display_name,avatar_url")
        ]
        guard let url = components.url else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["avatar_url": avatarURL.absoluteString])
        guard let (data, response) = try? await transport.send(request),
              (200 ..< 300).contains(response.statusCode),
              let rows = try? JSONDecoder().decode([UAPPProfileRow].self, from: data)
        else { return false }
        return rows.contains { $0.avatarURL == avatarURL.absoluteString }
    }

    private func clear() throws {
        didRestoreSession = true
        isRecoverySession = false
        generation += 1
        storedSession = nil
        expiresAt = nil
        refreshTask?.cancel()
        refreshTask = nil
        try sessionStorage.remove()
    }

    private func store(_ response: SessionResponse, recovery: Bool? = nil) throws -> UAPPAuthenticationSession {
        let temporary = recovery ?? isRecoverySession
        let expiration = now().addingTimeInterval(response.expiresIn)
        if temporary {
            try sessionStorage.remove()
        } else {
            try sessionStorage.save(JSONEncoder().encode(PersistedSession(
                response: response, expiresAt: expiration, publishableKey: configuration.publishableKey
            )))
        }
        didRestoreSession = true
        isRecoverySession = temporary
        storedSession = response
        expiresAt = expiration
        return response.session
    }

    private func persistSession() throws {
        guard let storedSession, let expiresAt else { return }
        try sessionStorage.save(JSONEncoder().encode(PersistedSession(
            response: storedSession, expiresAt: expiresAt, publishableKey: configuration.publishableKey
        )))
    }

    private func restoreSession() throws {
        guard !didRestoreSession else { return }
        guard let data = try sessionStorage.read() else { didRestoreSession = true; return }
        guard let persisted = try? JSONDecoder().decode(PersistedSession.self, from: data),
              !persisted.response.accessToken.isEmpty, !persisted.response.refreshToken.isEmpty,
              !persisted.response.user.id.isEmpty, persisted.response.expiresIn > 0
        else {
            try sessionStorage.remove()
            didRestoreSession = true
            return
        }
        storedSession = persisted.response
        expiresAt = persisted.expiresAt
        didRestoreSession = true
    }

    static func savedPublishableKey(_ data: Data?) -> String? {
        guard let data,
              let persisted = try? JSONDecoder().decode(PersistedSession.self, from: data),
              !persisted.publishableKey.isEmpty, !persisted.publishableKey.hasPrefix("sb_secret_")
        else { return nil }
        return persisted.publishableKey
    }

    private func token(grant: String, body: [String: String]) async throws -> SessionResponse {
        let data = try await request(path: "token", body: body, query: [URLQueryItem(name: "grant_type", value: grant)])
        return try decodeSession(data)
    }

    private func decodeSession(_ data: Data) throws -> SessionResponse {
        let response = try JSONDecoder().decode(SessionResponse.self, from: data)
        guard !response.accessToken.isEmpty, !response.refreshToken.isEmpty,
              !response.user.id.isEmpty, response.expiresIn > 0
        else {
            throw UAPPKitError.invalidResponse
        }
        return response
    }

    private func authURL(path: String) -> URL {
        configuration.host.appendingPathComponent("auth/v1").appendingPathComponent(path)
    }

    private func validateConfiguration() throws {
        guard configuration.host.scheme == "https", configuration.host.host != nil,
              configuration.host.user == nil, configuration.host.password == nil,
              configuration.host.query == nil, configuration.host.fragment == nil,
              !configuration.publishableKey.isEmpty,
              !configuration.publishableKey.hasPrefix("sb_secret_"),
              let scheme = configuration.callbackURL.scheme, !["http", "https"].contains(scheme),
              configuration.callbackURL.user == nil, configuration.callbackURL.password == nil,
              configuration.callbackURL.port == nil,
              configuration.callbackURL.query == nil, configuration.callbackURL.fragment == nil
        else { throw UAPPAuthenticationError.invalidConfiguration }
    }

    private func request(
        path: String,
        body: [String: Any],
        accessToken: String? = nil,
        query: [URLQueryItem] = [],
        method: String = "POST"
    ) async throws -> Data {
        try validateConfiguration()
        var components = URLComponents(url: authURL(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = query.isEmpty ? nil : query
        guard let url = components?.url else { throw UAPPAuthenticationError.invalidConfiguration }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await transport.send(request)
        try UAPPClient.validate(response, data: data)
        return data
    }

    static func callbackCode(_ callback: URL, expected: URL) throws -> String {
        guard callback.scheme == expected.scheme, callback.host == expected.host,
              callback.user == nil, callback.password == nil, callback.port == expected.port,
              callback.path == expected.path,
              let components = URLComponents(url: callback, resolvingAgainstBaseURL: false)
        else { throw UAPPAuthenticationError.invalidCallback }
        let codes = (components.queryItems ?? []).filter { $0.name == "code" }
        guard !(components.queryItems ?? []).contains(where: { $0.name == "error" }),
              codes.count == 1, let code = codes.first?.value, !code.isEmpty
        else { throw UAPPAuthenticationError.invalidCallback }
        return code
    }
}

public extension UAPPAuthentication {
    /// Exclui a conta pela função `delete-account` do UAPP, a mesma do painel web: o servidor apaga
    /// a foto, revoga o "Iniciar sessão com a Apple", encerra as sessões e remove o usuário. Requisições
    /// e comentários publicados continuam, sem autor. Só depois da confirmação a sessão local é apagada.
    func deleteAccount() async throws -> UAPPAccountDeletion {
        guard let session = try await currentSession(), !isRecoverySession else {
            throw UAPPAuthenticationError.signInRequired
        }
        try validateConfiguration()
        var request = URLRequest(url: configuration.host.appendingPathComponent("functions/v1/delete-account"))
        request.httpMethod = "POST"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer " + session.accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        let (data, response) = try await transport.send(request)
        do {
            try UAPPClient.validate(response, data: data)
        } catch UAPPKitError.http(status: 409, let message) {
            throw message == "apple_subscription_active"
                ? UAPPAccountDeletionError.activeAppStoreSubscription
                : UAPPAccountDeletionError.organizationOwnershipTransferRequired
        }
        struct DeletionResponse: Decodable {
            let deleted: Bool
            let appleRevocation: String?
            enum CodingKeys: String, CodingKey { case deleted, appleRevocation }
        }
        guard let result = try? JSONDecoder().decode(DeletionResponse.self, from: data), result.deleted else {
            throw UAPPKitError.invalidResponse
        }
        // A conta já não existe: a sessão local sai mesmo que outra operação tenha mudado o estado.
        try clear()
        return UAPPAccountDeletion(
            requiresAppleAccessRemoval: result.appleRevocation == "failed" || result.appleRevocation == "unavailable"
        )
    }
}

private struct PersistedSession: Codable {
    let response: SessionResponse
    let expiresAt: Date
    let publishableKey: String
}

private struct SessionResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: TimeInterval
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token", refreshToken = "refresh_token", expiresIn = "expires_in", user
    }

    struct User: Codable, Sendable {
        /// Foto escolhida no kit. Provedores sociais podem sobrescrever `avatar_url` a cada login,
        /// mas não esta chave; assim a última foto definida pelo usuário prevalece.
        static let chosenAvatarKey = "uapp_avatar_url"
        /// Nome e foto do perfil do UAPP (`profiles`), guardados só na sessão local.
        static let profileNameKey = "uapp_profile_display_name"
        static let profileAvatarKey = "uapp_profile_avatar_url"
        let id: String
        let email: String?
        let metadata: [String: String]

        enum CodingKeys: String, CodingKey { case id, email, metadata = "user_metadata" }

        init(id: String, email: String?, metadata: [String: String]) {
            self.id = id
            self.email = email
            self.metadata = metadata
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decode(String.self, forKey: .id)
            email = try values.decodeIfPresent(String.self, forKey: .email)
            // Provider metadata may contain booleans/objects alongside profile strings.
            let object = try? values.nestedContainer(keyedBy: MetadataKey.self, forKey: .metadata)
            var metadata: [String: String] = [:]
            for key in object?.allKeys ?? [] {
                if let value = try? object?.decode(String.self, forKey: key) {
                    metadata[key.stringValue] = value
                }
            }
            self.metadata = metadata
        }
    }

    var session: UAPPAuthenticationSession {
        UAPPAuthenticationSession(
            identity: UAPPIdentity(
                userId: user.id, email: user.email,
                displayName: user.metadata["full_name"] ?? user.metadata["name"]
                    ?? user.metadata[User.profileNameKey],
                // Foto escolhida no kit, depois a do perfil do UAPP (a mesma do painel web) e, por
                // último, a do provedor social.
                avatarURL: (user.metadata[User.chosenAvatarKey] ?? user.metadata[User.profileAvatarKey]
                    ?? user.metadata["avatar_url"] ?? user.metadata["picture"])
                    .flatMap(URL.init(string:))
            ),
            accessToken: accessToken
        )
    }
}

private struct MetadataKey: CodingKey {
    let stringValue: String
    var intValue: Int? {
        nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue _: Int) {
        nil
    }
}

/// Linha de `profiles` que o próprio usuário pode ler e atualizar.
struct UAPPProfileRow: Decodable, Sendable {
    let displayName: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }

    /// O cadastro preenche o nome com a parte do e-mail antes do "@" quando a pessoa não informa
    /// um; esse valor não é um nome escolhido e fica de fora.
    func displayName(for email: String?) -> String? {
        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let emailPrefix = email?.split(separator: "@").first.map(String.init)
        guard !name.isEmpty, name != emailPrefix else { return nil }
        return name
    }
}
