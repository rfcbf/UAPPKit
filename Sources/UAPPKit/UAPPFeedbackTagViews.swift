import Foundation

extension UAPPFeedbackTag {
    /// Componentes RGB (0...1) da cor da etiqueta.
    /// Aceita `#RRGGBB`, `RRGGBB` e a forma curta `#RGB`, com espaços nas pontas e letras em qualquer caixa.
    /// Valores vazios ou inválidos retornam `nil`, e a tela usa a cor neutra do tema.
    static func rgbComponents(hex: String?) -> (red: Double, green: Double, blue: Double)? {
        guard var value = hex?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }
        guard value.count == 6, value.allSatisfy(\.isHexDigit), let rgb = UInt32(value, radix: 16) else {
            return nil
        }
        return (
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

#if canImport(SwiftUI)
import SwiftUI

extension UAPPFeedbackTag {
    /// Cor da etiqueta, ou `fallback` quando o servidor não envia uma cor válida.
    func displayColor(fallback: Color) -> Color {
        guard let rgb = Self.rgbComponents(hex: color) else { return fallback }
        return Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }
}

/// Selo somente leitura de uma etiqueta: ponto na cor da etiqueta e nome no texto principal do tema,
/// para manter o contraste em claro e escuro mesmo com cores claras como amarelo.
struct UAPPFeedbackTagChip: View {
    let tag: UAPPFeedbackTag
    let fallbackColor: Color
    let textColor: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let color = tag.displayColor(fallback: fallbackColor)
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(verbatim: tag.name)
                .foregroundStyle(textColor)
        }
        .font(.caption.weight(.medium))
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(colorScheme == .dark ? 0.24 : 0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(colorScheme == .dark ? 0.5 : 0.35), lineWidth: 1))
    }
}

/// Prioridade e etiquetas de uma requisição, quebrando em linhas quando não cabem.
/// Não mostra nada quando a requisição não tem prioridade nem etiquetas.
struct UAPPFeedbackTagList: View {
    let tags: [UAPPFeedbackTag]
    var priority: UAPPFeedbackPriority?
    let languageIdentifier: String
    @Environment(\.uappTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    init(tags: [UAPPFeedbackTag], priority: UAPPFeedbackPriority? = nil, languageIdentifier: String) {
        self.tags = tags.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.priority = priority
        self.languageIdentifier = languageIdentifier
    }

    var body: some View {
        if priority != nil || !tags.isEmpty {
            let palette = theme.resolved(for: colorScheme)
            UAPPFlowLayout(spacing: 6) {
                if let priority {
                    UAPPFeedbackPriorityBadge(priority: priority, languageIdentifier: languageIdentifier)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: Self.priorityAccessibilityLabel(
                            priority,
                            languageIdentifier: languageIdentifier
                        )))
                }
                ForEach(tags) { tag in
                    UAPPFeedbackTagChip(
                        tag: tag,
                        fallbackColor: palette.secondaryText,
                        textColor: palette.primaryText
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: Self.tagAccessibilityLabel(
                        tag,
                        languageIdentifier: languageIdentifier
                    )))
                }
            }
        }
    }

    static func tagAccessibilityLabel(_ tag: UAPPFeedbackTag, languageIdentifier: String) -> String {
        String(format: uappLocalized("feedback.tag_accessibility", languageIdentifier: languageIdentifier), tag.name)
    }

    static func priorityAccessibilityLabel(_ priority: UAPPFeedbackPriority, languageIdentifier: String) -> String {
        String(
            format: uappLocalized("feedback.priority_accessibility", languageIdentifier: languageIdentifier),
            priority.title(languageIdentifier: languageIdentifier)
        )
    }
}

/// Layout que coloca os selos lado a lado e quebra para a linha seguinte quando falta espaço.
struct UAPPFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, maxWidth: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.init(width: bounds.width, height: nil))
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: .init(width: min(size.width, bounds.width), height: size.height)
                )
                x += min(size.width, bounds.width) + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.init(width: maxWidth.isFinite ? maxWidth : nil, height: nil))
            let width = min(size.width, maxWidth)
            let proposedWidth = current.indices.isEmpty ? width : current.width + spacing + width
            if !current.indices.isEmpty, proposedWidth > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? width : current.width + spacing + width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

#Preview("Prioridade e etiquetas") {
    VStack(alignment: .leading, spacing: 16) {
        UAPPFeedbackTagList(
            tags: [
                .init(id: "1", name: "Relatórios", color: "#2F80ED"),
                .init(id: "2", name: "Exportação", color: "#F2C94C"),
                .init(id: "3", name: "Sem cor"),
                .init(id: "4", name: "Cor inválida", color: "azul")
            ],
            priority: .important,
            languageIdentifier: "pt-BR"
        )
        UAPPFeedbackTagList(
            tags: [.init(id: "5", name: "Acessibilidade", color: "#27AE60")],
            languageIdentifier: "en"
        )
        UAPPFeedbackTagList(tags: [], priority: .urgent, languageIdentifier: "pt-BR")
    }
    .padding()
    .frame(width: 320)
}

#Preview("Card com prioridade e etiquetas") {
    let item = UAPPFeedbackItem(
        id: "preview", title: "Exportar relatórios em planilha",
        body: "Seria útil baixar o resumo mensal para compartilhar com a equipe.",
        voteCount: 12, likeCount: 0, commentCount: 3, category: .feature, priority: 3,
        authorName: "Ana",
        tags: [
            .init(id: "1", name: "Relatórios", color: "#2F80ED"),
            .init(id: "2", name: "Exportação", color: "#EB5757")
        ]
    )
    let status = UAPPRoadmapColumn.Status(id: "planned", key: "planned", name: "Planejado", position: 1)
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            UAPPFeedbackCard(
                item: item, status: status, accentColor: .blue,
                onReact: {}, onProfile: {}, onDetail: {}
            )
            UAPPFeedbackCard(
                item: item, status: status, accentColor: .blue, layout: .roadmap,
                onReact: {}, onProfile: {}, onDetail: {}
            )
        }
        .padding()
    }
}

#Preview("Detalhe com prioridade e etiquetas") {
    NavigationStack {
        UAPPFeedbackDetailScreen(
            client: UAPPClient(configuration: UAPPConfiguration(projectId: "exemplo")),
            item: UAPPFeedbackItem(
                id: "preview", title: "Exportar relatórios em planilha",
                body: "Seria útil baixar o resumo mensal para compartilhar com a equipe.",
                voteCount: 12, likeCount: 0, commentCount: 0, category: .feature, priority: 6,
                authorName: "Ana",
                tags: [
                    .init(id: "1", name: "Relatórios", color: "#2F80ED"),
                    .init(id: "2", name: "Exportação", color: "#F2C94C"),
                    .init(id: "3", name: "Sem cor")
                ]
            ),
            testingComments: [],
            isLoading: false
        )
    }
}
#endif
