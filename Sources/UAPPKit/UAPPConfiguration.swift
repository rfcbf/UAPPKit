import Foundation

/// Assinatura opcional gerada pelo backend do integrador para autenticar um
/// usuário final. Fica pronta para o futuro; a V1 não a exige.
public typealias UAPPSignatureProvider = @Sendable () async throws -> String

/// Obtém um access token aceito pelo backend UAPP. O app controla login,
/// renovação e logout; `nil` representa uma sessão ausente.
public typealias UAPPAccessTokenProvider = @Sendable () async throws -> String?

/// Configuração imutável do SDK. Não carrega segredos: apenas o identificador
/// público do projeto e o host do UAPP.
public struct UAPPConfiguration: Sendable {
    /// Identificador público do projeto/aplicativo no UAPP (o `public_slug`).
    public let projectId: String

    /// Host base do UAPP: produção, exceto na variante interna.
    public let host: URL

    /// Fornecedor opcional de assinatura para identificar usuários finais de
    /// forma verificável. Quando `nil`, a identificação é apenas informativa.
    public let signatureProvider: UAPPSignatureProvider?

    /// Locale inicial usado para a interface e enviado ao serviço público.
    /// Quando `nil`, o UAPPKit usa a preferência do aplicativo/sistema.
    public let localeIdentifier: String?

    /// Configuração do projeto `projectId` no servidor de produção do UAPP.
    public init(
        projectId: String,
        signatureProvider: UAPPSignatureProvider? = nil,
        locale: Locale? = nil
    ) {
        self.init(
            projectId: projectId, host: UAPPConfiguration.defaultHost,
            signatureProvider: signatureProvider, locale: locale
        )
    }

    /// Variante interna para outro servidor do UAPP (ferramentas da equipe e testes).
    @_spi(UAPPInternal)
    public init(
        projectId: String,
        host: URL,
        signatureProvider: UAPPSignatureProvider? = nil,
        locale: Locale? = nil
    ) {
        self.projectId = projectId
        self.host = host
        localeIdentifier = locale?.identifier
        self.signatureProvider = signatureProvider
    }

    public static let defaultHost = URL(string: "https://qyjxwtvfmrkfcvisipke.supabase.co")!

    /// Endpoint das Edge Functions públicas derivado do host.
    var functionsBaseURL: URL {
        host.appendingPathComponent("functions/v1")
    }
}

/// Identidade opcional de um usuário final do aplicativo. É uma entidade
/// separada de qualquer conta no UAPP.
public struct UAPPIdentity: Sendable, Equatable, Codable {
    public var userId: String
    public var email: String?
    public var displayName: String?
    /// Foto do perfil informada pelo app, sem comprovar autenticação.
    public var avatarURL: URL?
    /// Foto local do perfil para envio ao cadastro do autor, sem depender de um arquivo.
    public var avatarData: Data?
    public var traits: [String: String]

    public init(
        userId: String,
        email: String? = nil,
        displayName: String? = nil,
        traits: [String: String] = [:],
        avatarURL: URL? = nil,
        avatarData: Data? = nil
    ) {
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.traits = traits
        self.avatarURL = avatarURL
        self.avatarData = avatarData
    }

    private enum CodingKeys: String, CodingKey {
        case userId, email, displayName, traits, avatarURL, avatarData
    }
}
