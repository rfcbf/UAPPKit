import Foundation

/// Descobre a configuração pública do login somente na área de participação.
actor UAPPAutomaticAuthentication: UAPPAuthenticationProvider {
    nonisolated let methods: [UAPPLoginMethod]
    nonisolated let supportsProfilePhoto = true
    nonisolated let supportsAccountDeletion = true
    private let callbackURL: URL
    private let configuration: UAPPConfiguration
    private let transport: UAPPTransport
    private let sessionStorage: any UAPPSessionStorage
    private var provider: UAPPAuthentication?
    private var loading: Task<UAPPAuthentication, Error>?
    private var generation = 0

    init(
        configuration: UAPPConfiguration,
        transport: UAPPTransport = URLSessionTransport(),
        callbackURL: URL = UAPPAuthentication.defaultCallbackURL,
        methods: [UAPPLoginMethod] = [.email],
        sessionStorage: any UAPPSessionStorage = UAPPTransientSessionStorage()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.callbackURL = callbackURL
        self.methods = methods
        self.sessionStorage = sessionStorage
    }

    func currentSession() async throws -> UAPPAuthenticationSession? {
        if let provider {
            return try await provider.currentSession()
        }
        // Sem conta salva, a navegação pública continua sem consultar autenticação.
        guard try sessionStorage.read() != nil else { return nil }
        return try await resolve().currentSession()
    }

    func signIn(method: UAPPLoginMethod) async throws -> UAPPAuthenticationSession {
        guard method != .email, methods.contains(method) else { throw UAPPAuthenticationError.unsupportedMethod }
        return try await resolve().signIn(method: method)
    }

    func signIn(email: String, password: String) async throws -> UAPPAuthenticationSession {
        try await resolve().signIn(email: email, password: password)
    }

    func signUp(email: String, password: String, displayName: String?) async throws -> UAPPRegistrationResult {
        try await resolve().signUp(email: email, password: password, displayName: displayName)
    }

    func resendSignupCode(email: String) async throws {
        try await resolve().resendSignupCode(email: email)
    }

    func verifySignupCode(email: String, code: String) async throws -> UAPPAuthenticationSession {
        try await resolve().verifySignupCode(email: email, code: code)
    }

    func requestPasswordReset(email: String) async throws {
        try await resolve().requestPasswordReset(email: email)
    }

    func verifyPasswordResetCode(email: String, code: String) async throws {
        try await resolve().verifyPasswordResetCode(email: email, code: code)
    }

    func updatePassword(_ password: String) async throws -> UAPPAuthenticationSession {
        try await resolve().updatePassword(password)
    }

    func uploadProfilePhoto(_ data: Data) async throws -> UAPPAuthenticationSession {
        try await resolve().uploadProfilePhoto(data)
    }

    func requestEmailCode(email: String) async throws {
        try await resolve().requestEmailCode(email: email)
    }

    func verifyEmailCode(email: String, code: String) async throws -> UAPPAuthenticationSession {
        try await resolve().verifyEmailCode(email: email, code: code)
    }

    func signOut() async throws {
        generation += 1
        loading?.cancel()
        loading = nil
        if let provider {
            try await provider.signOut()
        } else {
            try sessionStorage.remove()
        }
    }

    func deleteAccount() async throws -> UAPPAccountDeletion {
        try await resolve().deleteAccount()
    }

    private func resolve() async throws -> UAPPAuthentication {
        if let provider {
            return provider
        }
        let capturedGeneration = generation
        let task: Task<UAPPAuthentication, Error>
        if let loading {
            task = loading
        } else {
            let savedKey = try UAPPAuthentication.savedPublishableKey(sessionStorage.read())
            task = Task {
                let publishableKey: String
                if let savedKey {
                    publishableKey = savedKey
                } else {
                    var components = URLComponents(
                        url: configuration.functionsBaseURL.appendingPathComponent("public-feedback"),
                        resolvingAgainstBaseURL: false
                    )
                    components?.queryItems = [
                        URLQueryItem(name: "slug", value: configuration.projectId),
                        URLQueryItem(name: "resource", value: "authentication")
                    ]
                    guard let url = components?.url else { throw UAPPAuthenticationError.invalidConfiguration }
                    var request = URLRequest(url: url)
                    request.setValue(configuration.projectId, forHTTPHeaderField: "x-uapp-project")
                    let (data, response) = try await transport.send(request)
                    try UAPPClient.validate(response, data: data)
                    let settings = try JSONDecoder().decode(Settings.self, from: data)
                    publishableKey = settings.publishableKey
                }
                return UAPPAuthentication(
                    configuration: UAPPAuthenticationConfiguration(
                        host: configuration.host, publishableKey: publishableKey,
                        callbackURL: callbackURL, methods: methods
                    ),
                    transport: transport,
                    oauthPresenter: UAPPOAuthBrowser.present,
                    now: Date.init,
                    sessionStorage: sessionStorage
                )
            }
            loading = task
        }
        do {
            let result = try await task.value
            guard capturedGeneration == generation else { throw UAPPAuthenticationError.cancelled }
            provider = result
            loading = nil
            return result
        } catch {
            if capturedGeneration == generation {
                loading = nil
            }
            throw error
        }
    }
}

private struct Settings: Decodable {
    let publishableKey: String

    enum CodingKeys: String, CodingKey { case publishableKey }
}
