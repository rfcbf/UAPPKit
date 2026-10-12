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
        } else {
            feedbackOrChangelog
        }
    }

    private var feedbackOrChangelog: some View {
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
            .navigationDestination(isPresented: showsChangelogDetail) {
                if let selectedChangelogEntry {
                    Self.changelogDetailScreen(
                        for: selectedChangelogEntry, accentColor: accentColor,
                        translationCache: changelogTranslationCache
                    )
                }
            }
            .background(palette.background.ignoresSafeArea())
            .foregroundStyle(palette.primaryText)
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
                promptKey: mode == .changelog ? "changelog.search" : "common.search"
            ))
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
                        Task { await load() }
                    }
                }
                .environment(\.uappTheme, theme)
                .environment(\.locale, Locale(identifier: selectedLanguage))
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
                feedbackCard(item, status: feedbackStatuses.first { $0.id == item.statusId })
                    .listRowBackground(palette.cardBackground)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    .alignmentGuide(.listRowSeparatorTrailing) { $0.width }
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

    private func feedbackCard(_ item: UAPPFeedbackItem, status: UAPPRoadmapColumn.Status?) -> some View {
        UAPPFeedbackCard(
            item: item, status: status, accentColor: accentColor,
            isReacting: reactingIds.contains(item.id) || participation.isBusy,
            onReact: { Task { await participation.perform { await react(to: item.id) } } },
            onProfile: { selectedAuthor = item },
            onDetail: { selectedFeedback = item }
        )
    }

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
        _errorMessage = State(initialValue: errorMessage)
        _errorMascotState = State(initialValue: errorMascotState)
        _projectColor = State(initialValue: projectColor)
        _feedback = State(initialValue: feedback)
        _changelogQuery = State(initialValue: testingQuery)
        _changelogTranslationCache = State(initialValue: testingChangelogTranslationCache ?? UAPPReviewTranslationCache())
        _changelogModel = StateObject(wrappedValue: testingChangelogModel ?? UAPPChangelogModel(
            client: client, entries: changelog, nextCursor: changelogNextCursor,
            isLoadingMore: isLoadingMoreChangelog, loadMoreError: changelogLoadMoreError
        ))
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
    private enum Field: Hashable {
        case title
        case description
    }

    static let minimumTitleLength = 3

    let client: UAPPClient
    var accentColor: Color?
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier
    @State private var title = ""
    @State private var details = ""
    @State private var imageData: [Data] = []
    @State private var isProcessingImage = false
    @State private var category: UAPPFeedbackCategory = .feature
    @State private var isSending = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?
    @ScaledMetric(relativeTo: .body) private var descriptionMinHeight: CGFloat = 140
    @ScaledMetric(relativeTo: .title2) private var headerIconSize: CGFloat = 52

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    private var resolvedAccent: Color {
        palette.accent ?? accentColor ?? .accentColor
    }

    private var trimmedTitleLength: Int {
        title.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                introHeader
                categorySection
                titleSection
                descriptionSection
                attachmentsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(palette.background.ignoresSafeArea())
        .foregroundStyle(palette.primaryText)
        .tint(resolvedAccent)
        .environment(\.locale, Locale(identifier: selectedLanguage))
        #if canImport(UIKit)
        .toolbar(.visible, for: .navigationBar)
        #endif
        .uappNavigationBar(
            titleKey: "feedback.new_title",
            accentColor: resolvedAccent
        )
        .uappKeyboardFieldNavigation(
            focusedField: $focusedField,
            fields: [.title, .description],
            accentColor: resolvedAccent
        )
        .safeAreaInset(edge: .bottom) {
            sendBar
        }
        .uappToast(message: Binding(
            get: { errorMessage.map { uappLocalized($0) } },
            set: {
                if $0 == nil {
                    errorMessage = nil
                }
            }
        ))
    }

    // MARK: - Seções

    private var introHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: category.composerSymbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(resolvedAccent)
                .frame(width: headerIconSize, height: headerIconSize)
                .background(
                    resolvedAccent.opacity(colorScheme == .dark ? 0.22 : 0.12),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .id(category)
                .uappMotionTransition(.scale(scale: 0.85).combined(with: .opacity))
                .accessibilityHidden(true)

            Text(verbatim: uappLocalized("feedback.compose.intro"))
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("feedback.field.type")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(UAPPFeedbackCategory.allCases, id: \.self) { option in
                    categoryChip(option)
                }
            }
        }
    }

    private func categoryChip(_ option: UAPPFeedbackCategory) -> some View {
        let isSelected = option == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                category = option
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: option.composerSymbol)
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 22)
                    .accessibilityHidden(true)
                Text(verbatim: uappLocalized(option.composerTitleKey))
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .uappMotionTransition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(isSelected ? resolvedAccent : palette.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? resolvedAccent.opacity(colorScheme == .dark ? 0.2 : 0.1) : palette.cardBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? resolvedAccent : palette.separator.opacity(0.5),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isSending)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("feedback.field.title")
            TextField(
                uappLocalized("feedback.field.title"),
                text: $title,
                prompt: Text(verbatim: uappLocalized("feedback.compose.title_placeholder"))
            )
            .textFieldStyle(.plain)
            .font(.body)
            .focused($focusedField, equals: .title)
            .submitLabel(.next)
            .onSubmit { focusedField = .description }
            .disabled(isSending)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(fieldBackground(isFocused: focusedField == .title))
            .contentShape(Rectangle())
            .onTapGesture { focusedField = .title }

            if !title.isEmpty, trimmedTitleLength < Self.minimumTitleLength {
                Label {
                    Text(verbatim: uappLocalized("feedback.compose.title_hint"))
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: trimmedTitleLength < Self.minimumTitleLength)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("feedback.field.description", detailKey: "feedback.compose.optional")
            ZStack(alignment: .topLeading) {
                if details.isEmpty {
                    Text(verbatim: uappLocalized("feedback.compose.description_placeholder"))
                        .foregroundStyle(palette.secondaryText)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $details)
                    .focused($focusedField, equals: .description)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: descriptionMinHeight)
                    .disabled(isSending)
                    .accessibilityLabel(Text(verbatim: uappLocalized("feedback.field.description")))
            }
            .font(.body)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(fieldBackground(isFocused: focusedField == .description))
        }
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                "feedback.compose.attachments",
                detail: "\(imageData.count)/\(UAPPFeedbackComposerAttachments.limit)"
            )
            UAPPFeedbackComposerAttachments(
                data: $imageData,
                isProcessing: $isProcessingImage,
                accent: resolvedAccent,
                palette: palette
            )
            .disabled(isSending)
            Text(verbatim: uappLocalized("feedback.compose.attachments_hint"))
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sendBar: some View {
        Button {
            focusedField = nil
            Task { await submit() }
        } label: {
            HStack(spacing: 10) {
                if isSending {
                    ProgressView().tint(palette.buttonText)
                } else {
                    Image(systemName: "paperplane.fill")
                        .accessibilityHidden(true)
                }
                Text(verbatim: uappLocalized("common.send"))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(palette.buttonText)
            .background(resolvedAccent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .opacity(canSend || isSending ? 1 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: canSend)
        .frame(maxWidth: 640)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            palette.background
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { Divider() }
        }
    }

    // MARK: - Componentes

    private func sectionHeader(_ key: String, detailKey: String) -> some View {
        sectionHeader(key, detail: uappLocalized(detailKey))
    }

    private func sectionHeader(_ key: String, detail: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: uappLocalized(key))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let detail {
                Text(verbatim: detail)
                    .monospacedDigit()
                    .font(.footnote)
                    .foregroundStyle(palette.secondaryText)
            }
        }
    }

    private func fieldBackground(isFocused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(palette.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isFocused ? resolvedAccent : palette.separator.opacity(0.5),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            }
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    private var canSend: Bool {
        !isSending && !isProcessingImage && trimmedTitleLength >= Self.minimumTitleLength
    }

    private func submit() async {
        isSending = true
        errorMessage = nil
        do {
            _ = try await client.submitFeedback(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: details.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                imagesData: imageData
            )
            onComplete()
        } catch {
            withAnimation(.easeInOut(duration: 0.2)) {
                errorMessage = "feedback.submit_error"
            }
        }
        isSending = false
    }
}

extension UAPPSubmitFeedbackScreen {
    /// Abre o compositor com título, descrição e tipo já preenchidos.
    init(
        client: UAPPClient,
        accentColor: Color? = nil,
        draft: UAPPFeedbackDraft,
        onComplete: @escaping () -> Void
    ) {
        self.init(client: client, accentColor: accentColor, onComplete: onComplete)
        _title = State(initialValue: draft.title)
        _details = State(initialValue: draft.details)
        _category = State(initialValue: draft.category)
    }
}

extension UAPPFeedbackCategory {
    /// Chave localizada exibida no seletor de tipo do compositor.
    var composerTitleKey: String {
        "category.\(rawValue)"
    }

    /// Símbolo SF associado ao tipo de feedback no compositor.
    var composerSymbol: String {
        switch self {
        case .bug: "ladybug"
        case .feature: "sparkles"
        case .improvement: "wand.and.stars"
        case .question: "questionmark.bubble"
        }
    }
}

#endif
