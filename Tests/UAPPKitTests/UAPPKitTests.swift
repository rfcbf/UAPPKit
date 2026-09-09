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
            XCTAssertNotNil(request.value(forHTTPHeaderField: "x-uapp-installation-id"))
            let body = """
            {"ok":true,"project":{"slug":"meu-app"},"items":[
              {"id":"1","title":"Modo escuro","body":null,"vote_count":12,"like_count":4,"public_comment_count":3,"category":"feature","priority":80,"viewer_voted":true,"viewer_liked":false}
            ],"nextCursor":"cursor-2"}
            """
            return (200, Data(body.utf8))
        }

        let items = try await client.feedback()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.title, "Modo escuro")
        XCTAssertEqual(items.first?.voteCount, 12)
        XCTAssertEqual(items.first?.likeCount, 4)
        XCTAssertEqual(items.first?.commentCount, 3)
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
            XCTAssertNotNil(UUID(uuidString: payload["installationId"] as? String ?? ""))
            XCTAssertEqual(payload["category"] as? String, "feature")
            XCTAssertNotNil(request.value(forHTTPHeaderField: "idempotency-key"))
            return (201, Data(#"{"ok":true,"id":"fb-1"}"#.utf8))
        }
        await client.setIdentity(UAPPIdentity(userId: "user-123"))

        let id = try await client.submitFeedback(title: "Bug no login")
        XCTAssertEqual(id, "fb-1")
    }

    func testVoteUsesInteractionEndpointAndIdempotencyKey() async throws {
        let client = makeClient { request in
            XCTAssertTrue(request.url!.path.hasSuffix("/public-feedback-interact"))
            XCTAssertNotNil(request.value(forHTTPHeaderField: "idempotency-key"))
            let payload = try! JSONSerialization.jsonObject(
                with: request.httpBody ?? Data()
            ) as! [String: Any]
            XCTAssertEqual(payload["itemId"] as? String, "feedback-1")
            XCTAssertEqual(payload["action"] as? String, "vote")
            XCTAssertEqual(payload["enabled"] as? Bool, true)
            return (200, Data(#"{"ok":true,"enabled":true}"#.utf8))
        }

        try await client.setReaction(
            itemId: "feedback-1",
            kind: .vote,
            enabled: true
        )
    }

    func testCommentsDecodePublishedCommunityContent() async throws {
        let client = makeClient { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
                .queryItems ?? []
            XCTAssertTrue(query.contains(URLQueryItem(name: "resource", value: "comments")))
            XCTAssertTrue(query.contains(URLQueryItem(name: "itemId", value: "feedback-1")))
            let body = """
            {"ok":true,"comments":[
              {"id":"comment-1","body":"Também preciso","parentCommentId":null,"likeCount":2,"createdAt":"2026-09-07T12:00:00Z","authorKind":"community","viewerLiked":true}
            ],"nextCursor":null}
            """
            return (200, Data(body.utf8))
        }

        let page = try await client.comments(itemId: "feedback-1")
        XCTAssertEqual(page.comments.first?.likeCount, 2)
        XCTAssertEqual(page.comments.first?.authorKind, .community)
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
