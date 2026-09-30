#if canImport(SwiftUI)
import SwiftUI

/// Modo de exibição da tela nativa.
public enum UAPPScreenMode: Sendable {
    case feedback
    case roadmap
    case changelog

    var titleKey: String {
        switch self {
        case .feedback: "screen.feedback"
        case .roadmap: "screen.roadmap"
        case .changelog: "screen.changelog"
        }
    }
}

/// Tela SwiftUI nativa que consome as Edge Functions públicas do UAPP.
/// Sem WebView: toda a interface é nativa e evolui pelo próprio pacote.
public struct UAPPFeedbackScreen: View {
    let client: UAPPClient
    let mode: UAPPScreenMode
    let changelogConfiguration: UAPPChangelogConfiguration
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var errorMascotState: UAPPMascotState = .unavailable
    @State private var projectColor: Color?
    @State private var feedback: [UAPPFeedbackItem] = []
    @State private var roadmap: [UAPPRoadmapColumn] = []
    @StateObject private var changelogModel: UAPPChangelogModel
    @State private var isSubmittingFeedback = false
    @State private var showsChangelogSearch = false
    @State private var changelogQuery = ""
    @State private var changelogTranslationCache = UAPPReviewTranslationCache()
    @State private var selectedChangelogEntry: UAPPChangelogEntry?

    public init(
        client: UAPPClient,
        mode: UAPPScreenMode,
        changelogConfiguration: UAPPChangelogConfiguration = .init()
    ) {
        self.client = client
        self.mode = mode
        self.changelogConfiguration = changelogConfiguration
        _changelogModel = StateObject(wrappedValue: UAPPChangelogModel(client: client, pageSize: changelogConfiguration.pageSize))
    }

    init(
        client: UAPPClient,
        mode: UAPPScreenMode,
        testingIsLoading isLoading: Bool,
        errorMessage: String? = nil,
        errorMascotState: UAPPMascotState = .unavailable,
        projectColor: Color? = nil,
        feedback: [UAPPFeedbackItem] = [],
        roadmap: [UAPPRoadmapColumn] = [],
        changelog: [UAPPChangelogEntry] = [],
        changelogNextCursor: String? = nil,
        isLoadingMoreChangelog: Bool = false,
        changelogLoadMoreError: String? = nil,
        testingChangelogModel: UAPPChangelogModel? = nil,
        testingChangelogTranslationCache: UAPPReviewTranslationCache? = nil
    ) {
        self.client = client
        self.mode = mode
        changelogConfiguration = .init()
        _isLoading = State(initialValue: isLoading)
        _errorMessage = State(initialValue: errorMessage)
        _errorMascotState = State(initialValue: errorMascotState)
        _projectColor = State(initialValue: projectColor)
        _feedback = State(initialValue: feedback)
        _roadmap = State(initialValue: roadmap)
        _changelogTranslationCache = State(initialValue: testingChangelogTranslationCache ?? UAPPReviewTranslationCache())
        _changelogModel = StateObject(wrappedValue: testingChangelogModel ?? UAPPChangelogModel(
            client: client, entries: changelog, nextCursor: changelogNextCursor,
            isLoadingMore: isLoadingMoreChangelog, loadMoreError: changelogLoadMoreError
        ))
    }

    public var body: some View {
        screenContent
            .navigationDestination(isPresented: showsChangelogDetail) {
                if let selectedChangelogEntry {
                    changelogDetailScreen(for: selectedChangelogEntry)
                }
            }
            .background(palette.background.ignoresSafeArea())
            .foregroundStyle(palette.primaryText)
            #if canImport(UIKit)
            .toolbar(.visible, for: .navigationBar)
            #endif
            .uappNavigationBar(titleKey: mode.titleKey, accentColor: accentColor)
            .modifier(UAPPChangelogSearchModifier(
                enabled: mode == .changelog,
                query: $changelogQuery,
                isPresented: $showsChangelogSearch,
                accentColor: accentColor
            ))
            .environment(\.uappChangelogTranslationCache, changelogTranslationCache)
            .environment(\.locale, Locale(identifier: selectedLanguage))
            .onChange(of: showsChangelogSearch) { isPresented in
                if !isPresented {
                    changelogQuery = ""
                }
            }
            .task { await load() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if case .feedback = mode {
                        Button {
                            isSubmittingFeedback = true
                        } label: {
                            Text(verbatim: uappLocalized("feedback.send"))
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if case .changelog = mode {
                        Button {
                            showsChangelogSearch.toggle()
                            if !showsChangelogSearch {
                                changelogQuery = ""
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(accentColor)
                        }
                        .accessibilityLabel(Text(verbatim: uappLocalized("changelog.search")))
                    }
                }
            }
            .sheet(isPresented: $isSubmittingFeedback) {
                NavigationStack {
                    UAPPSubmitFeedbackScreen(client: client) {
                        isSubmittingFeedback = false
                        Task { await load() }
                    }
                }
                .uappPresentationBackground(palette.background)
                .uappPresentationPlacement(.trailing)
            }
    }

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    private var accentColor: Color {
        palette.accent ?? projectColor ?? .accentColor
    }

    private var showsChangelogDetail: Binding<Bool> {
        Binding(
            get: { selectedChangelogEntry != nil },
            set: {
                if !$0 {
                    selectedChangelogEntry = nil
                }
            }
        )
    }

    func changelogDetailScreen(for entry: UAPPChangelogEntry) -> UAPPChangelogDetailScreen {
        UAPPChangelogDetailScreen(entry: entry, accentColor: accentColor, translationCache: changelogTranslationCache)
    }

    @ViewBuilder
    private var screenContent: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            UAPPUnavailableContent(
                message: errorMessage,
                accentColor: accentColor,
                mascotState: errorMascotState
            ) {
                Task { await load() }
            }
        } else {
            switch mode {
            case .feedback where feedback.isEmpty:
                UAPPEmptyContent(
                    mascotState: .emptyFeedback,
                    titleKey: "feedback.empty.title",
                    messageKey: "feedback.empty.message"
                )
            case .changelog where changelogModel.entries.isEmpty && changelogModel.nextCursor == nil:
                UAPPEmptyContent(
                    mascotState: .emptyChangelog,
                    titleKey: "changelog.empty.title",
                    messageKey: "changelog.empty.message"
                )
            default:
                List { content }
                    .scrollContentBackground(.hidden)
                    .background(palette.background)
                    .listRowSeparatorTint(palette.separator)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .feedback:
            ForEach(feedback) { item in
                NavigationLink {
                    UAPPFeedbackDetailScreen(client: client, item: item)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.headline)
                        if let body = item.body, !body.isEmpty {
                            Text(body).font(.subheadline).foregroundStyle(palette.secondaryText)
                        }
                        Text(verbatim: uappLocalizedFormat(
                            "feedback.metrics",
                            item.voteCount,
                            item.likeCount,
                            item.commentCount
                        ))
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText.opacity(0.75))
                    }
                }
                .listRowBackground(palette.cardBackground)
            }
        case .roadmap:
            ForEach(roadmap, id: \.status.key) { column in
                Section(column.status.name) {
                    if column.items.isEmpty {
                        Text(verbatim: uappLocalized("roadmap.empty"))
                            .foregroundStyle(palette.secondaryText)
                    }
                    ForEach(column.items) { item in
                        NavigationLink(item.title) {
                            UAPPFeedbackDetailScreen(client: client, item: item)
                        }
                    }
                }
                .listRowBackground(palette.cardBackground)
            }
        case .changelog:
            let filtered = UAPPChangelogPresentation.newestFirst(changelogModel.entries)
                .filter { UAPPChangelogPresentation(entry: $0).matches(changelogQuery) }
            if filtered.isEmpty {
                Text(verbatim: uappLocalized("changelog.no_results"))
                    .listRowBackground(palette.cardBackground)
            }
            ForEach(filtered) { entry in
                UAPPChangelogCard(
                    entry: entry, configuration: changelogConfiguration,
                    translationCache: changelogTranslationCache,
                    onOpen: { selectedChangelogEntry = entry }
                )
                .tint(accentColor)
                .listRowBackground(palette.cardBackground)
            }
            if changelogModel.isLoadingMore {
                HStack(spacing: 10) {
                    ProgressView().tint(accentColor)
                    Text(verbatim: uappLocalized("changelog.loading_more"))
                        .font(.footnote).foregroundStyle(palette.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .listRowBackground(palette.cardBackground)
                .listRowSeparator(.hidden)
            } else if changelogModel.nextCursor != nil, changelogModel.loadMoreError == nil {
                Color.clear
                    .frame(height: 1)
                    .id(changelogModel.nextCursor)
                    .onAppear { Task { await changelogModel.loadMore() } }
                    .accessibilityHidden(true)
                    .listRowSeparator(.hidden)
                    .listRowBackground(palette.cardBackground)
            }
            if let loadMoreError = changelogModel.loadMoreError {
                Text(loadMoreError)
                    .font(.footnote)
                    .foregroundStyle(palette.secondaryText)
                    .listRowBackground(palette.cardBackground)
                Button {
                    Task { await changelogModel.loadMore() }
                } label: {
                    Text(verbatim: uappLocalized("common.retry"))
                }
                .listRowBackground(palette.cardBackground)
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            switch mode {
            case .feedback:
                feedback = try await client.feedback()
            case .roadmap:
                roadmap = try await client.roadmap()
            case .changelog:
                try await changelogModel.load()
            }
        } catch {
            let project = await client.currentProject()
            projectColor = project?.primaryColor.flatMap(Color.init(hex:))
            if case UAPPKitError.http(status: 403, _) = error {
                errorMascotState = .unavailable
                errorMessage = uappLocalized("unavailable.content")
            } else {
                errorMascotState = .connectionError
                errorMessage = uappLocalized("unavailable.load_error")
            }
        }
        isLoading = false
    }
}

struct UAPPEmptyContent: View {
    let mascotState: UAPPMascotState
    let title: Text
    let message: Text
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    init(mascotState: UAPPMascotState, title: String, message: String) {
        self.mascotState = mascotState
        self.title = Text(verbatim: title)
        self.message = Text(verbatim: message)
    }

    init(mascotState: UAPPMascotState, titleKey: String, messageKey: String) {
        self.mascotState = mascotState
        title = Text(verbatim: uappLocalized(titleKey))
        message = Text(verbatim: uappLocalized(messageKey))
    }

    var body: some View {
        UAPPStateCard {
            VStack(spacing: 12) {
                UAPPMascotIllustration(state: mascotState)

                title
                    .font(.headline)
                    .multilineTextAlignment(.center)

                message
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct UAPPSubmitFeedbackScreen: View {
    let client: UAPPClient
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @State private var title = ""
    @State private var details = ""
    @State private var category: UAPPFeedbackCategory = .feature
    @State private var isSending = false
    @State private var errorMessage: String?

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    var body: some View {
        Form {
            TextField(
                uappLocalized("feedback.field.title"),
                text: $title
            )
            Picker(selection: $category) {
                Text(verbatim: uappLocalized("category.bug")).tag(UAPPFeedbackCategory.bug)
                Text(verbatim: uappLocalized("category.feature")).tag(UAPPFeedbackCategory.feature)
                Text(verbatim: uappLocalized("category.improvement")).tag(UAPPFeedbackCategory.improvement)
                Text(verbatim: uappLocalized("category.question")).tag(UAPPFeedbackCategory.question)
            } label: {
                Text(verbatim: uappLocalized("feedback.field.type"))
            }
            TextField(
                uappLocalized("feedback.field.description"),
                text: $details,
                axis: .vertical
            )
            .lineLimit(4 ... 10)
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .foregroundStyle(palette.primaryText)
        .tint(palette.accent ?? .accentColor)
        #if canImport(UIKit)
        .toolbar(.visible, for: .navigationBar)
        #endif
        .uappNavigationBar(
            titleKey: "feedback.new_title",
            accentColor: palette.accent ?? .accentColor
        )
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await submit() }
                } label: {
                    Text(verbatim: uappLocalized("common.send"))
                }
                .disabled(isSending || title.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
            }
        }
    }

    private func submit() async {
        isSending = true
        errorMessage = nil
        do {
            _ = try await client.submitFeedback(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: details.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category
            )
            onComplete()
        } catch {
            errorMessage = uappLocalized("feedback.submit_error")
        }
        isSending = false
    }
}

private extension View {
    @ViewBuilder
    func uappPresentationPlacement(_ placement: UAPPPresentationPlacement) -> some View {
        #if os(iOS)
        if #available(iOS 27, *) {
            presentationPlacement(placement.swiftUIValue)
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func uappPresentationBackground(_ color: Color) -> some View {
        if #available(iOS 16.4, macOS 13.3, *) {
            presentationBackground(color)
        } else {
            background(color.ignoresSafeArea())
        }
    }
}

private enum UAPPPresentationPlacement {
    case trailing

    #if os(iOS)
    @available(iOS 27, *)
    var swiftUIValue: PresentationPlacement {
        switch self {
        case .trailing: .trailing
        }
    }
    #endif
}

#endif
