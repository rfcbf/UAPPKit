import Foundation
import Testing
@testable import UAPPKit

private final class FailingURLProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
    }

    override func stopLoading() {
        // A falha é entregue imediatamente em startLoading().
    }
}

private final class SuccessfulURLProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestURL = request.url,
              let response = HTTPURLResponse(
                  url: requestURL,
                  statusCode: 204,
                  httpVersion: nil,
                  headerFields: ["Content-Type": "application/json"]
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"ok":true}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // A resposta é entregue imediatamente em startLoading().
    }
}

private final class NonHTTPURLProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestURL = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let response = URLResponse(
            url: requestURL,
            mimeType: "text/plain",
            expectedContentLength: 0,
            textEncodingName: nil
        )
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // A resposta é entregue imediatamente em startLoading().
    }
}

private final class PendingURLProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        // Simula um servidor que nunca entrega a resposta, sem rede externa.
    }

    override func stopLoading() {}
}

private final class TimedOutURLProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
    }

    override func stopLoading() {}
}

private final class RequestTimeoutURLProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(String(request.timeoutInterval).utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeURLSessionTransport(protocolClass: AnyClass, timeoutInterval: TimeInterval = 15) -> URLSessionTransport {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [protocolClass]
    return URLSessionTransport(session: URLSession(configuration: configuration), timeoutInterval: timeoutInterval)
}

@Test("transporte interrompe servidor que não entrega uma resposta")
func urlSessionTransportEnforcesResponseDeadline() async throws {
    let transport = makeURLSessionTransport(protocolClass: PendingURLProtocol.self, timeoutInterval: 0.01)
    let request = try URLRequest(url: #require(URL(string: "https://example.test")))

    await #expect(throws: UAPPKitError.transport("Tempo limite de comunicação com o UAPP excedido. Tente novamente.")) {
        _ = try await transport.send(request)
    }
}

@Test("timeout da URLSession retorna mensagem compreensível")
func urlSessionTransportMapsTimeout() async throws {
    let transport = makeURLSessionTransport(protocolClass: TimedOutURLProtocol.self)
    let request = try URLRequest(url: #require(URL(string: "https://example.test")))

    await #expect(throws: UAPPKitError.transport("Tempo limite de comunicação com o UAPP excedido. Tente novamente.")) {
        _ = try await transport.send(request)
    }
}

@Test("transporte aplica prazo configurado e usa 15 segundos para valores inválidos")
func urlSessionTransportSetsRequestTimeout() async throws {
    let request = try URLRequest(url: #require(URL(string: "https://example.test")))
    let defaultTransport = makeURLSessionTransport(protocolClass: RequestTimeoutURLProtocol.self)
    let (defaultData, _) = try await defaultTransport.send(request)
    #expect(String(decoding: defaultData, as: UTF8.self) == "15.0")

    for interval in [3.0, 0, -1, .infinity, .nan] {
        let transport = makeURLSessionTransport(protocolClass: RequestTimeoutURLProtocol.self, timeoutInterval: interval)
        let (data, _) = try await transport.send(request)
        #expect(String(decoding: data, as: UTF8.self) == (interval == 3 ? "3.0" : "15.0"))
    }
}

@Test("validação aceita somente respostas 2xx e extrai mensagem")
func validationAcceptsOnlySuccessStatus() throws {
    let url = try #require(URL(string: "https://example.test"))
    let success = try #require(HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil))
    try UAPPClient.validate(success, data: Data())

    let failure = try #require(HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil))
    do {
        try UAPPClient.validate(failure, data: json(#"{"error":"Falhou"}"#))
        Issue.record("era esperado erro HTTP")
    } catch {
        #expect(error as? UAPPKitError == .http(status: 500, message: "Falhou"))
    }
}

@Test("transportador converte falhas de URLSession em erros do SDK")
func urlSessionTransportMapsFailures() async throws {
    let transport = makeURLSessionTransport(protocolClass: FailingURLProtocol.self)
    let request = try URLRequest(url: #require(URL(string: "https://example.test")))

    do {
        _ = try await transport.send(request)
        Issue.record("era esperada uma falha de transporte")
    } catch let error as UAPPKitError {
        if case .transport = error {
            #expect(true)
        } else {
            Issue.record("erro inesperado: \(error)")
        }
    } catch {
        Issue.record("erro não convertido: \(error)")
    }
}

@Test("transportador devolve dados e resposta HTTP válidos")
func urlSessionTransportReturnsHTTPResponse() async throws {
    let transport = makeURLSessionTransport(protocolClass: SuccessfulURLProtocol.self)
    let request = try URLRequest(url: #require(URL(string: "https://example.test")))

    let (data, response) = try await transport.send(request)

    #expect(response.statusCode == 204)
    #expect(data == Data(#"{"ok":true}"#.utf8))
}

@Test("transportador rejeita resposta que não é HTTP")
func urlSessionTransportRejectsNonHTTPResponse() async throws {
    let transport = makeURLSessionTransport(protocolClass: NonHTTPURLProtocol.self)
    let request = try URLRequest(url: #require(URL(string: "https://example.test")))

    do {
        _ = try await transport.send(request)
        Issue.record("era esperada uma resposta inválida")
    } catch {
        #expect(error as? UAPPKitError == .invalidResponse)
    }
}
