import Foundation

public enum UAPPLoginMethod: String, Sendable, CaseIterable, Identifiable {
    case apple, google, github, email

    public var id: String {
        rawValue
    }
}

/// Sessão fornecida pela camada de autenticação. O backend valida o token em cada operação.
public struct UAPPAuthenticationSession: Sendable, Equatable {
    public let identity: UAPPIdentity
    public let accessToken: String

    public init(identity: UAPPIdentity, accessToken: String) {
        self.identity = identity
        self.accessToken = accessToken
    }
}

public enum UAPPAuthenticationError: Error, Sendable, Equatable {
    case signInRequired
    case unsupportedMethod
    case invalidConfiguration
    case invalidCallback
    case cancelled
}

public enum UAPPRegistrationResult: Sendable, Equatable {
    case signedIn(UAPPAuthenticationSession)
    case confirmationRequired
}

/// Adaptador da sessão do aplicativo ou do login próprio de participação.
/// Nenhum método é chamado pelo setup ou pelas telas Sobre/Reviews/Changelog.
public protocol UAPPAuthenticationProvider: Sendable {
    var methods: [UAPPLoginMethod] { get }
    var supportsProfilePhoto: Bool { get }
    func currentSession() async throws -> UAPPAuthenticationSession?
    func signIn(method: UAPPLoginMethod) async throws -> UAPPAuthenticationSession
    func signIn(email: String, password: String) async throws -> UAPPAuthenticationSession
    func signUp(email: String, password: String, displayName: String?) async throws -> UAPPRegistrationResult
    func resendSignupCode(email: String) async throws
    func verifySignupCode(email: String, code: String) async throws -> UAPPAuthenticationSession
    func requestPasswordReset(email: String) async throws
    func verifyPasswordResetCode(email: String, code: String) async throws
    func updatePassword(_ password: String) async throws -> UAPPAuthenticationSession
    func uploadProfilePhoto(_ data: Data) async throws -> UAPPAuthenticationSession
    func requestEmailCode(email: String) async throws
    func verifyEmailCode(email: String, code: String) async throws -> UAPPAuthenticationSession
    func signOut() async throws
}

public extension UAPPAuthenticationProvider {
    var supportsProfilePhoto: Bool { false }

    func uploadProfilePhoto(_: Data) async throws -> UAPPAuthenticationSession {
        throw UAPPAuthenticationError.unsupportedMethod
    }

    func signUp(email _: String, password _: String, displayName _: String?) async throws -> UAPPRegistrationResult {
        throw UAPPAuthenticationError.unsupportedMethod
    }

    func resendSignupCode(email _: String) async throws {
        throw UAPPAuthenticationError.unsupportedMethod
    }

    func verifySignupCode(email _: String, code _: String) async throws -> UAPPAuthenticationSession {
        throw UAPPAuthenticationError.unsupportedMethod
    }

    func requestPasswordReset(email _: String) async throws {
        throw UAPPAuthenticationError.unsupportedMethod
    }

    func verifyPasswordResetCode(email _: String, code _: String) async throws {
        throw UAPPAuthenticationError.unsupportedMethod
    }

    func updatePassword(_: String) async throws -> UAPPAuthenticationSession {
        throw UAPPAuthenticationError.unsupportedMethod
    }

    /// Implementação opcional, para preservar os provedores existentes.
    func signIn(email _: String, password _: String) async throws -> UAPPAuthenticationSession {
        throw UAPPAuthenticationError.unsupportedMethod
    }

    func requestEmailCode(email _: String) async throws {
        throw UAPPAuthenticationError.unsupportedMethod
    }

    func verifyEmailCode(email _: String, code _: String) async throws -> UAPPAuthenticationSession {
        throw UAPPAuthenticationError.unsupportedMethod
    }
}
