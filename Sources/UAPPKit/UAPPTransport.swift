import Foundation

/// Abstração de transporte HTTP para permitir testes sem rede e trocar a
/// implementação no futuro (ex.: cliente REST nativo assinado no backend).
public protocol UAPPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Implementação padrão sobre `URLSession`.
public struct URLSessionTransport: UAPPTransport {
    private let session: URLSession
    private let timeoutInterval: TimeInterval

    /// Prazo máximo para receber a resposta completa, em segundos.
    /// Valores inválidos usam o padrão de 15 segundos.
    public init(session: URLSession = .shared, timeoutInterval: TimeInterval = 15) {
        self.session = session
        self.timeoutInterval = timeoutInterval.isFinite && timeoutInterval > 0 ? timeoutInterval : 15
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            var request = request
            request.timeoutInterval = timeoutInterval
            let (data, response) = try await withThrowingTaskGroup(
                of: (Data, URLResponse).self
            ) { group in
                group.addTask { [session, request] in
                    try await session.data(for: request)
                }
                group.addTask { [timeoutInterval] in
                    try await Task.sleep(for: .seconds(timeoutInterval))
                    throw URLError(.timedOut)
                }
                defer { group.cancelAll() }
                guard let response = try await group.next() else {
                    throw UAPPKitError.invalidResponse
                }
                return response
            }
            guard let http = response as? HTTPURLResponse else {
                throw UAPPKitError.invalidResponse
            }
            return (data, http)
        } catch let error as UAPPKitError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw UAPPKitError.transport("Tempo limite de comunicação com o UAPP excedido. Tente novamente.")
        } catch {
            throw UAPPKitError.transport(error.localizedDescription)
        }
    }
}
