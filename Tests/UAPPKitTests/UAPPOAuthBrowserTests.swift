import AuthenticationServices
import Foundation
import Testing
@testable import UAPPKit

/// Sessão falsa que responde ao iniciar, sem abrir o navegador do sistema.
private final class FakeWebSession: UAPPWebAuthenticationSession, @unchecked Sendable {
    weak var presentationContextProvider: (any ASWebAuthenticationPresentationContextProviding)?
    var startsSuccessfully = true
    var reply: (URL?, (any Error)?)?
    private let completion: @Sendable (URL?, (any Error)?) -> Void
    private(set) var cancelled = false

    init(completion: @escaping @Sendable (URL?, (any Error)?) -> Void) {
        self.completion = completion
    }

    func start() -> Bool {
        if let reply {
            completion(reply.0, reply.1)
        }
        return startsSuccessfully
    }

    func cancel() {
        cancelled = true
    }
}

@MainActor
struct UAPPOAuthBrowserTests {
    private let login = URL(string: "https://auth.example.test/authorize")!
    private let callback = URL(string: "uappkit-test://auth")!

    private func browser(
        reply: (URL?, (any Error)?)?, starts: Bool = true, created: ((FakeWebSession) -> Void)? = nil
    ) -> UAPPOAuthBrowser {
        UAPPOAuthBrowser { _, scheme, completion in
            #expect(scheme == "uappkit-test")
            let session = FakeWebSession(completion: completion)
            session.reply = reply
            session.startsSuccessfully = starts
            created?(session)
            return session
        }
    }

    @Test("Callback do sistema conclui o login com a URL recebida")
    func successReturnsCallback() async throws {
        let returned = try #require(URL(string: "uappkit-test://auth?code=123"))
        var provider: (any ASWebAuthenticationPresentationContextProviding)?
        let oauth = browser(reply: (returned, nil)) { provider = $0.presentationContextProvider }
        #expect(try await oauth.open(login, callback: callback) == returned)
        #expect(provider == nil || provider is UAPPOAuthBrowser)
    }

    @Test("Cancelamento, erro do sistema e falha ao iniciar viram erros de autenticação")
    func failuresMapToAuthenticationErrors() async {
        await #expect(throws: UAPPAuthenticationError.cancelled) {
            try await browser(reply: (nil, ASWebAuthenticationSessionError(.canceledLogin))).open(login, callback: callback)
        }
        await #expect(throws: UAPPAuthenticationError.invalidCallback) {
            try await browser(reply: (nil, TestError.expected)).open(login, callback: callback)
        }
        await #expect(throws: UAPPAuthenticationError.invalidConfiguration) {
            try await browser(reply: nil, starts: false).open(login, callback: callback)
        }
    }

    @Test("Cancelar a tarefa encerra a sessão do sistema")
    func taskCancellationCancelsSession() async {
        var session: FakeWebSession?
        let oauth = browser(reply: nil) { session = $0 }
        let task = Task { try await oauth.open(login, callback: callback) }
        while session == nil {
            await Task.yield()
        }
        task.cancel()
        await #expect(throws: UAPPAuthenticationError.cancelled) { try await task.value }
        #expect(session?.cancelled == true)
    }

    @Test("Mapeamento do retorno trata URL, cancelamento e ausência de callback")
    func resultMapping() throws {
        let url = try #require(URL(string: "uappkit-test://auth"))
        #expect(try UAPPOAuthBrowser.result(url: url, error: nil).get() == url)
        #expect(throws: UAPPAuthenticationError.invalidCallback) { try UAPPOAuthBrowser.result(url: nil, error: nil).get() }
    }

    @Test("Âncora de apresentação usa a janela ativa ou uma nova")
    func presentationAnchorExists() {
        let oauth = UAPPOAuthBrowser()
        let session = ASWebAuthenticationSession(url: login, callbackURLScheme: "uappkit-test") { _, _ in }
        _ = oauth.presentationAnchor(for: session)
    }
}
