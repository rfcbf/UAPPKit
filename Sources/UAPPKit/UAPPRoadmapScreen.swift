#if canImport(SwiftUI)
import SwiftUI

/// Roadmap público: sugestões publicadas agrupadas pelos status visíveis do projeto.
/// Navegação pública; votar pede login e retoma a ação após a autenticação.
public struct UAPPRoadmapScreen: View {
    let client: UAPPClient
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier

    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var errorMascotState: UAPPMascotState = .unavailable
    @State private var projectColor: Color?
    @State private var columns: [UAPPRoadmapColumn] = []
    @State private var category: UAPPFeedbackCategory?
    @State private var statusId: String?
    @State private var sort: UAPPFeedbackSort = .newest
    @StateObject private var participation: UAPPParticipationModel
    @State private var showsSearch = false
    @State private var query = ""
    @State private var translationCache = UAPPReviewTranslationCache()
    @State private var selectedFeedback: UAPPFeedbackItem?
    @State private var selectedAuthor: UAPPFeedbackItem?
    @State private var reactingIds: Set<String> = []
    @State private var reactionError: String?

    public init(client: UAPPClient) {
        self.client = client
        _participation = StateObject(wrappedValue: UAPPParticipationModel(client: client))
    }

    public var body: some View {
        content
            .modifier(UAPPFeedbackItemNavigation(
                client: client, accentColor: accentColor, statuses: statuses,
                selectedFeedback: $selectedFeedback, selectedAuthor: $selectedAuthor,
                reactionError: $reactionError, onUpdate: replace
            ))
            .safeAreaInset(edge: .top, spacing: 0) {
                if !isLoading, errorMessage == nil {
                    UAPPFeedbackControls(
                        statuses: statuses, category: $category, statusId: $statusId,
                        sort: $sort, accentColor: accentColor
                    )
                }
            }
            .background(palette.background.ignoresSafeArea())
            .foregroundStyle(palette.primaryText)
            #if canImport(UIKit)
            .toolbar(.visible, for: .navigationBar)
            #endif
            .uappNavigationBar(titleKey: UAPPScreenMode.roadmap.titleKey, accentColor: accentColor, showsLanguageMenu: false)
            .modifier(UAPPParticipationModifier(
                model: participation,
                accentColor: accentColor,
                enabled: true,
                searchAction: {
                    showsSearch.toggle()
                    if !showsSearch {
                        query = ""
                    }
                },
                searchPromptKey: "common.search"
            ))
            .modifier(UAPPChangelogSearchModifier(
                enabled: true,
                query: $query,
                isPresented: $showsSearch,
                accentColor: accentColor,
                promptKey: "common.search"
            ))
            .environment(\.uappFeedbackTranslationCache, translationCache)
            .environment(\.locale, Locale(identifier: selectedLanguage))
            .uappOnChange(of: showsSearch) { isPresented in
                if !isPresented {
                    query = ""
                }
            }
            .task { await load() }
            .modifier(UAPPFeedbackLiveModifier(client: client) {
                await load(silently: true)
            })
    }

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    private var accentColor: Color {
        palette.accent ?? projectColor ?? .accentColor
    }

    private var statuses: [UAPPRoadmapColumn.Status] {
        columns.map(\.status)
    }

    /// Colunas após busca (título, descrição ou nome do status), filtros e ordenação.
    private var presentedColumns: [UAPPRoadmapColumn] {
        UAPPFeedbackSearch.columns(columns, matching: query)
            .filter { statusId == nil || $0.status.id == statusId }
            .map { column in
                UAPPRoadmapColumn(status: column.status, items: UAPPFeedbackSearch.presentedItems(
                    column.items, matching: "", category: category, statusId: nil, sort: sort
                ))
            }
    }

    @ViewBuilder
    private var content: some View {
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
            let presented = presentedColumns
            if presented.allSatisfy(\.items.isEmpty) {
                UAPPStateCard { UAPPFeedbackNoResults() }
            } else {
                List {
                    ForEach(presented, id: \.status.key) { column in
                        Section(uappFeedbackStatusTitle(column.status)) {
                            if column.items.isEmpty {
                                UAPPFeedbackCompactNoResultsRow()
                            }
                            ForEach(column.items) { item in
                                card(item, status: column.status)
                                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                                    .alignmentGuide(.listRowSeparatorTrailing) { $0.width }
                            }
                        }
                        .listRowBackground(palette.cardBackground)
                    }
                }
                .modifier(UAPPFeedbackListSpacing(enabled: true))
                .scrollContentBackground(.hidden)
                .background(palette.background)
                .listRowSeparatorTint(palette.separator)
            }
        }
    }

    private func card(_ item: UAPPFeedbackItem, status: UAPPRoadmapColumn.Status) -> some View {
        UAPPFeedbackCard(
            item: item, status: status, accentColor: accentColor,
            isReacting: reactingIds.contains(item.id) || participation.isBusy,
            layout: .roadmap,
            onReact: { Task { await participation.perform { await react(to: item.id) } } },
            onProfile: { selectedAuthor = item },
            onDetail: { selectedFeedback = item }
        )
    }

    private func replace(_ item: UAPPFeedbackItem) {
        columns = columns.map { column in
            UAPPRoadmapColumn(status: column.status, items: column.items.map { $0.id == item.id ? item : $0 })
        }
    }

    private func react(to id: String) async {
        guard !reactingIds.contains(id),
              let original = columns.flatMap(\.items).first(where: { $0.id == id }) else { return }
        reactingIds.insert(id)
        defer { reactingIds.remove(id) }
        if await !(UAPPFeedbackVoting.toggle(original, client: client, replace: replace)) {
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
            }
        }
        do {
            let loaded = try await client.roadmap()
            try Task.checkCancellation()
            columns = loaded
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            if let failure = UAPPFeedbackLoadFailure.make(for: error, silently: silently, hasContent: !columns.isEmpty) {
                if failure.clearsContent {
                    columns = []
                }
                errorMascotState = failure.mascotState
                errorMessage = failure.messageKey
            }
        }
        let project = await client.currentProject()
        projectColor = project?.primaryColor.flatMap(Color.init(hex:))
    }
}

extension UAPPRoadmapScreen {
    init(
        client: UAPPClient,
        testingIsLoading isLoading: Bool,
        errorMessage: String? = nil,
        errorMascotState: UAPPMascotState = .unavailable,
        projectColor: Color? = nil,
        columns: [UAPPRoadmapColumn] = [],
        testingQuery: String = ""
    ) {
        self.init(client: client)
        _isLoading = State(initialValue: isLoading)
        _errorMessage = State(initialValue: errorMessage)
        _errorMascotState = State(initialValue: errorMascotState)
        _projectColor = State(initialValue: projectColor)
        _columns = State(initialValue: columns)
        _query = State(initialValue: testingQuery)
    }
}
#endif
