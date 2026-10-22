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
    /// Versão do pacote, igual à tag publicada e ao primeiro título de versão do `CHANGELOG.md`.
    /// Um pacote Swift não expõe a própria tag em tempo de execução; por isso o valor é mantido aqui
    /// e atualizado junto com o `CHANGELOG.md` a cada versão.
    public nonisolated static let version = "2.4.0"

    private static var client: UAPPClient?
    private static var configuration: UAPPConfiguration?
    private static var participationClient: UAPPClient?
    private static var participationIdentity: UAPPIdentity?
    private static var theme: UAPPTheme = .system
    private static var hostLocaleIdentifier = UAPPLocalizationPreferences.defaultIdentifier
    /// Transporte e abertura de links substituíveis nos testes, sem rede nem apps externos.
    static var makeTransport: @MainActor () -> any UAPPTransport = { URLSessionTransport() }
    static var urlOpener: UAPPURLOpener = uappSystemOpenURL

    // MARK: - Configuração

    /// Configura o kit para o projeto `projectId` no servidor de produção do UAPP.
    public static func setup(
        projectId: String,
        theme: UAPPTheme = .system,
        signatureProvider: UAPPSignatureProvider? = nil,
        locale: Locale? = nil
    ) {
        setup(
            projectId: projectId,
            host: UAPPConfiguration.defaultHost,
            theme: theme,
            signatureProvider: signatureProvider,
            locale: locale
        )
    }

    /// Variante interna para outro servidor do UAPP, usada pelas ferramentas da equipe, pelos
    /// testes e pelos dados fictícios do Demo. Aplicativos publicados usam sempre produção.
    @_spi(UAPPInternal)
    public static func setup(
        projectId: String,
        host: URL,
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
        if self.configuration?.projectId != projectId || self.configuration?.host != host {
            participationClient = nil
            participationIdentity = nil
        }
        self.configuration = configuration
        self.theme = theme
        client = UAPPClient(configuration: configuration, transport: makeTransport())
        Task { [participationClient] in
            await participationClient?.setLocale(Locale(identifier: localeIdentifier))
        }
    }

    /// Atualiza o idioma principal informado pelo aplicativo hospedeiro.
    /// As próximas apresentações usam essa escolha como idioma inicial.
    public static func setLocale(_ locale: Locale) {
        let identifier = UAPPLocalizationPreferences.select(identifier: locale.identifier)
        hostLocaleIdentifier = identifier
        Task { [client, participationClient] in
            await client?.setLocale(Locale(identifier: identifier))
            await participationClient?.setLocale(Locale(identifier: identifier))
        }
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
        traits: [String: String] = [:],
        avatarURL: URL? = nil
    ) {
        let identity = UAPPIdentity(
            userId: userId,
            email: email,
            displayName: displayName,
            traits: traits,
            avatarURL: avatarURL
        )
        participationIdentity = identity
        Task { [client, participationClient] in
            await client?.setIdentity(identity)
            await participationClient?.setIdentity(identity)
        }
    }

    public static func reset() {
        participationIdentity = nil
        Task { [client, participationClient] in
            await client?.setIdentity(nil)
            await participationClient?.setIdentity(nil)
        }
    }

    /// Cliente de baixo nível para quem quiser montar a própria interface.
    public static func makeClient() throws -> UAPPClient {
        guard let client else { throw UAPPKitError.notConfigured }
        return client
    }

    /// Cliente com login automático por e-mail, para Feedback/Roadmap em navegação própria.
    /// Não solicita login nem acessa autenticação durante o setup.
    public static func makeParticipationClient() throws -> UAPPClient {
        if let participationClient {
            return participationClient
        }
        guard let configuration else { throw UAPPKitError.notConfigured }
        let client = UAPPClient(
            configuration: configuration,
            transport: makeTransport(),
            authentication: UAPPAutomaticAuthentication(
                configuration: configuration,
                transport: makeTransport(),
                sessionStorage: UAPPKeychainSessionStorage(account: UAPPKeychainSessionStorage.account(
                    host: configuration.host, projectId: configuration.projectId
                ))
            )
        )
        participationClient = client
        let identity = participationIdentity
        Task { await client.setIdentity(identity) }
        return client
    }

    /// Cliente isolado de Feedback/Roadmap, criado depois do setup e do login.
    /// O perfil é opcional e não representa comprovação de autenticação.
    public static func makeClient(
        identity: UAPPIdentity? = nil,
        accessTokenProvider: UAPPAccessTokenProvider?
    ) async throws -> UAPPClient {
        try await requireClient().withAuthentication(
            identity: identity, accessTokenProvider: accessTokenProvider
        )
    }

    public static func makeClient(
        identity: UAPPIdentity? = nil,
        authentication: any UAPPAuthenticationProvider
    ) async throws -> UAPPClient {
        try await requireClient().withAuthentication(identity: identity, provider: authentication)
    }

    static func requireClient() throws -> UAPPClient {
        guard let client else { throw UAPPKitError.notConfigured }
        return client
    }

    // MARK: - Apresentação das telas nativas

    /// Cria o provedor reutilizável da conta do app sem iniciar login no setup.
    public static func makeAuthentication(
        callbackURL: URL = UAPPAuthentication.defaultCallbackURL,
        methods: [UAPPLoginMethod] = UAPPLoginMethod.allCases
    ) throws -> any UAPPAuthenticationProvider {
        guard let configuration else { throw UAPPKitError.notConfigured }
        return UAPPAuthentication.automatic(configuration: configuration, callbackURL: callbackURL, methods: methods)
    }

    #if canImport(SwiftUI) && (canImport(UIKit) || os(macOS))
    #if canImport(UIKit) && DEBUG
    @MainActor
    static var presenterProvider: () -> UIViewController? = {
        topViewController()
    }
    #endif

    #if os(macOS)
    /// Janelas abertas pelo pacote no Mac; substituível nos testes.
    static var windowPresenter = UAPPMacWindowPresenter()
    #endif

    /// No iPhone e no iPad, apresenta em uma sheet grande. No Mac, abre em uma janela própria,
    /// trazida para a frente se já estiver aberta.
    public static func showFeedback() throws {
        try present(UAPPFeedbackScreen(client: makeParticipationClient(), mode: .feedback), screen: .feedback)
    }

    /// Abre as informações da conta já conectada no aplicativo.
    public static func showUser(
        session: UAPPAuthenticationSession,
        authentication: any UAPPAuthenticationProvider,
        onSessionChange: @escaping @MainActor (UAPPAuthenticationSession?) -> Void = { _ in }
    ) throws {
        try present(UAPPUserScreen(
            session: session, authentication: authentication, client: requireClient(), theme: theme,
            onSessionChange: onSessionChange
        ), screen: .user)
    }

    /// Abre login/cadastro/recuperação com a identidade visual do aplicativo.
    public static func showAuthentication(
        authentication: any UAPPAuthenticationProvider,
        onSessionChange: @escaping @MainActor (UAPPAuthenticationSession?) -> Void = { _ in }
    ) throws {
        try present(UAPPAccountScreen(
            authentication: authentication, client: requireClient(), theme: theme,
            onSessionChange: onSessionChange
        ), screen: .account)
    }

    public static func showFeedback(
        identity: UAPPIdentity? = nil,
        authentication: any UAPPAuthenticationProvider
    ) async throws {
        let client = try await makeClient(identity: identity, authentication: authentication)
        present(UAPPFeedbackScreen(client: client, mode: .feedback), screen: .feedback)
    }

    public static func showFeedback(
        identity: UAPPIdentity? = nil,
        accessTokenProvider: UAPPAccessTokenProvider?
    ) async throws {
        let client = try await makeClient(identity: identity, accessTokenProvider: accessTokenProvider)
        present(UAPPFeedbackScreen(client: client, mode: .feedback), screen: .feedback)
    }

    public static func showRoadmap() throws {
        try present(UAPPRoadmapScreen(client: makeParticipationClient()), screen: .roadmap)
    }

    public static func showRoadmap(
        identity: UAPPIdentity? = nil,
        authentication: any UAPPAuthenticationProvider
    ) async throws {
        let client = try await makeClient(identity: identity, authentication: authentication)
        present(UAPPRoadmapScreen(client: client), screen: .roadmap)
    }

    public static func showRoadmap(
        identity: UAPPIdentity? = nil,
        accessTokenProvider: UAPPAccessTokenProvider?
    ) async throws {
        let client = try await makeClient(identity: identity, accessTokenProvider: accessTokenProvider)
        present(UAPPRoadmapScreen(client: client), screen: .roadmap)
    }

    public static func showChangelog() throws {
        try showChangelog(configuration: .init())
    }

    public static func showChangelog(configuration: UAPPChangelogConfiguration) throws {
        try present(UAPPFeedbackScreen(
            client: requireClient(), mode: .changelog, changelogConfiguration: configuration
        ), screen: .changelog)
    }

    /// Apresenta avaliações com páginas de 1 a 50 itens (valores fora da faixa são ajustados).
    public static func showReviews(pageSize: Int) throws {
        try present(UAPPReviewsScreen(client: requireClient(), pageSize: pageSize), screen: .reviews)
    }

    public static func showAbout(
        configuration: UAPPAboutConfiguration = .init()
    ) throws {
        let client = try requireClient()
        present(UAPPAboutScreen(configuration: configuration, client: client), screen: .about)
    }

    public static func showDeveloperAbout() throws {
        try present(UAPPDeveloperAboutScreen(client: requireClient()), screen: .developerAbout)
    }

    #if os(macOS)
    private static func present(_ content: some View, screen: UAPPPresentedScreen) {
        presentWindow(content, screen: screen)
    }

    /// Abre uma tela do pacote na janela própria dela. `onClose` roda quando a janela fecha.
    static func presentWindow(
        _ content: some View,
        screen: UAPPPresentedScreen,
        onClose: (@MainActor () -> Void)? = nil
    ) {
        windowPresenter.present(screen, content: UAPPKitPresentationRoot(
            content: content,
            theme: theme,
            initialLanguage: hostLocaleIdentifier,
            wrapsInNavigationStack: screen.wrapsInNavigationStack
        ), onClose: onClose)
    }
    #else
    private static func present(_ content: some View, screen _: UAPPPresentedScreen) {
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
    #endif

    /// Busca o app definido em `setup(projectId:)` e abre sua tela de avaliação
    /// na App Store.
    public static func openAppStoreReview() async throws {
        let client = try requireClient()
        guard let destination = try await client.appStoreReviewDestination() else {
            throw UAPPKitError.appStoreURLUnavailable
        }
        guard await uappOpenExternalURLAndReportSuccess(destination, opener: urlOpener) else {
            throw UAPPKitError.appStoreURLCouldNotOpen
        }
    }
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

    private let wrapsInNavigationStack: Bool

    init(content: Content, theme: UAPPTheme, initialLanguage: String, wrapsInNavigationStack: Bool = true) {
        self.content = content
        self.theme = theme
        self.wrapsInNavigationStack = wrapsInNavigationStack
        let resolvedLanguage = UAPPLocalizationPreferences.preparePresentation(
            initialIdentifier: initialLanguage
        )
        _selectedLanguage = AppStorage(
            wrappedValue: resolvedLanguage,
            UAPPLocalizationPreferences.presentationStorageKey
        )
    }

    var body: some View {
        navigationContent
            .environment(\.uappTheme, theme)
            .environment(\.locale, Locale(identifier: selectedLanguage))
            .background { UAPPThemePresentationBackground() }
    }

    /// Feedback e Roadmap no Mac já trazem a divisão lista/detalhe e não entram em uma pilha.
    @ViewBuilder private var navigationContent: some View {
        if wrapsInNavigationStack {
            NavigationStack { content }
        } else {
            content
        }
    }
}
#endif
