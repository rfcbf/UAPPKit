#if canImport(SwiftUI)
import SwiftUI

/// Tela Sobre do aplicativo hospedeiro.
///
/// O ícone, o nome e a versão são descobertos automaticamente. O conteúdo
/// institucional é fornecido por `UAPPAboutConfiguration`.
public struct UAPPAboutScreen: View {
    private let configuration: UAPPAboutConfiguration
    private let appMetadata: UAPPAppMetadata
    private let client: UAPPClient?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier
    @State private var appStoreReviewURL: URL?
    @State private var remoteIconURL: URL?
    @State private var isLoadingAboutContent: Bool
    @State private var isRemoteIconReady: Bool
    @State private var isChangelogPresented = false
    @State private var isOpeningAppStoreReview = false
    @State private var appStoreReviewError: String?

    public init(configuration: UAPPAboutConfiguration = .init()) {
        self.configuration = configuration
        appMetadata = UAPPAppMetadata()
        client = nil
        _appStoreReviewURL = State(initialValue: nil)
        _remoteIconURL = State(initialValue: nil)
        _isLoadingAboutContent = State(initialValue: false)
        _isRemoteIconReady = State(initialValue: true)
    }

    init(configuration: UAPPAboutConfiguration, client: UAPPClient) {
        self.configuration = configuration
        appMetadata = UAPPAppMetadata()
        self.client = client
        _appStoreReviewURL = State(initialValue: nil)
        _remoteIconURL = State(initialValue: nil)
        _isLoadingAboutContent = State(initialValue: true)
        _isRemoteIconReady = State(initialValue: false)
    }

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    var changelogScreen: UAPPFeedbackScreen? {
        client.map {
            UAPPFeedbackScreen(
                client: $0, mode: .changelog,
                changelogConfiguration: configuration.changelogConfiguration
            )
        }
    }

    public var body: some View {
        Group {
            if isLoadingAboutContent || !isRemoteIconReady {
                loadingView
            } else {
                aboutContent
            }
        }
        .background(palette.background.ignoresSafeArea())
        .foregroundStyle(palette.primaryText)
        .id(selectedLanguage)
        .task {
            await loadAboutContent()
        }
        .sheet(isPresented: $isChangelogPresented) {
            if let changelogScreen {
                NavigationStack {
                    changelogScreen
                }
                .environment(\.uappTheme, theme)
                .environment(\.locale, Locale(identifier: selectedLanguage))
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
        .alert(
            Text(verbatim: uappLocalized("about.rate_app")),
            isPresented: Binding(
                get: { appStoreReviewError != nil },
                set: {
                    if !$0 {
                        appStoreReviewError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) { appStoreReviewError = nil }
        } message: {
            Text(verbatim: appStoreReviewError ?? "")
        }
        .uappNavigationBar(
            titleKey: "screen.about",
            accentColor: palette.accent ?? .accentColor
        )
    }

    private var aboutContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                UAPPAboutAppIdentity(
                    metadata: appMetadata,
                    configuration: configuration,
                    presentationLanguageIdentifier: selectedLanguage,
                    palette: palette,
                    remoteIconURL: remoteIconURL
                )
                UAPPAboutResources(
                    configuration: configuration,
                    palette: palette,
                    isOpeningAppStoreReview: isOpeningAppStoreReview,
                    onOpenAppStoreReview: client.map { _ in
                        { openAppStoreReview() }
                    },
                    onOpenChangelog: client.map { _ in
                        { isChangelogPresented = true }
                    }
                )
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, minHeight: 300, alignment: .top)
        }
    }

    private var loadingView: some View {
        VStack {
            // Sem o círculo claro do placeholder de imagem: só o indicador, na cor de destaque.
            ProgressView()
                .tint(palette.accent ?? .accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background.ignoresSafeArea())
    }

    private func loadAboutContent() async {
        guard let client else {
            isLoadingAboutContent = false
            isRemoteIconReady = true
            return
        }

        do {
            let about = try await client.about()
            let project = await client.currentProject()
            let iconURL = project?.iconURL ?? matchingAboutAppIconURL(
                in: about,
                project: project
            )
            remoteIconURL = iconURL

            if let iconURL {
                await preloadRemoteIcon(iconURL)
            } else {
                isRemoteIconReady = true
            }

            if configuration.showsAppStoreReview {
                appStoreReviewURL = try? await client.appStoreReviewDestination()
            }
        } catch {
            remoteIconURL = nil
            isRemoteIconReady = true
            appStoreReviewURL = nil
        }
        isLoadingAboutContent = false
    }

    private func preloadRemoteIcon(_ url: URL) async {
        do {
            _ = try await UAPPRemoteImageCache.shared.load(url)
            isRemoteIconReady = true
        } catch {
            remoteIconURL = nil
            isRemoteIconReady = true
        }
    }

    private func openAppStoreReview() {
        guard !isOpeningAppStoreReview else { return }
        isOpeningAppStoreReview = true
        Task { @MainActor in
            defer { isOpeningAppStoreReview = false }
            do {
                let destination: URL
                if let appStoreReviewURL {
                    destination = appStoreReviewURL
                } else {
                    guard let client else { return }
                    guard let loadedDestination = try await client.appStoreReviewDestination() else {
                        appStoreReviewError = UAPPKitError.appStoreURLUnavailable.localizedDescription
                        return
                    }
                    appStoreReviewURL = loadedDestination
                    destination = loadedDestination
                }

                guard await uappOpenExternalURLAndReportSuccess(destination) else {
                    appStoreReviewError = UAPPKitError.appStoreURLCouldNotOpen.localizedDescription
                    return
                }
            } catch {
                appStoreReviewURL = nil
                appStoreReviewError = error.localizedDescription
            }
        }
    }

    private func matchingAboutAppIconURL(
        in about: UAPPAbout,
        project: UAPPProject?
    ) -> URL? {
        guard let project else { return nil }
        return about.apps.first { app in
            app.slug == project.slug
                || app.projectId == project.slug
                || app.name.caseInsensitiveCompare(project.displayName ?? "") == .orderedSame
        }?.iconURL
    }
}
#endif
