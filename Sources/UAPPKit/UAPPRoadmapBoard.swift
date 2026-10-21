#if os(macOS) && canImport(SwiftUI)
import SwiftUI

/// Roadmap no Mac em quadro: uma coluna por status, lado a lado, dividindo a largura da janela.
/// Só quando as colunas não cabem com a largura mínima o quadro rola na horizontal. Cada coluna
/// rola na vertical e mostra quantos itens tem.
struct UAPPRoadmapBoard<Card: View>: View {
    static var minimumColumnWidth: CGFloat {
        280
    }

    static var maximumColumnWidth: CGFloat {
        560
    }

    static var spacing: CGFloat {
        14
    }

    static var padding: CGFloat {
        16
    }

    /// Largura de cada coluna para `count` colunas em `available` pontos.
    static func columnWidth(available: CGFloat, count: Int) -> CGFloat {
        guard count > 0 else { return minimumColumnWidth }
        let usable = available - padding * 2 - spacing * CGFloat(count - 1)
        return min(max(usable / CGFloat(count), minimumColumnWidth), maximumColumnWidth)
    }

    let columns: [UAPPRoadmapColumn]
    let selectedId: String?
    let accentColor: Color
    @ViewBuilder let card: (UAPPFeedbackItem, UAPPRoadmapColumn.Status) -> Card
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = Self.columnWidth(available: proxy.size.width, count: columns.count)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Self.spacing) {
                    ForEach(columns, id: \.status.key) { column in
                        boardColumn(column)
                            .frame(width: width, height: max(240, proxy.size.height - Self.padding * 2), alignment: .top)
                    }
                }
                .padding(Self.padding)
            }
        }
    }

    private func boardColumn(_ column: UAPPRoadmapColumn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(verbatim: uappFeedbackStatusTitle(column.status))
                    .font(.headline)
                    .lineLimit(1)
                Text(verbatim: "\(column.items.count)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(palette.separator.opacity(0.35), in: Capsule())
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ScrollView {
                LazyVStack(spacing: 10) {
                    if column.items.isEmpty {
                        UAPPFeedbackCompactNoResultsRow()
                            .padding(.horizontal, 12)
                            .uappCardSurface(palette)
                    }
                    ForEach(column.items) { item in
                        card(item, column.status)
                            .padding(14)
                            .uappCardSurface(palette)
                            .overlay {
                                if item.id == selectedId {
                                    RoundedRectangle(cornerRadius: UAPPSurface.largeCornerRadius, style: .continuous)
                                        .strokeBorder(accentColor, lineWidth: 2)
                                }
                            }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
        .background(
            palette.primaryText.opacity(colorScheme == .dark ? 0.05 : 0.04),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

extension View {
    /// Detalhe do item escolhido no quadro, em um painel à direita (inspetor) a partir do
    /// macOS 14; no macOS 13, em uma sheet.
    @ViewBuilder
    func uappRoadmapDetailPanel(
        selection: Binding<UAPPFeedbackItem?>,
        @ViewBuilder detail: @escaping (UAPPFeedbackItem) -> some View
    ) -> some View {
        let isPresented = Binding(
            get: { selection.wrappedValue != nil },
            set: {
                if !$0 {
                    selection.wrappedValue = nil
                }
            }
        )
        if #available(macOS 14, *) {
            inspector(isPresented: isPresented) {
                if let item = selection.wrappedValue {
                    detail(item)
                        .id(item.id)
                        .environment(\.uappIsSplitDetail, true)
                        .inspectorColumnWidth(min: 360, ideal: 440, max: 620)
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button { selection.wrappedValue = nil } label: {
                                    Label(uappLocalized("navigation.close"), systemImage: "sidebar.trailing")
                                }
                                .keyboardShortcut(.cancelAction)
                                .help(Text(verbatim: uappLocalized("navigation.close")))
                            }
                        }
                }
            }
        } else {
            sheet(item: selection) { item in
                detail(item)
                    .environment(\.uappIsSplitDetail, true)
                    .uappMacSheetFrame(width: 560, height: 640)
            }
        }
    }
}
#endif
