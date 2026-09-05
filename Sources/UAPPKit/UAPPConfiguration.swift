import Foundation

/// Assinatura opcional gerada pelo backend do integrador para autenticar um
/// usuário final. Fica pronta para o futuro; a V1 não a exige.
public typealias UAPPSignatureProvider = @Sendable () async throws -> String

/// Configuração imutável do SDK. Não carrega segredos: apenas o identificador
/// público do projeto e o host do UAPP.
public struct UAPPConfiguration: Sendable {
    /// Identificador público do projeto/aplicativo no UAPP (o `public_slug`).
    public let projectId: String

    /// Host base do UAPP. Default: produção.
    public let host: URL

    /// Fornecedor opcional de assinatura para identificar usuários finais de
    /// forma verificável. Quando `nil`, a identificação é apenas informativa.
    public let signatureProvider: UAPPSignatureProvider?

    public init(
        projectId: String,
        host: URL = UAPPConfiguration.defaultHost,
        signatureProvider: UAPPSignatureProvider? = nil
    ) {
        self.projectId = projectId
        self.host = host
        self.signatureProvider = signatureProvider
    }

    public static let defaultHost = URL(string: "https://app.uapp.com")!

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
    public var traits: [String: String]

    public init(
        userId: String,
        email: String? = nil,
        displayName: String? = nil,
        traits: [String: String] = [:]
    ) {
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.traits = traits
    }
}
