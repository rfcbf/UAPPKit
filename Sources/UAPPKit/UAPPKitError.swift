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
    /// O projeto configurado ainda não possui um destino de avaliação na App Store.
    case appStoreURLUnavailable
    /// O sistema não conseguiu abrir o destino da App Store.
    case appStoreURLCouldNotOpen
}

extension UAPPKitError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            "UAPPKit não configurado. Chame UAPPKit.setup(projectId:) primeiro."
        case let .http(status, message):
            "UAPP respondeu \(status)\(message.map { ": \($0)" } ?? "")."
        case .invalidResponse:
            "Resposta do UAPP em formato inesperado."
        case let .transport(detail):
            "Falha de comunicação com o UAPP: \(detail)."
        case .appStoreURLUnavailable:
            "O projeto configurado ainda não possui um link de avaliação na App Store."
        case .appStoreURLCouldNotOpen:
            "Não foi possível abrir a App Store neste dispositivo."
        }
    }
}
