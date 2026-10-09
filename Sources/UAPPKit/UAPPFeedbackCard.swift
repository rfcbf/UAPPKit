import SwiftUI

struct UAPPFeedbackCard: View {
    enum Layout {
        /// Autor e voto no topo; status e comentários abaixo do conteúdo.
        case feedback
        /// Tipo e voto no topo; autor abaixo do conteúdo, sem status nem comentários.
        case roadmap
    }

    let item: UAPPFeedbackItem
    let status: UAPPRoadmapColumn.Status?
    let accentColor: Color
    var isReacting = false
    var layout: Layout = .feedback
    let onReact: () -> Void
    let onProfile: () -> Void
    let onDetail: () -> Void
    @Environment(\.uappTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    private var authorName: String {
        let name = item.authorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? uappLocalized("comments.community", languageIdentifier: selectedLanguage) : name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 14) {
            switch layout {
            case .feedback:
                HStack(spacing: 10) {
                    authorButton
                    Spacer(minLength: 8)
                    voteButton
                }
                textContent
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        statusBadge.allowsHitTesting(false)
                        priorityBadge.allowsHitTesting(false)
                        commentsButton
                        Spacer(minLength: 0)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        statusBadge.allowsHitTesting(false)
                        priorityBadge.allowsHitTesting(false)
                        commentsButton
                    }
                }
            case .roadmap:
                // O status já é a seção do Roadmap: o card compacto mostra tipo, conteúdo e autor.
                HStack(alignment: .center, spacing: 10) {
                    categoryLabel.allowsHitTesting(false)
                    priorityBadge.allowsHitTesting(false)
                    Spacer(minLength: 8)
                    voteButton
                }
                textContent
                authorButton
            }
        }
        .padding(.vertical, isCompact ? 4 : 10)
        .background {
            Button(action: onDetail) {
                Rectangle().fill(.clear)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: item.title))
        }
    }

    private var authorButton: some View {
        Button(action: onProfile) {
            HStack(spacing: 10) {
                UAPPCachedImage(url: item.authorAvatarURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().scaledToFit()
                            .foregroundStyle(palette.secondaryText)
                    }
                }
                .frame(width: isCompact ? 22 : 30, height: isCompact ? 22 : 30)
                .clipShape(Circle())
                .accessibilityHidden(true)
                Text(verbatim: authorName)
                    .font(isCompact ? .footnote.weight(.medium) : .subheadline.weight(.medium))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
            .frame(minHeight: isCompact ? 32 : 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: authorName))
    }

    private var voteButton: some View {
        Button(action: onReact) {
            HStack(spacing: 5) {
                Image(systemName: item.viewerVoted ? "arrow.up.circle.fill" : "arrow.up.circle")
                Text(verbatim: item.voteCount.formatted())
            }
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(accentColor)
            .fixedSize()
            .padding(.horizontal, 8)
            .frame(minWidth: 52, minHeight: 28)
            .background(accentColor.opacity(item.viewerVoted ? 0.16 : 0.08), in: Capsule())
            .frame(minHeight: isCompact ? 32 : 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isReacting)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: uappLocalizedFormat("feedback.votes_count", item.voteCount)))
        .accessibilityAddTraits(item.viewerVoted ? [.isSelected] : [])
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
            UAPPFeedbackTranslatedText(text: item.title)
                .font(.headline)
                .foregroundStyle(palette.primaryText)
            if let body = item.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                UAPPFeedbackTranslatedText(text: body, lineLimit: 3)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .allowsHitTesting(false)
    }

    private var isCompact: Bool {
        layout == .roadmap
    }

    /// Badge do tipo da demanda; itens publicados sem tipo exibem um aviso neutro.
    private var categoryLabel: some View {
        UAPPFeedbackCategoryBadge(category: item.category, languageIdentifier: selectedLanguage)
    }

    /// Selo da prioridade definida pela equipe; requisições sem prioridade não mostram nada.
    @ViewBuilder
    private var priorityBadge: some View {
        if let priority = UAPPFeedbackPriority(value: item.priority) {
            UAPPFeedbackPriorityBadge(priority: priority, languageIdentifier: selectedLanguage)
        }
    }

    private var statusBadge: some View {
        UAPPStatusBadge(status: status)
    }

    private var commentsButton: some View {
        Button(action: onDetail) {
            HStack(spacing: 4) {
                Image(systemName: "bubble.right")
                Text(verbatim: item.commentCount.formatted())
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(palette.secondaryText)
            .accessibilityElement(children: .ignore)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: uappLocalizedFormat("feedback.comments_count", item.commentCount)))
    }
}

enum UAPPFeedbackStatusStyle {
    static func color(for status: UAPPRoadmapColumn.Status?) -> Color {
        if let hex = status?.color, let color = Color(hex: hex) {
            return color
        }
        switch status?.key {
        case "reviewing": return Color(red: 0.49, green: 0.35, blue: 0.12)
        case "planned": return Color(red: 0.32, green: 0.36, blue: 0.63)
        case "in_progress": return Color(red: 0.16, green: 0.40, blue: 0.65)
        case "in_test": return Color(red: 0.52, green: 0.29, blue: 0.58)
        case "shipped", "delivered", "done": return Color(red: 0.17, green: 0.43, blue: 0.30)
        default: return Color(red: 0.38, green: 0.42, blue: 0.46)
        }
    }
}

/// Badge com ícone e cor por tipo de demanda (bug, feature, melhoria e dúvida).
struct UAPPFeedbackCategoryBadge: View {
    let category: UAPPFeedbackCategory?
    let languageIdentifier: String

    var body: some View {
        let color = Self.color(for: category)
        Label {
            Text(verbatim: uappLocalized(
                category.map { "category.\($0.rawValue)" } ?? "category.unset",
                languageIdentifier: languageIdentifier
            ))
            .italic(category == nil)
        } icon: {
            Image(systemName: Self.symbol(for: category))
        }
        .labelStyle(UAPPFeedbackCategoryLabelStyle())
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.14), in: Capsule())
    }

    static func symbol(for category: UAPPFeedbackCategory?) -> String {
        switch category {
        case .bug: "ladybug.fill"
        case .feature: "sparkles"
        case .improvement: "wand.and.stars"
        case .question: "questionmark.circle.fill"
        case nil: "tag"
        }
    }

    static func color(for category: UAPPFeedbackCategory?) -> Color {
        switch category {
        case .bug: .red
        case .feature: .indigo
        case .improvement: .teal
        case .question: .orange
        case nil: .gray
        }
    }
}

private struct UAPPFeedbackCategoryLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.accessibilityHidden(true)
            configuration.title
        }
    }
}
