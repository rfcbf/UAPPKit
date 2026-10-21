import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

private let statuses: [UAPPRoadmapColumn.Status] = [
    .init(id: "done", key: "shipped", name: "Concluído", position: 3, color: "#28734D"),
    .init(id: "planned", key: "planned", name: "Planejado", position: 1),
    .init(id: "custom", key: "custom", name: "Personalizado", position: 2, color: "#FF0000")
]

@MainActor
struct UAPPStatusBadgeTests {
    @Test("Selo mostra status conhecido, título explícito e ausência de status")
    func badgeRenders() async {
        await render(VStack {
            UAPPStatusBadge(status: statuses[0])
            UAPPStatusBadge(status: statuses[2], title: "Em análise")
            UAPPStatusBadge(status: nil)
        })
    }

    @Test("Anel de progresso acompanha a posição do status")
    func progressRenders() async {
        await render(HStack {
            ForEach(statuses, id: \.id) { UAPPStatusProgress(status: $0, statuses: statuses) }
            UAPPStatusProgress(status: .init(id: "zero", key: "new", name: "Novo", position: 0), statuses: [])
        })
    }

    @Test("Filtro lista todos os status em ordem com imagem do anel")
    func filterOptionsRender() async {
        var selection: String? = "planned"
        let binding = Binding(get: { selection }, set: { selection = $0 })
        await render(UAPPStatusFilterOptions(statuses: statuses, selection: binding))
        await render(UAPPStatusFilterOptions(statuses: [], selection: binding))
        #expect(selection == "planned")
    }
}
