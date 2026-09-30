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

private func makeURLSessionTransport(protocolClass: AnyClass) -> URLSessionTransport {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [protocolClass]
    return URLSessionTransport(session: URLSession(configuration: configuration))
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
