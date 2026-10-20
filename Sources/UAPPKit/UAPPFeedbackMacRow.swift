#if os(macOS) && canImport(SwiftUI)
import SwiftUI

/// Linha da lista de Feedback no Mac, no estilo da lista de mensagens do Mail: autor e data,
/// título, descrição e, embaixo, status, prioridade, comentários e o voto na mesma cápsula do
/// iPhone. O item escolhido fica destacado e o item sob o cursor, levemente realçado.
struct UAPPFeedbackMacRow: View {
    let item: UAPPFeedbackItem
    let status: UAPPRoadmapColumn.Status?
    let accentColor: Color
    let isSelected: Bool
    var isReacting = false
    let onReact: () -> Void
    let onProfile: () -> Void
    let onDetail: () -> Void
    @State private var isHovered = false
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                authorButton
                Spacer(minLength: 8)
                if let date = item.createdAt {
                    Text(date, format: .dateTime.day().month(.abbreviated))
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
            }
            UAPPFeedbackTranslatedText(text: item.title, lineLimit: 2)
                .font(.headline)
                .foregroundStyle(palette.primaryText)
            if let body = item.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                UAPPFeedbackTranslatedText(text: body, lineLimit: 2)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }
            if !item.tags.isEmpty {
                UAPPFeedbackTagList(tags: item.tags, languageIdentifier: selectedLanguage)
            }
            HStack(spacing: 8) {
                UAPPStatusBadge(status: status)
                    .lineLimit(1)
                    .fixedSize()
                if let priority = UAPPFeedbackPriority(value: item.priority) {
                    UAPPFeedbackPriorityBadge(priority: priority, languageIdentifier: selectedLanguage)
                        .lineLimit(1)
                        .fixedSize()
                }
                Spacer(minLength: 8)
                Label {
                    Text(verbatim: item.commentCount.formatted())
                } icon: {
                    Image(systemName: "bubble.right")
                }
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .monospacedDigit()
                .fixedSize()
                .foregroundStyle(palette.secondaryText)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: uappLocalizedFormat("feedback.comments_count", item.commentCount)))
                voteButton
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture(perform: onDetail)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: Text(verbatim: item.title), onDetail)
    }

    private var rowBackground: Color {
        if isSelected {
            return accentColor.opacity(colorScheme == .dark ? 0.24 : 0.14)
        }
        return isHovered ? palette.primaryText.opacity(0.05) : .clear
    }

    private var voteButton: some View {
        Button(action: onReact) {
            UAPPMacVoteLabel(count: item.voteCount, isVoted: item.viewerVoted, accentColor: accentColor)
        }
        .buttonStyle(.plain)
        .uappVoteBurst(isSelected: item.viewerVoted, tint: accentColor)
        .disabled(isReacting)
        .help(Text(verbatim: uappLocalizedFormat("feedback.votes_count", item.voteCount)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: uappLocalizedFormat("feedback.votes_count", item.voteCount)))
        .accessibilityAddTraits(item.viewerVoted ? [.isSelected] : [])
    }

    private var authorButton: some View {
        Button(action: onProfile) {
            HStack(spacing: 6) {
                UAPPFeedbackAvatar(name: authorName, url: item.authorAvatarURL, size: 20)
                    .accessibilityHidden(true)
                Text(verbatim: authorName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: authorName))
    }
}

/// Voto no Mac: preenchido com a cor de destaque quando a pessoa votou, para ser reconhecido de
/// longe; neutro, na cor do sistema e com contorno, quando ainda não votou.
struct UAPPMacVoteLabel: View {
    let count: Int
    let isVoted: Bool
    let accentColor: Color
    @Environment(\.uappTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = theme.resolved(for: colorScheme)
        HStack(spacing: 5) {
            Image(systemName: isVoted ? "arrow.up.circle.fill" : "arrow.up.circle")
            Text(verbatim: count.formatted())
        }
        .font(.caption.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(isVoted ? palette.buttonText : palette.primaryText)
        .fixedSize()
        .padding(.horizontal, 9)
        .frame(minWidth: 48, minHeight: 24)
        .background(isVoted ? accentColor : palette.primaryText.opacity(0.06), in: Capsule())
        .overlay {
            if !isVoted {
                Capsule().strokeBorder(palette.separator)
            }
        }
        .contentShape(Capsule())
    }
}
#endif
