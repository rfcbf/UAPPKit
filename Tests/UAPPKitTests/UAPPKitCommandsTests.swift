#if canImport(SwiftUI) && (canImport(UIKit) || os(macOS))
import SwiftUI
import Testing
@testable import UAPPKit

@MainActor
struct UAPPKitCommandsTests {
    @Test("Itens do menu Ajuda usam os títulos traduzidos do pacote")
    func itemTitlesAreLocalized() {
        for item in UAPPKitCommands.Item.allCases {
            let title = UAPPKitCommands.title(for: item)
            #expect(!title.isEmpty)
            #expect(!title.contains("."))
        }
        #expect(UAPPKitCommands.aboutTitle(appName: "Exemplo").contains("Exemplo"))
    }

    @Test("Menu é montado com e sem o item Sobre")
    func commandsBuild() {
        _ = UAPPKitCommands().body
        _ = UAPPKitCommands(items: [], aboutConfiguration: .init()).body
    }
}
#endif
