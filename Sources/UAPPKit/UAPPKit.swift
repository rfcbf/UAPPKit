import Foundation

#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Ponto de entrada público do SDK.
///
/// ```swift
/// UAPPKit.setup(projectId: "meu-app")
/// UAPPKit.identify(userId: "user-123")
/// try await UAPPKit.showFeedback()
/// ```
///
/// A V1 apresenta telas SwiftUI **nativas** (nada de WebView). O contrato
/// público já está preparado para autenticação assinada no backend e para
/// telas cada vez mais ricas sem quebrar a API.
@MainActor
public enum UAPPKit {
    private static var client: UAPPClient?
    private static var configuration: UAPPConfiguration?

    // MARK: - Configuração

    public static func setup(
        projectId: String,
        host: URL = UAPPConfiguration.defaultHost,
        signatureProvider: UAPPSignatureProvider? = nil
    ) {
        let configuration = UAPPConfiguration(
            projectId: projectId,
            host: host,
            signatureProvider: signatureProvider
        )
        self.configuration = configuration
        self.client = UAPPClient(configuration: configuration)
    }

    public static func identify(
        userId: String,
        email: String? = nil,
        displayName: String? = nil,
        traits: [String: String] = [:]
    ) {
        let identity = UAPPIdentity(
            userId: userId,
            email: email,
            displayName: displayName,
            traits: traits
        )
        Task { await client?.setIdentity(identity) }
    }

    public static func reset() {
        Task { await client?.setIdentity(nil) }
    }

    /// Cliente de baixo nível para quem quiser montar a própria interface.
    public static func makeClient() throws -> UAPPClient {
        guard let client else { throw UAPPKitError.notConfigured }
        return client
    }

    static func requireClient() throws -> UAPPClient {
        guard let client else { throw UAPPKitError.notConfigured }
        return client
    }

    // MARK: - Apresentação das telas nativas

    #if canImport(UIKit) && canImport(SwiftUI)
    public static func showFeedback() throws {
        try present(UAPPFeedbackScreen(client: requireClient(), mode: .feedback))
    }

    public static func showRoadmap() throws {
        try present(UAPPFeedbackScreen(client: requireClient(), mode: .roadmap))
    }

    public static func showChangelog() throws {
        try present(UAPPFeedbackScreen(client: requireClient(), mode: .changelog))
    }

    private static func present<Content: View>(_ content: Content) {
        guard let presenter = Self.topViewController() else { return }
        let host = UIHostingController(rootView: NavigationStack { content })
        presenter.present(host, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
    #endif
}
