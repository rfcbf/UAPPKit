#if canImport(SwiftUI)
import SwiftUI

/// Tela pública Sobre do desenvolvedor, carregada do perfil do UAPP.
public struct UAPPDeveloperAboutScreen: View {
    private let client: UAPPClient
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier
    @State private var about: UAPPAbout?
    @State private var project: UAPPProject?
    @State private var isLoading = true
    @State private var hasError = false

    public init(client: UAPPClient) {
        self.client = client
    }

    init(
        client: UAPPClient,
        testingAbout about: UAPPAbout?,
        project: UAPPProject? = nil,
        isLoading: Bool,
        hasError: Bool = false
    ) {
        self.client = client
        _about = State(initialValue: about)
        _project = State(initialValue: project)
        _isLoading = State(initialValue: isLoading)
        _hasError = State(initialValue: hasError)
    }

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    public var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hasError {
                UAPPUnavailableContent(
                    message: uappLocalized("about.load_error"),
                    accentColor: palette.accent ?? .accentColor
                ) {
                    Task { await load() }
                }
            } else if let about {
                ScrollView {
                    UAPPAboutDeveloperContent(
                        about: about,
                        project: project,
                        selectedLanguage: selectedLanguage,
                        palette: palette
                    )
                    .padding(24)
                    .frame(maxWidth: 560, alignment: .leading)
                    .frame(maxWidth: .infinity, minHeight: 300, alignment: .top)
                }
            } else {
                UAPPEmptyContent(
                    mascotState: .emptyFeedback,
                    titleKey: "screen.developer_about",
                    messageKey: "about.empty"
                )
            }
        }
        .background(palette.background.ignoresSafeArea())
        .foregroundStyle(palette.primaryText)
        .uappNavigationBar(
            titleKey: "screen.developer_about",
            accentColor: palette.accent ?? .accentColor
        )
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            about = try await client.about()
            project = await client.currentProject()
            hasError = false
        } catch {
            hasError = true
        }
    }
}
#endif
