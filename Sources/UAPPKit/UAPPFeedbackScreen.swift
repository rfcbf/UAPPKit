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
    /// A primeira carga terminou e a cor do projeto já é conhecida.
    @State private var hasLoaded = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var errorMascotState: UAPPMascotState = .unavailable
    @State private var projectColor: Color?
    @State private var feedback: [UAPPFeedbackItem] = []
    @State private var feedbackStatuses: [UAPPRoadmapColumn.Status] = []
    @State private var feedbackCategory: UAPPFeedbackCategory?
    @State private var feedbackStatusId: String?
    @State private var feedbackSort: UAPPFeedbackSort = .newest
    @StateObject private var changelogModel: UAPPChangelogModel
    @StateObject private var participation: UAPPParticipationModel
    @State private var isSubmittingFeedback = false
    /// App de demonstração: aviso com a contagem até a requisição enviada ser publicada sozinha.
    @State private var autoPublishNotice: String?
    @State private var autoPublishSeconds: Int?
    @State private var autoPublishTicket: UUID?
    @State private var showsChangelogSearch = false
    @State private var changelogQuery = ""
    @State private var changelogTranslationCache = UAPPReviewTranslationCache()
    @State private var feedbackTranslationCache = UAPPReviewTranslationCache()
    @State private var selectedChangelogEntry: UAPPChangelogEntry?
    @State private var selectedFeedback: UAPPFeedbackItem?
    @State private var selectedAuthor: UAPPFeedbackItem?
    @State private var reactingIds: Set<String> = []
    @State private var reactionError: String?

    public init(
        client: UAPPClient,
        mode: UAPPScreenMode,
        changelogConfiguration: UAPPChangelogConfiguration = .init()
    ) {
        self.client = client
        self.mode = mode
        self.changelogConfiguration = changelogConfiguration
        _participation = StateObject(wrappedValue: UAPPParticipationModel(client: client))
        _changelogModel = StateObject(wrappedValue: UAPPChangelogModel(client: client, pageSize: changelogConfiguration.pageSize))
    }

    public var body: some View {
        screenBody.uappTextSizeLimit()
    }

    @ViewBuilder private var screenBody: some View {
        if mode == .roadmap {
            // Compatibilidade: `mode: .roadmap` apresenta a view própria do Roadmap.
            UAPPRoadmapScreen(client: client)
        } else if mode == .feedback {
            // No Mac, a barra de ferramentas e a busca ficam sobre a divisão inteira, do lado do
            // detalhe; no iPhone e no iPad a divisão devolve só a lista.
            screenChrome(UAPPFeedbackSplitView(
                client: client, accentColor: accentColor, statuses: feedbackStatuses,
                selectedFeedback: $selectedFeedback, onUpdate: replaceFeedback
            ) {
                listContent
            })
        } else {
            screenChrome(listContent)
        }
    }

    private var listContent: some View {
        screenContent
            .modifier(UAPPFeedbackItemNavigation(
                client: client, accentColor: accentColor, statuses: feedbackStatuses,
                selectedFeedback: $selectedFeedback, selectedAuthor: $selectedAuthor,
                reactionError: $reactionError, onUpdate: replaceFeedback
            ))
            .safeAreaInset(edge: .top, spacing: 0) {
                if mode == .feedback, !isLoading, errorMessage == nil {
                    UAPPFeedbackControls(
                        statuses: feedbackStatuses, category: $feedbackCategory, statusId: $feedbackStatusId,
                        sort: $feedbackSort, accentColor: accentColor
                    )
                }
            }
            // No Mac, "Enviar feedback" fica na barra de ferramentas, com ⌘N.
            #if !os(macOS)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if case .feedback = mode {
                    HStack {
                        Spacer()
                        submitFeedbackButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
            }
            #endif
            .modifier(changelogNavigation)
            .uappScreenBackground(palette.background)
            .foregroundStyle(palette.primaryText)
    }

    /// Só o Changelog empilha o detalhe. No Mac, Feedback fica fora de uma `NavigationStack`, e um
    /// destino registrado ali impedia a lista de mostrar as linhas.
    private var changelogNavigation: UAPPChangelogDetailNavigation {
        UAPPChangelogDetailNavigation(
            isEnabled: mode == .changelog,
            isPresented: showsChangelogDetail,
            destination: selectedChangelogEntry.map {
                Self.changelogDetailScreen(
                    for: $0, accentColor: accentColor, translationCache: changelogTranslationCache
                )
            }
        )
    }

    /// Título, barra de ferramentas, busca, carga e sheets da tela.
    private func screenChrome(_ content: some View) -> some View {
        content
            #if canImport(UIKit)
            .toolbar(.visible, for: .navigationBar)
            #endif
            .uappNavigationBar(titleKey: mode.titleKey, accentColor: accentColor, showsLanguageMenu: false)
            .modifier(UAPPParticipationModifier(
                model: participation,
                accentColor: accentColor,
                enabled: mode != .changelog,
                searchAction: {
                    showsChangelogSearch.toggle()
                    if !showsChangelogSearch {
                        changelogQuery = ""
                    }
                },
                searchPromptKey: mode == .changelog ? "changelog.search" : "common.search"
            ))
            .modifier(UAPPChangelogSearchModifier(
                enabled: true,
                query: $changelogQuery,
                isPresented: $showsChangelogSearch,
                accentColor: accentColor,
                promptKey: mode == .changelog ? "changelog.search" : "common.search",
                isPersistentOnMac: true
            ))
            .modifier(UAPPMacFeedbackCommands(
                showsNewFeedback: mode == .feedback,
                accentColor: accentColor,
                isRefreshing: isRefreshing,
                onNewFeedback: { Task { await participation.perform { isSubmittingFeedback = true } } },
                onRefresh: { Task { await load() } }
            ))
            #if os(macOS)
            // No Mac, os botões da barra só aparecem quando a cor do projeto já é conhecida.
            .environment(\.uappToolbarItemsHidden, !hasLoaded)
            #endif
            .environment(\.uappChangelogTranslationCache, changelogTranslationCache)
            .environment(\.uappFeedbackTranslationCache, feedbackTranslationCache)
            .environment(\.locale, Locale(identifier: selectedLanguage))
            .uappOnChange(of: showsChangelogSearch) { isPresented in
                if !isPresented {
                    changelogQuery = ""
                }
            }
            .task { await load() }
            .modifier(UAPPFeedbackLiveModifier(client: mode == .changelog ? nil : client) {
                await load(silently: true)
            })
            .sheet(isPresented: $isSubmittingFeedback) {
                NavigationStack {
                    UAPPSubmitFeedbackScreen(client: client, accentColor: accentColor) {
                        isSubmittingFeedback = false
                        Task { await feedbackSubmitted() }
                    }
                    .environment(\.uappSheetClose) { isSubmittingFeedback = false }
                }
                .environment(\.uappTheme, theme)
                .environment(\.locale, Locale(identifier: selectedLanguage))
                .uappPresentationBackground(palette.background)
                .uappPresentationPlacement(.trailing)
            }
            .uappToast(
                message: $autoPublishNotice,
                kind: .information,
                title: uappLocalized("feedback.demo_title"),
                duration: .seconds(autoPublishSeconds ?? 0)
            )
            .task(id: autoPublishTicket) { await reloadAfterAutoPublish() }
    }

    /// Depois de enviar uma requisição. No app de demonstração, avisa quando ela vai aparecer e
    /// recarrega a lista nessa hora; nos demais, só recarrega.
    private func feedbackSubmitted() async {
        if let seconds = await client.currentProject()?.autoPublishSeconds, seconds > 0 {
            autoPublishSeconds = seconds
            autoPublishNotice = uappLocalizedFormat("feedback.demo_auto_publish", seconds)
            autoPublishTicket = UUID()
        }
        await load()
    }

    private func reloadAfterAutoPublish() async {
        guard autoPublishTicket != nil, let seconds = autoPublishSeconds else { return }
        do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
        autoPublishNotice = nil
        await load(silently: true)
    }

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    private var accentColor: Color {
        palette.accent ?? projectColor ?? .accentColor
    }

    #if !os(macOS)
    private var submitFeedbackButton: some View {
        Button {
            Task { await participation.perform { isSubmittingFeedback = true } }
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(palette.buttonText)
                .frame(width: 56, height: 56)
                .background(accentColor, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: uappLocalized("feedback.send")))
    }
    #endif

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

    /// Recebe cor e cache já resolvidos para não ler ambiente ou estado fora de `body`.
    static func changelogDetailScreen(
        for entry: UAPPChangelogEntry, accentColor: Color, translationCache: UAPPReviewTranslationCache
    ) -> UAPPChangelogDetailScreen {
        UAPPChangelogDetailScreen(entry: entry, accentColor: accentColor, translationCache: translationCache)
    }

    @ViewBuilder
    private var screenContent: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            UAPPUnavailableContent(
                message: uappLocalized(errorMessage),
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
            case .feedback where UAPPFeedbackSearch.presentedItems(
                feedback, matching: changelogQuery, category: feedbackCategory,
                statusId: feedbackStatusId, sort: feedbackSort
            ).isEmpty:
                UAPPStateCard { UAPPFeedbackNoResults() }
            case .changelog where changelogModel.entries.isEmpty && changelogModel.nextCursor == nil:
                UAPPEmptyContent(
                    mascotState: .emptyChangelog,
                    titleKey: "changelog.empty.title",
                    messageKey: "changelog.empty.message"
                )
            default:
                List { content }
                    .modifier(UAPPFeedbackListSpacing(enabled: mode != .changelog))
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
            let filtered = UAPPFeedbackSearch.presentedItems(
                feedback, matching: changelogQuery, category: feedbackCategory,
                statusId: feedbackStatusId, sort: feedbackSort
            )
            if filtered.isEmpty {
                UAPPFeedbackNoResultsRow()
            }
            ForEach(filtered) { item in
                #if os(macOS)
                macRow(item, status: feedbackStatuses.first { $0.id == item.statusId })
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                #else
                feedbackCard(item, status: feedbackStatuses.first { $0.id == item.statusId })
                    .listRowBackground(palette.cardBackground)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    .alignmentGuide(.listRowSeparatorTrailing) { $0.width }
                #endif
            }
        case .roadmap:
            // Apresentado por UAPPRoadmapScreen.
            EmptyView()
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

    #if os(macOS)
    private func macRow(_ item: UAPPFeedbackItem, status: UAPPRoadmapColumn.Status?) -> some View {
        UAPPFeedbackMacRow(
            item: item, status: status, accentColor: accentColor,
            isSelected: selectedFeedback?.id == item.id,
            isReacting: reactingIds.contains(item.id) || participation.isBusy,
            onReact: { Task { await participation.perform { await react(to: item.id) } } },
            onProfile: { selectedAuthor = item },
            onDetail: { selectedFeedback = item }
        )
    }
    #else
    private func feedbackCard(_ item: UAPPFeedbackItem, status: UAPPRoadmapColumn.Status?) -> some View {
        UAPPFeedbackCard(
            item: item, status: status, accentColor: accentColor,
            isReacting: reactingIds.contains(item.id) || participation.isBusy,
            onReact: { Task { await participation.perform { await react(to: item.id) } } },
            onProfile: { selectedAuthor = item },
            onDetail: { selectedFeedback = item }
        )
    }
    #endif

    private func replaceFeedback(_ item: UAPPFeedbackItem) {
        feedback = feedback.map { $0.id == item.id ? item : $0 }
    }

    private func react(to id: String) async {
        guard !reactingIds.contains(id),
              let original = feedback.first(where: { $0.id == id }) else { return }
        reactingIds.insert(id)
        defer { reactingIds.remove(id) }
        if await !(UAPPFeedbackVoting.toggle(original, client: client, replace: replaceFeedback)) {
            reactionError = uappLocalized("detail.reaction_error")
        }
    }

    private func load(silently: Bool = false) async {
        while isRefreshing || (silently && !reactingIds.isEmpty) {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
        }
        guard !Task.isCancelled else { return }
        isRefreshing = true
        if !silently {
            isLoading = true; errorMessage = nil
        }
        defer {
            isRefreshing = false; if !silently {
                isLoading = false
                hasLoaded = true
            }
        }
        do {
            switch mode {
            case .feedback:
                let page = try await client.feedbackPage()
                try Task.checkCancellation()
                feedback = page.items
                feedbackStatuses = page.statuses
            case .roadmap:
                return
            case .changelog:
                try await changelogModel.load()
            }
            let project = await client.currentProject()
            projectColor = project?.primaryColor.flatMap(Color.init(hex:))
            errorMessage = nil
        } catch is CancellationError { return
        } catch {
            let project = await client.currentProject()
            projectColor = project?.primaryColor.flatMap(Color.init(hex:))
            if let failure = UAPPFeedbackLoadFailure.make(for: error, silently: silently, hasContent: !feedback.isEmpty) {
                if failure.clearsContent {
                    feedback = []
                }
                errorMascotState = failure.mascotState
                errorMessage = failure.messageKey
            }
        }
    }
}

extension UAPPFeedbackScreen {
    init(
        client: UAPPClient,
        mode: UAPPScreenMode,
        testingIsLoading isLoading: Bool,
        errorMessage: String? = nil,
        errorMascotState: UAPPMascotState = .unavailable,
        projectColor: Color? = nil,
        feedback: [UAPPFeedbackItem] = [],
        statuses: [UAPPRoadmapColumn.Status] = [],
        selectedFeedback: UAPPFeedbackItem? = nil,
        changelog: [UAPPChangelogEntry] = [],
        changelogNextCursor: String? = nil,
        isLoadingMoreChangelog: Bool = false,
        changelogLoadMoreError: String? = nil,
        testingChangelogModel: UAPPChangelogModel? = nil,
        testingChangelogTranslationCache: UAPPReviewTranslationCache? = nil,
        testingQuery: String = ""
    ) {
        self.client = client
        self.mode = mode
        changelogConfiguration = .init()
        _participation = StateObject(wrappedValue: UAPPParticipationModel(client: client))
        _isLoading = State(initialValue: isLoading)
        _hasLoaded = State(initialValue: !isLoading)
        _errorMessage = State(initialValue: errorMessage)
        _errorMascotState = State(initialValue: errorMascotState)
        _projectColor = State(initialValue: projectColor)
        _feedback = State(initialValue: feedback)
        _feedbackStatuses = State(initialValue: statuses)
        _selectedFeedback = State(initialValue: selectedFeedback)
        _changelogQuery = State(initialValue: testingQuery)
        _changelogTranslationCache = State(initialValue: testingChangelogTranslationCache ?? UAPPReviewTranslationCache())
        _changelogModel = StateObject(wrappedValue: testingChangelogModel ?? UAPPChangelogModel(
            client: client, entries: changelog, nextCursor: changelogNextCursor,
            isLoadingMore: isLoadingMoreChangelog, loadMoreError: changelogLoadMoreError
        ))
    }
}

#endif
