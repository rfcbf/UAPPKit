import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@MainActor
struct UAPPPresentationTests {
    @Test("Sheets recebem fundo do tema e posicionamento lateral quando disponível")
    func presentationModifiersRender() async {
        await render(
            Text("Conteúdo")
                .sheet(isPresented: .constant(false)) {
                    Text("Sheet")
                        .uappPresentationBackground(.white)
                        .uappPresentationPlacement(.trailing)
                }
                .uappPresentationBackground(.black)
                .uappPresentationPlacement(.trailing)
        )
    }
}
