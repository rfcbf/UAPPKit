import Foundation
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@Test("login automático é preguiçoso, descobre configuração pública e compartilha a sessão")
func automaticAuthenticationLifecycle() async throws {
    let recorder = RequestRecorder()
    let host = try #require(URL(string: "https://login.example"))
    let auth = UAPPAutomaticAuthentication(
        configuration: UAPPConfiguration(projectId: "demo", host: host),
        transport: StubTransport { request in
            recorder.record(request)
            switch request.url?.path {
            case "/functions/v1/public-feedback":
                #expect(request.value(forHTTPHeaderField: "x-uapp-project") == "demo")
                #expect(request.url?.query?.contains("resource=authentication") == true)
                #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
                return response(request, body: #"{"publishableKey":"public-test-key"}"#)
            case "/auth/v1/otp":
                #expect(request.value(forHTTPHeaderField: "apikey") == "public-test-key")
                return response(request, body: "{}")
            case "/auth/v1/verify":
                return response(request, body: #"{"access_token":"access","refresh_token":"refresh","expires_in":3600,"user":{"id":"account","email":"visitor@example.test"}}"#)
            default:
                return response(request, body: "{}")
            }
        }
    )
    #expect(auth.methods == [.email])
    #expect(try await auth.currentSession() == nil)
    #expect(recorder.requests.isEmpty)
    try await auth.requestEmailCode(email: "visitor@example.test")
    let session = try await auth.verifyEmailCode(email: "visitor@example.test", code: "123456")
    #expect(session.identity.userId == "account")
    #expect(try await auth.currentSession() == session)
    #expect(recorder.requests.filter { $0.url?.path == "/functions/v1/public-feedback" }.count == 1)
    try await auth.signOut()
    #expect(try await auth.currentSession() == nil)
    await #expect(throws: UAPPAuthenticationError.unsupportedMethod) { try await auth.signIn(method: .apple) }
}

@Test("falha na descoberta não cria sessão nem dispara envio de código e permite tentar novamente")
func automaticAuthenticationDiscoveryFailure() async throws {
    let recorder = RequestRecorder()
    let auth = UAPPAutomaticAuthentication(
        configuration: UAPPConfiguration(projectId: "demo"),
        transport: StubTransport { request in
            recorder.record(request)
            return response(request, body: "{}", status: 503)
        }
    )
    for _ in 0 ..< 2 {
        await #expect(throws: UAPPKitError.self) { try await auth.requestEmailCode(email: "visitor@example.test") }
    }
    #expect(recorder.requests.count == 2)
    #expect(recorder.requests.allSatisfy { $0.url?.path.hasSuffix("public-feedback") == true })
    #expect(try await auth.currentSession() == nil)
}

@Test("configuração malformada e chave secreta não viram login automático")
func automaticAuthenticationInvalidSettings() async throws {
    for body in ["{}", #"{"publishableKey":"sb_secret_invalid"}"#] {
        let recorder = RequestRecorder()
        let auth = UAPPAutomaticAuthentication(
            configuration: UAPPConfiguration(projectId: "demo"),
            transport: StubTransport { request in
                recorder.record(request)
                return response(request, body: body)
            }
        )
        await #expect(throws: (any Error).self) { try await auth.requestEmailCode(email: "visitor@example.test") }
        #expect(recorder.requests.count == 1)
    }
}

private func response(_: URLRequest, body: String, status: Int = 200) -> (Int, Data) {
    (status, Data(body.utf8))
}

@Test("login automático exclui a conta com a chave descoberta e limpa a sessão")
func automaticAuthenticationDeletesAccount() async throws {
    let recorder = RequestRecorder()
    let host = try #require(URL(string: "https://login.example"))
    let auth = UAPPAutomaticAuthentication(
        configuration: UAPPConfiguration(projectId: "demo", host: host),
        transport: StubTransport { request in
            recorder.record(request)
            switch request.url?.path {
            case "/functions/v1/public-feedback":
                return response(request, body: #"{"publishableKey":"public-test-key"}"#)
            case "/auth/v1/verify":
                return response(request, body: #"{"access_token":"access","refresh_token":"refresh","expires_in":3600,"user":{"id":"account","email":"visitor@example.test"}}"#)
            case "/functions/v1/delete-account":
                #expect(request.value(forHTTPHeaderField: "apikey") == "public-test-key")
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access")
                return response(request, body: #"{"deleted":true,"appleRevocation":"not_needed"}"#)
            default:
                return response(request, body: "{}")
            }
        }
    )
    #expect(auth.supportsAccountDeletion)
    _ = try await auth.verifyEmailCode(email: "visitor@example.test", code: "123456")
    #expect(try await auth.deleteAccount() == UAPPAccountDeletion())
    #expect(try await auth.currentSession() == nil)
    #expect(recorder.requests.contains { $0.url?.path == "/functions/v1/delete-account" })
}
