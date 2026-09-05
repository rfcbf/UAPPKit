import Foundation

/// Abstração de transporte HTTP para permitir testes sem rede e trocar a
/// implementação no futuro (ex.: cliente REST nativo assinado no backend).
public protocol UAPPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Implementação padrão sobre `URLSession`.
public struct URLSessionTransport: UAPPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw UAPPKitError.invalidResponse
            }
            return (data, http)
        } catch let error as UAPPKitError {
            throw error
        } catch {
            throw UAPPKitError.transport(error.localizedDescription)
        }
    }
}
