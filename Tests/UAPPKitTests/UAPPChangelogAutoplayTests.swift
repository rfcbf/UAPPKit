import SwiftUI
import Testing
@testable import UAPPKit

@Test("autoplay depende do aplicativo ativo, visibilidade, configuração e acessibilidade")
func changelogAutoplayConditions() {
    func enabled(auto: Bool = true, count: Int = 2, visible: Bool = true, active: Bool = true, voiceOver: Bool = false, reduceMotion: Bool = false) -> Bool {
        UAPPChangelogAutoplay.isEnabled(
            configuration: .init(automaticallyScrolls: auto), imageCount: count, isVisible: visible,
            isApplicationActive: active, voiceOver: voiceOver, reduceMotion: reduceMotion
        )
    }
    #expect(enabled())
    #expect(!enabled(auto: false))
    #expect(!enabled(count: 0))
    #expect(!enabled(count: 1))
    #expect(!enabled(visible: false))
    #expect(!enabled(active: false))
    #expect(!enabled(voiceOver: true))
    #expect(!enabled(reduceMotion: true))
}

@Test("observador do ciclo de vida renderiza em um hosting controller")
@MainActor
func changelogApplicationActivityRenders() async {
    await render(Text("Carrossel").modifier(UAPPChangelogApplicationActivity(isActive: .constant(false))))
}
