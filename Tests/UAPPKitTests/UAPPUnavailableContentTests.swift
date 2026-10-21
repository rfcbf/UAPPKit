import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Test("recursos visuais do mascote estão presentes e são decodificáveis")
@MainActor
func mascotResourcesAreBundled() async throws {
    let states: [UAPPMascotState] = [.unavailable, .emptyFeedback, .connectionError, .emptyChangelog, .success]
    let names = [
        "UAPPMascotPrototype",
        "UAPPMascotEmptyFeedback",
        "UAPPMascotConnectionError",
        "UAPPMascotEmptyChangelog",
        "UAPPMascotSuccess"
    ]
    for (state, name) in zip(states, names) {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "png"))
        #expect(url.pathExtension == "png")
        await render(UAPPMascotIllustration(state: state))
        #if canImport(UIKit)
        #expect(UIImage(contentsOfFile: url.path) != nil)
        #elseif canImport(AppKit)
        #expect(NSImage(contentsOf: url) != nil)
        #endif
    }
}

@Test("hexadecimal de cor aceita RGB válido e rejeita entradas inválidas")
func colorHexParsing() {
    #expect(Color(hex: "#2D7A52") != nil)
    #expect(Color(hex: "2D7A52") != nil)
    #expect(Color(hex: "#12345") == nil)
    #expect(Color(hex: "#GGGGGG") == nil)
}

@Test("conteúdos vazio, indisponível e cartão de estado constroem views")
@MainActor
func unavailableContentViewsBuild() async {
    await render(UAPPEmptyContent(
        mascotState: .emptyFeedback,
        title: "Vazio",
        message: "Ainda não há itens."
    ))
    await render(UAPPUnavailableContent(
        message: "Falha",
        accentColor: .blue,
        mascotState: .connectionError,
        retry: {}
    ))
    await render(UAPPStateCard { Text("Conteúdo") })
}
