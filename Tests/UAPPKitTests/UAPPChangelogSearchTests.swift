import SwiftUI
import Testing
@testable import UAPPKit

@MainActor
struct UAPPChangelogSearchTests {
    private func renderSearch(enabled: Bool, presented: Bool, query: String = "") async {
        var text = query
        var isPresented = presented
        await render(
            NavigationStack {
                List { Text("Versão 2.0") }
                    .modifier(UAPPChangelogSearchModifier(
                        enabled: enabled,
                        query: Binding(get: { text }, set: { text = $0 }),
                        isPresented: Binding(get: { isPresented }, set: { isPresented = $0 }),
                        accentColor: .purple,
                        promptKey: "common.search"
                    ))
            }
        )
    }

    @Test("Busca aberta, fechada e desativada constroem a lista")
    func searchStatesRender() async {
        await renderSearch(enabled: true, presented: true, query: "2.0")
        await renderSearch(enabled: true, presented: false)
        await renderSearch(enabled: false, presented: true)
    }
}
