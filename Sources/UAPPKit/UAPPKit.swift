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
/// try UAPPKit.showReviews(pageSize: 20)
/// ```
///
/// A V1 apresenta telas SwiftUI **nativas** (nada de WebView). O contrato
/// público já está preparado para autenticação assinada no backend e para
/// telas cada vez mais ricas sem quebrar a API.
@MainActor
public enum UAPPKit {
    private static var client: UAPPClient?
    private static var configuration: UAPPConfiguration?
    private static var theme: UAPPTheme = .system
    private static var hostLocaleIdentifier = UAPPLocalizationPreferences.defaultIdentifier

    // MARK: - Configuração

    public static func setup(
        projectId: String,
        host: URL = UAPPConfiguration.defaultHost,
        theme: UAPPTheme = .system,
        signatureProvider: UAPPSignatureProvider? = nil,
        locale: Locale? = nil
    ) {
        let localeIdentifier = UAPPLocalizationPreferences.ensureStored(
            initialIdentifier: locale?.identifier
        )
        hostLocaleIdentifier = localeIdentifier
        let configuration = UAPPConfiguration(
            projectId: projectId,
            host: host,
            signatureProvider: signatureProvider,
            locale: Locale(identifier: localeIdentifier)
        )
        self.configuration = configuration
        self.theme = theme
        client = UAPPClient(configuration: configuration)
    }

    /// Atualiza o idioma principal informado pelo aplicativo hospedeiro.
    /// As próximas apresentações usam essa escolha como idioma inicial.
    public static func setLocale(_ locale: Locale) {
        let identifier = UAPPLocalizationPreferences.select(identifier: locale.identifier)
        hostLocaleIdentifier = identifier
        Task { await client?.setLocale(Locale(identifier: identifier)) }
    }

    /// Chave de `UserDefaults` que o aplicativo hospedeiro pode usar para
    /// persistir o idioma principal dele.
    public static var localePreferenceKey: String {
        UAPPLocalizationPreferences.storageKey
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
    #if DEBUG
    @MainActor
    static var presenterProvider: () -> UIViewController? = {
        topViewController()
    }
    #endif

    public static func showFeedback() throws {
        try present(UAPPFeedbackScreen(client: requireClient(), mode: .feedback))
    }

    public static func showRoadmap() throws {
        try present(UAPPFeedbackScreen(client: requireClient(), mode: .roadmap))
    }

    public static func showChangelog() throws {
        try showChangelog(configuration: .init())
    }

    public static func showChangelog(configuration: UAPPChangelogConfiguration) throws {
        try present(UAPPFeedbackScreen(
            client: requireClient(), mode: .changelog, changelogConfiguration: configuration
        ))
    }

    /// Apresenta avaliações com páginas de 1 a 50 itens (valores fora da faixa são ajustados).
    public static func showReviews(pageSize: Int) throws {
        try present(UAPPReviewsScreen(client: requireClient(), pageSize: pageSize))
    }

    public static func showAbout(
        configuration: UAPPAboutConfiguration = .init()
    ) throws {
        let client = try requireClient()
        present(UAPPAboutScreen(configuration: configuration, client: client))
    }

    /// Busca o app definido em `setup(projectId:)` e abre sua tela de avaliação
    /// na App Store.
    public static func openAppStoreReview() async throws {
        let client = try requireClient()
        guard let destination = try await client.appStoreReviewDestination() else {
            throw UAPPKitError.appStoreURLUnavailable
        }
        guard await uappOpenExternalURLAndReportSuccess(destination) else {
            throw UAPPKitError.appStoreURLCouldNotOpen
        }
    }

    public static func showDeveloperAbout() throws {
        try present(UAPPDeveloperAboutScreen(client: requireClient()))
    }

    private static func present(_ content: some View) {
        #if DEBUG
        let presenter = presenterProvider()
        #else
        let presenter = topViewController()
        #endif
        guard let presenter else { return }
        let rootView = UAPPKitPresentationRoot(
            content: content,
            theme: theme,
            initialLanguage: hostLocaleIdentifier
        )
        let host = UIHostingController(rootView: rootView)
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.selectedDetentIdentifier = .large
            sheet.prefersGrabberVisible = false
        }
        host.view.backgroundColor = UIColor { traits in
            let colorScheme: ColorScheme = traits.userInterfaceStyle == .dark ? .dark : .light
            return UIColor(theme.resolved(for: colorScheme).background)
        }
        presenter.present(host, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
        let window = windows.first(where: \.isKeyWindow)
            ?? windows.first {
                $0.windowLevel == .normal && !$0.isHidden && $0.rootViewController != nil
            }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
    #endif
}

#if canImport(SwiftUI)
struct UAPPThemePresentationBackground: View {
    @Environment(\.uappTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        theme.resolved(for: colorScheme).background
            .ignoresSafeArea()
    }
}

struct UAPPKitPresentationRoot<Content: View>: View {
    private let content: Content
    private let theme: UAPPTheme
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier

    init(content: Content, theme: UAPPTheme, initialLanguage: String) {
        self.content = content
        self.theme = theme
        let resolvedLanguage = UAPPLocalizationPreferences.preparePresentation(
            initialIdentifier: initialLanguage
        )
        _selectedLanguage = AppStorage(
            wrappedValue: resolvedLanguage,
            UAPPLocalizationPreferences.presentationStorageKey
        )
    }

    var body: some View {
        NavigationStack { content }
            .environment(\.uappTheme, theme)
            .environment(\.locale, Locale(identifier: selectedLanguage))
            .background { UAPPThemePresentationBackground() }
    }
}
#endif
