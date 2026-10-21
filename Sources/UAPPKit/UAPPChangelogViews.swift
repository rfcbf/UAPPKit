#if canImport(SwiftUI)
import SwiftUI

struct UAPPChangelogCard: View {
    let entry: UAPPChangelogEntry
    let configuration: UAPPChangelogConfiguration
    var translationCache: UAPPReviewTranslationCache?
    var onOpen: () -> Void = {}
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @Environment(\.uappChangelogTranslationCache) private var inheritedCache
    @State private var localCache = UAPPReviewTranslationCache()

    private var resolvedCache: UAPPReviewTranslationCache {
        translationCache ?? inheritedCache ?? localCache
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onOpen) {
                HStack(alignment: .top) {
                    UAPPChangelogHeading(entry: entry)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            let presentation = UAPPChangelogPresentation(entry: entry)
            if !presentation.description.isEmpty {
                Button(action: onOpen) {
                    UAPPChangelogTranslatedText(text: presentation.description, lineLimit: 3)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            if !presentation.imageItems.isEmpty {
                UAPPChangelogCarousel(entry: entry, configuration: configuration, onOpen: onOpen)
            }
            UAPPChangelogTextItems(items: presentation.textItems, lineLimit: 3)
                .onTapGesture(perform: onOpen)
        }
        .padding(.vertical, 12)
        .foregroundStyle(theme.resolved(for: colorScheme).primaryText)
        .environment(\.uappChangelogTranslationCache, resolvedCache)
    }
}

struct UAPPChangelogHeading: View {
    let entry: UAPPChangelogEntry
    var showsVersion = true
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsVersion {
                Group {
                    if let version = entry.version {
                        Text(verbatim: uappLocalizedFormat("changelog.version", version))
                    } else {
                        UAPPChangelogTranslatedText(text: entry.title)
                    }
                }
                .font(.title3.weight(.bold)).foregroundStyle(.tint)
            }
            if let build = entry.build {
                Text(verbatim: uappLocalizedFormat("changelog.build", build))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let date = entry.releasedAt {
                Text(verbatim: uappLocalizedFormat(
                    "changelog.released",
                    uappChangelogReleaseDate(date, locale: Locale(identifier: selectedLanguage))
                ))
                .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct UAPPChangelogImage: View {
    let item: UAPPChangelogItem
    var parallaxOffset: CGFloat = 0
    @Environment(\.uappChangelogImageFixture) private var fixture
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            UAPPCachedImage(url: fixture == nil ? item.section.imageURL : nil) { phase in
                switch fixture?.phase ?? phase {
                case let .success(image):
                    image.resizable().scaledToFit()
                        .scaleEffect(1 + abs(parallaxOffset) / max(proxy.size.width, 1) * 0.8)
                        .offset(x: -parallaxOffset * 0.4)
                case .failure:
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                        Text(verbatim: uappLocalized("changelog.image_failed"))
                            .font(.caption).multilineTextAlignment(.center)
                    }
                default:
                    // Sem o círculo claro do placeholder de imagem: só o indicador, na cor de destaque.
                    ProgressView()
                        .tint(theme.resolved(for: colorScheme).accent ?? .accentColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel(Text(verbatim: uappLocalized("changelog.image_loading")))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(40.0 / 21.0, contentMode: .fit)
        .background(.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.secondary.opacity(0.18), lineWidth: 1)
        }
        .accessibilityLabel(Text(uappChangelogMarkdown(item.section.bodyMarkdown)))
    }
}

struct UAPPChangelogItemText: View {
    let item: UAPPChangelogItem
    var lineLimit: Int?
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            UAPPChangelogCategoryLabel(category: item.section.category)
            UAPPChangelogTranslatedText(text: item.section.bodyMarkdown, lineLimit: lineLimit)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Rótulo da categoria com ícone sobre fundo tingido pela cor de destaque.
struct UAPPChangelogCategoryLabel: View {
    let category: UAPPChangelogCategory
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // HStack em vez de Label: o espaçamento padrão do Label afasta demais o ícone do nome.
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: category.symbol)
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(verbatim: uappLocalized("category.\(category.rawValue)", languageIdentifier: locale.identifier))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.tint.opacity(colorScheme == .dark ? 0.2 : 0.1), in: Capsule())
        .accessibilityAddTraits(.isHeader)
    }
}

extension UAPPChangelogCategory {
    /// Símbolo SF exibido junto ao nome da categoria no changelog.
    var symbol: String {
        switch self {
        case .new: "sparkles"
        case .improved: "arrow.up.circle"
        case .fixed: "wrench.and.screwdriver"
        case .security: "lock.shield"
        }
    }
}

struct UAPPChangelogCarousel: View {
    let entry: UAPPChangelogEntry
    let configuration: UAPPChangelogConfiguration
    var onOpen: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @State private var selection = -1
    @State private var scrollProgress: CGFloat = 0
    @State private var isVisible = false
    @State private var isApplicationActive = false

    private var presentation: UAPPChangelogPresentation {
        .init(entry: entry)
    }

    private var images: [UAPPChangelogItem] {
        presentation.imageItems
    }

    private var selected: UAPPChangelogItem? {
        presentation.selectedImage(selection)
    }

    private var selectionBinding: Binding<Int> {
        Binding(get: { selected?.id ?? -1 }, set: { selection = $0 })
    }

    var body: some View {
        VStack(spacing: 12) {
            if images.count > 1 {
                pages
                UAPPPagingIndicator(
                    count: images.count, progress: indicatorProgress, selection: selectedIndex,
                    activeTint: theme.resolved(for: colorScheme).accent ?? .accentColor,
                    inActiveTint: theme.resolved(for: colorScheme).primaryText.opacity(0.15)
                ) { index in
                    guard images.indices.contains(index) else { return }
                    select(images[index].id)
                }
            } else if let selected {
                UAPPChangelogImage(item: selected).onTapGesture(perform: onOpen)
            }
            if let selected {
                Button(action: onOpen) {
                    UAPPChangelogItemText(item: selected, lineLimit: 3)
                        .id(selected.id)
                        .transition(.opacity)
                }
                .buttonStyle(.plain)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: selected.id)
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .modifier(UAPPChangelogApplicationActivity(isActive: $isApplicationActive))
        .task(id: autoplayIdentity) {
            guard autoplayEnabled else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(configuration.interval)) } catch { return }
                guard !Task.isCancelled, let next = presentation.nextImage(after: selectionBinding.wrappedValue) else { return }
                select(next)
            }
        }
    }

    private var autoplayEnabled: Bool {
        UAPPChangelogAutoplay.isEnabled(
            configuration: configuration, imageCount: images.count, isVisible: isVisible,
            isApplicationActive: isApplicationActive, voiceOver: voiceOver, reduceMotion: reduceMotion
        )
    }

    private var selectedIndex: Int {
        images.firstIndex { $0.id == selected?.id } ?? 0
    }

    private var indicatorProgress: CGFloat {
        #if os(iOS)
        if #available(iOS 17, *), !reduceMotion {
            return scrollProgress
        }
        #endif
        return CGFloat(selectedIndex)
    }

    private var autoplayIdentity: String {
        "\(autoplayEnabled)-\(configuration.interval)-\(selection)-\(images)"
    }

    @ViewBuilder private var pages: some View {
        #if os(iOS)
        if #available(iOS 17, *) {
            UAPPChangelogParallaxCarousel(
                items: images, selection: selectionBinding, progress: $scrollProgress, onOpen: onOpen
            )
        } else {
            TabView(selection: selectionBinding) {
                ForEach(images) { item in
                    UAPPChangelogImage(item: item)
                        .padding(.horizontal, 3)
                        .onTapGesture(perform: onOpen)
                        .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .aspectRatio(40.0 / 21.0, contentMode: .fit)
        }
        #else
        if let selected {
            UAPPChangelogImage(item: selected).onTapGesture(perform: onOpen)
        }
        #endif
    }

    private func select(_ id: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { selection = id }
    }
}

struct UAPPChangelogTextItems: View {
    let items: [UAPPChangelogItem]
    var lineLimit: Int?
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(UAPPChangelogCategory.allCases, id: \.self) { category in
                let group = items.filter { $0.section.category == category }
                if !group.isEmpty {
                    UAPPChangelogCategoryLabel(category: category)
                    ForEach(group) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Circle()
                                .fill(.tint)
                                .frame(width: 5, height: 5)
                                .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 2 }
                                .accessibilityHidden(true)
                            UAPPChangelogTranslatedText(text: item.section.bodyMarkdown, lineLimit: lineLimit)
                                .font(.subheadline)
                        }
                        .padding(.leading, 4)
                    }
                }
            }
        }
    }
}

struct UAPPChangelogDetailScreen: View {
    let entry: UAPPChangelogEntry
    var accentColor: Color?
    var translationCache: UAPPReviewTranslationCache?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.uappChangelogTranslationCache) private var inheritedCache

    var body: some View {
        let presentation = UAPPChangelogPresentation(entry: entry)
        let palette = theme.resolved(for: colorScheme)
        let tint = accentColor ?? palette.accent ?? .accentColor
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                UAPPChangelogHeading(entry: entry, showsVersion: false)
                if !presentation.description.isEmpty {
                    UAPPChangelogTranslatedText(text: presentation.description)
                }
                ForEach(presentation.items) { item in
                    if item.section.imageURL != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            UAPPChangelogImage(item: item)
                            UAPPChangelogItemText(item: item)
                        }
                    } else if entry.descriptionMarkdown != nil {
                        UAPPChangelogItemText(item: item)
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(palette.background.ignoresSafeArea())
        .foregroundStyle(palette.primaryText)
        .environment(\.uappChangelogTranslationCache, translationCache ?? inheritedCache)
        .navigationTitle(entry.version.map {
            String(format: uappLocalized("changelog.detail_title", languageIdentifier: locale.identifier), $0)
        } ?? entry.title)
        .tint(tint)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(tint)
                }
                .tint(tint)
                .accessibilityLabel(Text(verbatim: uappLocalized("changelog.back")))
            }
        }
    }
}

/// A fixture prevents image requests while rendering deterministic UI tests.
enum UAPPChangelogImageFixture: Sendable {
    case loading, success, failure

    var phase: AsyncImagePhase {
        switch self {
        case .loading: .empty
        case .success: .success(Image(systemName: "photo"))
        case .failure: .failure(URLError(.cannotLoadFromNetwork))
        }
    }
}

private struct UAPPChangelogImageFixtureKey: EnvironmentKey {
    static let defaultValue: UAPPChangelogImageFixture? = nil
}

extension EnvironmentValues {
    var uappChangelogImageFixture: UAPPChangelogImageFixture? {
        get { self[UAPPChangelogImageFixtureKey.self] }
        set { self[UAPPChangelogImageFixtureKey.self] = newValue }
    }
}

struct UAPPChangelogDetailNavigation: ViewModifier {
    let isEnabled: Bool
    let isPresented: Binding<Bool>
    let destination: UAPPChangelogDetailScreen?

    func body(content: Content) -> some View {
        if isEnabled {
            content.navigationDestination(isPresented: isPresented) {
                if let destination {
                    destination
                }
            }
        } else {
            content
        }
    }
}
#endif
