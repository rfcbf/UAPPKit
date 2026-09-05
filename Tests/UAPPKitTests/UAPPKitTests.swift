import XCTest
@testable import UAPPKit

/// Transporte falso: responde com JSON fixo por caminho de URL.
struct StubTransport: UAPPTransport {
    var handler: @Sendable (URLRequest) -> (Int, Data)

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (status, data) = handler(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}

final class UAPPConfigurationTests: XCTestCase {
    func testFunctionsBaseURLDerivesFromHost() {
        let config = UAPPConfiguration(
            projectId: "meu-app",
            host: URL(string: "https://exemplo.uapp.com")!
        )
        XCTAssertEqual(
            config.functionsBaseURL.absoluteString,
            "https://exemplo.uapp.com/functions/v1"
        )
    }

    func testIdentityEncodesTraits() throws {
        let identity = UAPPIdentity(
            userId: "u1",
            email: "u1@example.test",
            traits: ["plan": "pro"]
        )
        let data = try JSONEncoder().encode(identity)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(json["userId"] as? String, "u1")
        XCTAssertEqual((json["traits"] as? [String: String])?["plan"], "pro")
    }
}

final class UAPPClientTests: XCTestCase {
    private func makeClient(
        handler: @escaping @Sendable (URLRequest) -> (Int, Data)
    ) -> UAPPClient {
        let config = UAPPConfiguration(
            projectId: "meu-app",
            host: URL(string: "https://exemplo.uapp.com")!
        )
        return UAPPClient(
            configuration: config,
            transport: StubTransport(handler: handler)
        )
    }

    func testFeedbackBuildsQueryAndDecodes() async throws {
        let client = makeClient { request in
            let url = request.url!
            XCTAssertTrue(url.path.hasSuffix("/functions/v1/public-feedback"))
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                .queryItems ?? []
            XCTAssertTrue(query.contains(URLQueryItem(name: "slug", value: "meu-app")))
            XCTAssertTrue(query.contains(URLQueryItem(name: "resource", value: "feedback")))
            let body = """
            {"ok":true,"project":{"slug":"meu-app"},"items":[
              {"id":"1","title":"Modo escuro","body":null,"vote_count":12,"comment_count":3}
            ]}
            """
            return (200, Data(body.utf8))
        }

        let items = try await client.feedback()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.title, "Modo escuro")
        XCTAssertEqual(items.first?.voteCount, 12)
    }

    func testHTTPErrorSurfacesMessage() async {
        let client = makeClient { _ in
            (403, Data(#"{"error":"Conteúdo não público."}"#.utf8))
        }
        do {
            _ = try await client.feedback()
            XCTFail("esperava erro")
        } catch let UAPPKitError.http(status, message) {
            XCTAssertEqual(status, 403)
            XCTAssertEqual(message, "Conteúdo não público.")
        } catch {
            XCTFail("erro inesperado: \(error)")
        }
    }

    func testSubmitFeedbackSendsIdentityAndProjectHeader() async throws {
        let client = makeClient { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "x-uapp-project"),
                "meu-app"
            )
            let payload = try! JSONSerialization.jsonObject(
                with: request.httpBody ?? Data()
            ) as! [String: Any]
            XCTAssertEqual(payload["slug"] as? String, "meu-app")
            XCTAssertEqual(payload["title"] as? String, "Bug no login")
            XCTAssertEqual(payload["externalId"] as? String, "user-123")
            return (201, Data(#"{"ok":true,"id":"fb-1"}"#.utf8))
        }
        await client.setIdentity(UAPPIdentity(userId: "user-123"))

        let id = try await client.submitFeedback(title: "Bug no login")
        XCTAssertEqual(id, "fb-1")
    }

    func testInvalidBodyThrowsInvalidResponse() async {
        let client = makeClient { _ in (200, Data("not json".utf8)) }
        do {
            _ = try await client.changelog()
            XCTFail("esperava erro")
        } catch UAPPKitError.invalidResponse {
            // esperado
        } catch {
            XCTFail("erro inesperado: \(error)")
        }
    }
}
