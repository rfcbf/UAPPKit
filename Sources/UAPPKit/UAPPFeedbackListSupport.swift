#if canImport(SwiftUI)
import SwiftUI

/// Filtros por categoria/status e ordenação compartilhados por Feedback e Roadmap.
struct UAPPFeedbackControls: View {
    let statuses: [UAPPRoadmapColumn.Status]
    @Binding var category: UAPPFeedbackCategory?
    @Binding var statusId: String?
    @Binding var sort: UAPPFeedbackSort
    let accentColor: Color
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.uappTheme) private var theme

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    private var hasFilters: Bool {
        category != nil || statusId != nil
    }

    private var layout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        } else {
            AnyLayout(HStackLayout(spacing: 16))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            layout {
                Menu {
                    Picker(selection: $category) {
                        Text(verbatim: uappLocalized("feedback.filter.all_categories"))
                            .tag(UAPPFeedbackCategory?.none)
                        ForEach(UAPPFeedbackCategory.allCases, id: \.self) { category in
                            Text(verbatim: uappLocalized("category.\(category.rawValue)"))
                                .tag(Optional(category))
                        }
                    } label: {
                        Text(verbatim: uappLocalized("feedback.field.type"))
                    }
                    UAPPStatusFilterOptions(statuses: statuses, selection: $statusId)
                    if hasFilters {
                        Button(uappLocalized("feedback.filter.clear")) {
                            category = nil
                            statusId = nil
                        }
                    }
                } label: {
                    Label(
                        uappLocalized("feedback.filter.title"),
                        systemImage: hasFilters
                            ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
                    )
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                }
                Menu {
                    Picker(selection: $sort) {
                        ForEach(UAPPFeedbackSort.allCases, id: \.self) { sort in
                            Text(verbatim: uappLocalized(sort.titleKey)).tag(sort)
                        }
                    } label: {
                        Text(verbatim: uappLocalized("feedback.sort.title"))
                    }
                } label: {
                    Label(uappLocalized(sort.titleKey), systemImage: "arrow.up.arrow.down")
                }
                .accessibilityLabel(Text(verbatim: uappLocalized("feedback.sort.title")))
            }
            .font(.subheadline.weight(.medium))
            if hasFilters {
                Text(verbatim: [
                    category.map { uappLocalized("category.\($0.rawValue)") },
                    statuses.first { $0.id == statusId }.map { uappFeedbackStatusTitle($0) }
                ].compactMap(\.self).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
        }
        // No Mac, filtro e ordenação na cor do sistema, como os demais controles da janela.
        .tint(Color.uappToolbarIcon(accentColor))
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(palette.background)
    }
}

/// Mascote e mensagem exibidos quando busca/filtros não encontram itens.
struct UAPPFeedbackNoResults: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme

    var body: some View {
        VStack(spacing: 14) {
            UAPPMascotIllustration(state: .emptyFeedback)
            Text(verbatim: uappLocalized("feedback.filter.empty"))
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.resolved(for: colorScheme).secondaryText)
        }
    }
}

/// Linha de lista com o estado sem resultados.
struct UAPPFeedbackNoResultsRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme

    var body: some View {
        UAPPFeedbackNoResults()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .listRowBackground(theme.resolved(for: colorScheme).cardBackground)
            .listRowSeparator(.hidden)
    }
}

/// Versão em linha do estado sem resultados: mascote pequeno à esquerda e
/// texto de até duas linhas à direita, para colunas vazias do Roadmap.
struct UAPPFeedbackCompactNoResultsRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme

    var body: some View {
        let palette = theme.resolved(for: colorScheme)
        HStack(spacing: 14) {
            UAPPMascotIllustration(state: .emptyFeedback, width: 40)
                .accessibilityHidden(true)
            Text(verbatim: uappLocalized("feedback.filter.empty"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .listRowBackground(palette.cardBackground)
        .listRowSeparator(.hidden)
    }
}

/// Detalhes do item, perfil público do autor e alerta de falha no voto.
struct UAPPFeedbackItemNavigation: ViewModifier {
    let client: UAPPClient
    let accentColor: Color
    let statuses: [UAPPRoadmapColumn.Status]
    @Binding var selectedFeedback: UAPPFeedbackItem?
    @Binding var selectedAuthor: UAPPFeedbackItem?
    @Binding var reactionError: String?
    let onUpdate: (UAPPFeedbackItem) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier

    func body(content: Content) -> some View {
        detailNavigation(content)
            .uappToast(message: Binding(
                get: { reactionError.map { uappLocalized($0) } },
                set: {
                    if $0 == nil {
                        reactionError = nil
                    }
                }
            ), title: uappLocalized("detail.reaction_error"))
            .sheet(item: $selectedAuthor) { author in
                UAPPUserScreen(publicIdentity: UAPPIdentity(
                    userId: author.id,
                    displayName: author.authorName ?? uappLocalized("comments.community"),
                    avatarURL: author.authorAvatarURL
                ), theme: theme, client: client, feedbackId: author.id)
                    .environment(\.locale, Locale(identifier: selectedLanguage))
                    .uappPresentationBackground(theme.resolved(for: colorScheme).background)
            }
    }

    /// No Mac o detalhe aparece ao lado da lista (`UAPPFeedbackSplitView`); nos demais
    /// sistemas, é empilhado pela navegação.
    private func detailNavigation(_ content: Content) -> some View {
        #if os(macOS)
        content
        #else
        content
            .navigationDestination(isPresented: Binding(
                get: { selectedFeedback != nil },
                set: {
                    if !$0 {
                        selectedFeedback = nil
                    }
                }
            )) {
                if let selectedFeedback {
                    UAPPFeedbackDetailScreen(
                        client: client, item: selectedFeedback, accentColor: accentColor,
                        status: statuses.first { $0.id == selectedFeedback.statusId },
                        onUpdate: onUpdate
                    )
                }
            }
        #endif
    }
}

enum UAPPFeedbackVoting {
    /// Alterna o voto com atualização imediata e restaura o item em caso de erro.
    /// Retorna `false` quando a requisição falha.
    @MainActor
    static func toggle(
        _ original: UAPPFeedbackItem, client: UAPPClient,
        replace: (UAPPFeedbackItem) -> Void
    ) async -> Bool {
        let enabled = !original.viewerVoted
        replace(original.settingVote(enabled: enabled))
        do {
            try await client.setReaction(itemId: original.id, kind: .vote, enabled: enabled)
            return true
        } catch {
            replace(original)
            return false
        }
    }
}

/// Estado exibido quando a carga pública de Feedback/Roadmap falha.
struct UAPPFeedbackLoadFailure: Equatable {
    let messageKey: String
    let mascotState: UAPPMascotState
    /// Projeto indisponível: o conteúdo já carregado deve ser descartado.
    let clearsContent: Bool

    /// `nil` quando uma atualização silenciosa falha e há conteúdo para preservar.
    static func make(for error: any Error, silently: Bool, hasContent: Bool) -> UAPPFeedbackLoadFailure? {
        if case UAPPKitError.http(status: 403, _) = error {
            return .init(messageKey: "unavailable.content", mascotState: .unavailable, clearsContent: true)
        }
        guard !silently || !hasContent else { return nil }
        return .init(messageKey: "unavailable.load_error", mascotState: .connectionError, clearsContent: false)
    }
}

struct UAPPFeedbackListSpacing: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            #if os(macOS)
            // Na coluna da lista, o estilo de barra lateral do Mac seria aplicado por padrão.
            content.listStyle(.inset)
            #else
            if #available(iOS 17, *) {
                content.contentMargins(.top, 0, for: .scrollContent)
            } else {
                content.listStyle(.plain)
            }
            #endif
        } else {
            content
        }
    }
}
#endif
