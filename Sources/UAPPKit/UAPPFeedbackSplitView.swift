#if canImport(SwiftUI)
import SwiftUI

/// Lista de Feedback ou Roadmap com o detalhe ao lado no Mac, como em Mail. No iPhone e no iPad a
/// lista é devolvida sem mudança e o detalhe continua empilhado pela navegação.
///
/// No Mac a coluna da lista não é uma barra lateral (`NavigationSplitView`), que o sistema
/// pintaria com material próprio até a barra de ferramentas, deixando a barra com duas cores.
/// A largura da lista abre em `UAPPListColumnWidth.standard` e é lembrada ao arrastar o divisor.
struct UAPPFeedbackSplitView<Sidebar: View>: View {
    let client: UAPPClient
    let accentColor: Color
    let statuses: [UAPPRoadmapColumn.Status]
    @Binding var selectedFeedback: UAPPFeedbackItem?
    let onUpdate: (UAPPFeedbackItem) -> Void
    @ViewBuilder let list: () -> Sidebar
    #if os(macOS)
    @AppStorage(UAPPListColumnWidth.storageKey) private var listWidth = Double(UAPPListColumnWidth.standard)
    #endif

    var body: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            list()
                .frame(width: UAPPListColumnWidth.clamped(listWidth))
            UAPPColumnDivider(width: $listWidth)
            UAPPFeedbackSplitDetail(
                client: client, accentColor: accentColor, statuses: statuses,
                selectedFeedback: selectedFeedback, onUpdate: onUpdate
            )
            .frame(minWidth: 380, maxWidth: .infinity)
        }
        #else
        list()
        #endif
    }
}

#if os(macOS)
/// Largura da coluna da lista no Mac: abre estreita, como a lista de mensagens do Mail.
enum UAPPListColumnWidth {
    static let storageKey = "UAPPKit.listColumnWidth"
    static let standard: CGFloat = 400
    static let range: ClosedRange<CGFloat> = 300 ... 560

    static func clamped(_ width: Double) -> CGFloat {
        min(max(CGFloat(width), range.lowerBound), range.upperBound)
    }
}

/// Divisor arrastável entre a lista e o detalhe, com o cursor de redimensionar do sistema.
struct UAPPColumnDivider: View {
    @Binding var width: Double
    @State private var dragStart: Double?

    var body: some View {
        Divider()
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .overlay {
                // Área de arrasto mais larga que a linha, sem mudar o desenho.
                Color.clear
                    .frame(width: 9)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { value in
                                let start = dragStart ?? width
                                dragStart = start
                                width = Double(UAPPListColumnWidth.clamped(start + value.translation.width))
                            }
                            .onEnded { _ in dragStart = nil }
                    )
            }
            .accessibilityHidden(true)
    }
}

/// Coluna de detalhe: o item escolhido ou um convite para escolher um item da lista.
private struct UAPPFeedbackSplitDetail: View {
    let client: UAPPClient
    let accentColor: Color
    let statuses: [UAPPRoadmapColumn.Status]
    let selectedFeedback: UAPPFeedbackItem?
    let onUpdate: (UAPPFeedbackItem) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme

    var body: some View {
        let palette = theme.resolved(for: colorScheme)
        if let selectedFeedback {
            UAPPFeedbackDetailScreen(
                client: client, item: selectedFeedback, accentColor: accentColor,
                status: statuses.first { $0.id == selectedFeedback.statusId },
                onUpdate: onUpdate
            )
            // Outro item recria a tela, com comentários e rascunho próprios.
            .id(selectedFeedback.id)
            .environment(\.uappIsSplitDetail, true)
        } else {
            VStack(spacing: 14) {
                UAPPMascotIllustration(state: .emptyFeedback, width: 120)
                    .accessibilityHidden(true)
                Text(verbatim: uappLocalized("feedback.select_prompt"))
                    .font(.headline)
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background)
        }
    }
}
#endif
#endif
