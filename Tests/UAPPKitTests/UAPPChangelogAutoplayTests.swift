import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit

private let becameActive = UIApplication.didBecomeActiveNotification
private let resignedActive = UIApplication.willResignActiveNotification
#elseif canImport(AppKit)
import AppKit

private let becameActive = NSApplication.didBecomeActiveNotification
private let resignedActive = NSApplication.didResignActiveNotification
#endif
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

@MainActor
private final class ActivityBox {
    var isActive = false
    var binding: Binding<Bool> {
        Binding(get: { self.isActive }, set: { self.isActive = $0 })
    }
}

@Test("observador acompanha ativação e saída do aplicativo")
@MainActor
func changelogApplicationActivityFollowsLifecycle() async {
    let box = ActivityBox()
    await render(Text("Carrossel").modifier(UAPPChangelogApplicationActivity(isActive: box.binding))) {
        NotificationCenter.default.post(name: becameActive, object: nil)
        await Task.yield()
        #expect(box.isActive)
        NotificationCenter.default.post(name: resignedActive, object: nil)
        await Task.yield()
        #expect(!box.isActive)
    }
}
