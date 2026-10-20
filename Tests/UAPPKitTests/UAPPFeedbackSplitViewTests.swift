import SwiftUI
import Testing
@testable import UAPPKit
#if os(macOS)
import AppKit
#endif

@MainActor
struct UAPPFeedbackSplitViewTests {
    private let item = UAPPFeedbackItem(
        id: "split-item", title: "Exportar relatório", body: "Em planilha",
        voteCount: 2, likeCount: 0, commentCount: 0
    )

    @Test("Lista e detalhe são montados com e sem item escolhido")
    func splitRendersSelectionStates() async {
        let client = makeClient { _ in response(#"{"ok":true,"comments":[]}"#) }
        for selected in [nil, item] {
            await render(UAPPFeedbackSplitView(
                client: client, accentColor: .purple, statuses: [],
                selectedFeedback: .constant(selected), onUpdate: { _ in }
            ) {
                List { Text("Lista") }
            })
        }
    }

    @Test("Detalhe ao lado da lista é montado sem botão de voltar")
    func splitDetailRenders() async {
        let client = makeClient { _ in response(#"{"ok":true,"comments":[]}"#) }
        await renderInNavigationStack(
            UAPPFeedbackDetailScreen(client: client, item: item).environment(\.uappIsSplitDetail, true)
        )
    }

    @Test("Comandos da lista são montados com e sem o botão de novo feedback")
    func listCommandsRender() async {
        var refreshed = false
        for showsNewFeedback in [false, true] {
            await renderInNavigationStack(Text("Lista").modifier(UAPPMacFeedbackCommands(
                showsNewFeedback: showsNewFeedback,
                accentColor: .purple,
                isRefreshing: showsNewFeedback,
                onNewFeedback: {},
                onRefresh: { refreshed = true }
            )))
        }
        #expect(!refreshed)
    }

    @Test("Sheets do Mac recebem tamanho próprio sem mudar o conteúdo")
    func macSheetFrameRenders() async {
        await render(Text("Sheet").uappMacSheetFrame(width: 400, height: 300))
    }

    #if os(macOS)
    @Test("Na janela do pacote, fechar fecha a janela; fora dela, usa o dismiss")
    func screenCloserClosesPackageWindow() async throws {
        let presenter = UAPPMacWindowPresenter()
        presenter.ordersWindowsFront = false
        defer { presenter.closeAll() }
        presenter.present(.about, content: CloserProbe())
        for _ in 0 ..< 100 where presenter.windows[.about] != nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(presenter.windows[.about] == nil)

        let other = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        #expect(!UAPPMacWindowPresenter.isPackageWindow(other))
        #expect(!UAPPMacWindowPresenter.isPackageWindow(nil))
        await render(CloserProbe(), settling: true)
    }
    #endif
}

/// Fecha a tela pouco depois de aparecer, quando a janela que a hospeda já é conhecida.
private struct CloserProbe: View {
    private var closer = UAPPScreenCloser()

    var body: some View {
        Text("Tela")
            .uappNavigationBar(titleKey: "screen.feedback", accentColor: .purple)
            .background { closer.windowReader }
            .task {
                try? await Task.sleep(for: .milliseconds(100))
                closer()
            }
    }
}

#if os(macOS)
@MainActor
struct UAPPMacBoardAndDividerTests {
    private let item = UAPPFeedbackItem(
        id: "board-item", title: "Quadro", body: nil, voteCount: 0, likeCount: 0, commentCount: 0
    )

    @Test("Quadro do Roadmap mostra colunas com e sem itens e destaca o escolhido")
    func roadmapBoardRenders() async {
        let status = UAPPRoadmapColumn.Status(id: "planned", key: "planned", name: "Planejados", position: 0)
        let empty = UAPPRoadmapColumn.Status(id: "shipped", key: "shipped", name: "Entregues", position: 1)
        await render(UAPPRoadmapBoard(
            columns: [.init(status: status, items: [item]), .init(status: empty, items: [])],
            selectedId: item.id, accentColor: .purple
        ) { item, _ in Text(item.title) })
    }

    @Test("Painel de detalhe do Roadmap é montado com e sem item escolhido")
    func roadmapDetailPanelRenders() async {
        for selection in [nil, item] {
            await render(Text("Quadro").uappRoadmapDetailPanel(selection: .constant(selection)) { item in
                Text(item.title)
            })
        }
    }

    @Test("Largura da lista fica entre os limites e o divisor é montado")
    func listColumnWidth() async {
        #expect(UAPPListColumnWidth.clamped(10) == UAPPListColumnWidth.range.lowerBound)
        #expect(UAPPListColumnWidth.clamped(10000) == UAPPListColumnWidth.range.upperBound)
        #expect(UAPPListColumnWidth.clamped(400) == 400)
        await render(UAPPColumnDivider(width: .constant(360)))
        #expect(Color.uappToolbarIcon(.purple) == .primary)
    }
}
#endif

#if os(macOS)
@MainActor
struct UAPPFeedbackMacRowTests {
    @Test("Linha do Mac mostra autor sem foto, votos, etiquetas, prioridade e seleção")
    func macRowStatesRender() async {
        let status = UAPPRoadmapColumn.Status(id: "planned", key: "planned", name: "Planejados", position: 0)
        let plain = UAPPFeedbackItem(
            id: "row", title: "Linha", body: "Descrição", voteCount: 3, likeCount: 0, commentCount: 2,
            createdAt: Date(), authorName: "Wedja"
        )
        let voted = UAPPFeedbackItem(
            id: "voted", title: "Votado", body: nil, voteCount: 1, likeCount: 0, commentCount: 0,
            priority: 3, viewerVoted: true, tags: [UAPPFeedbackTag(id: "t", name: "Boleto", color: "#888888")]
        )
        for (item, selected) in [(plain, false), (voted, true)] {
            await render(UAPPFeedbackMacRow(
                item: item, status: status, accentColor: .purple, isSelected: selected,
                onReact: {}, onProfile: {}, onDetail: {}
            ))
        }
    }
}
#endif
