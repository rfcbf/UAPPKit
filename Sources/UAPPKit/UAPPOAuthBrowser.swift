import AuthenticationServices
import Foundation

/// Apresentação segura do sistema para OAuth, sem incorporar WebView ao app.
@MainActor
public final class UAPPOAuthBrowser: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<URL, Error>?

    public static func present(_ url: URL, callback: URL) async throws -> URL {
        let browser = UAPPOAuthBrowser()
        return try await browser.open(url, callback: callback)
    }

    private func open(_ url: URL, callback: URL) async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callback.scheme) { url, error in
                    Task { @MainActor in
                        if let url {
                            self.finish(.success(url))
                        } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                            self.finish(.failure(UAPPAuthenticationError.cancelled))
                        } else {
                            self.finish(.failure(UAPPAuthenticationError.invalidCallback))
                        }
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
