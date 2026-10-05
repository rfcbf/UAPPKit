import AuthenticationServices
import Foundation

/// Sessão de autenticação web do sistema; substituível nos testes.
protocol UAPPWebAuthenticationSession: AnyObject {
    var presentationContextProvider: (any ASWebAuthenticationPresentationContextProviding)? { get set }
    func start() -> Bool
    func cancel()
}

extension ASWebAuthenticationSession: UAPPWebAuthenticationSession {}

typealias UAPPWebAuthenticationSessionFactory = @MainActor (
    _ url: URL, _ callbackScheme: String?, _ completion: @escaping @Sendable (URL?, (any Error)?) -> Void
) -> any UAPPWebAuthenticationSession

/// Apresentação segura do sistema para OAuth, sem incorporar WebView ao app.
@MainActor
public final class UAPPOAuthBrowser: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: (any UAPPWebAuthenticationSession)?
    private var continuation: CheckedContinuation<URL, Error>?
    private let makeSession: UAPPWebAuthenticationSessionFactory

    init(makeSession: @escaping UAPPWebAuthenticationSessionFactory = { url, scheme, completion in
        ASWebAuthenticationSession(url: url, callbackURLScheme: scheme, completionHandler: completion)
    }) {
        self.makeSession = makeSession
    }

    public static func present(_ url: URL, callback: URL) async throws -> URL {
        let browser = UAPPOAuthBrowser()
        return try await browser.open(url, callback: callback)
    }

    func open(_ url: URL, callback: URL) async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let session = makeSession(url, callback.scheme) { url, error in
                    Task { @MainActor in
                        self.finish(Self.result(url: url, error: error))
                    }
                }
                self.session = session
                session.presentationContextProvider = self
                if !session.start() {
                    self.finish(.failure(UAPPAuthenticationError.invalidConfiguration))
                }
            }
        } onCancel: {
            Task { @MainActor in
                self.session?.cancel()
                self.finish(.failure(UAPPAuthenticationError.cancelled))
            }
        }
    }

    /// Converte o retorno do sistema em callback, cancelamento ou callback inválido.
    nonisolated static func result(url: URL?, error: (any Error)?) -> Result<URL, Error> {
        if let url {
            return .success(url)
        }
        if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
            return .failure(UAPPAuthenticationError.cancelled)
        }
        return .failure(UAPPAuthenticationError.invalidCallback)
    }

    private func finish(_ result: Result<URL, Error>) {
        let continuation = continuation
        self.continuation = nil
        session = nil
        continuation?.resume(with: result)
    }

    public func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        #else
        NSApplication.shared.keyWindow ?? ASPresentationAnchor()
        #endif
    }
}
