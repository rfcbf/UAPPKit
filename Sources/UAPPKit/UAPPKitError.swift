import Foundation

/// Erros expostos pelo SDK.
public enum UAPPKitError: Error, Equatable, Sendable {
    /// `UAPPKit.setup(projectId:)` ainda não foi chamado.
    case notConfigured
    /// A resposta HTTP não foi 2xx.
    case http(status: Int, message: String?)
    /// O corpo da resposta não pôde ser decodificado.
    case invalidResponse
    /// Falha de transporte (rede indisponível, timeout, etc.).
    case transport(String)
}

extension UAPPKitError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "UAPPKit não configurado. Chame UAPPKit.setup(projectId:) primeiro."
        case let .http(status, message):
            return "UAPP respondeu \(status)\(message.map { ": \($0)" } ?? "")."
        case .invalidResponse:
            return "Resposta do UAPP em formato inesperado."
        case let .transport(detail):
            return "Falha de comunicação com o UAPP: \(detail)."
        }
    }
}
