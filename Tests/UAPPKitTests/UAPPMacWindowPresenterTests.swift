#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import UAPPKit

@MainActor
@Suite(.serialized)
struct UAPPMacWindowPresenterTests {
    @Test("Cada tela abre uma janela própria, reaproveitada na nova abertura")
    func presenterReusesWindowPerScreen() throws {
        let presenter = UAPPMacWindowPresenter()
        presenter.ordersWindowsFront = false
        defer { presenter.closeAll() }

        presenter.present(.feedback, content: Text("Primeira"))
        let window = try #require(presenter.windows[.feedback])
        #expect(window.title == uappLocalized("screen.feedback"))
        #expect(window.styleMask.contains(.resizable))
        #expect(window.contentMinSize == UAPPPresentedScreen.feedback.minimumSize)
        #expect(window.isReleasedWhenClosed == false)

        presenter.present(.feedback, content: Text("Segunda"))
        #expect(presenter.windows[.feedback] === window)
        #expect(presenter.windows.count == 1)

        presenter.present(.account, content: Text("Conta"))
        let account = try #require(presenter.windows[.account])
        #expect(!account.styleMask.contains(.resizable))
        #expect(!account.styleMask.contains(.miniaturizable))
        #expect(account.styleMask.contains(.closable))
        #expect(account.standardWindowButton(.zoomButton)?.isHidden != false)
        #expect(account.standardWindowButton(.miniaturizeButton)?.isHidden != false)
        #expect(presenter.windows.count == 2)
    }

    @Test("Fechar a janela libera a tela, e a próxima abertura cria outra")
    func closingWindowReleasesScreen() throws {
        let presenter = UAPPMacWindowPresenter()
        presenter.ordersWindowsFront = false
        defer { presenter.closeAll() }

        presenter.present(.about, content: Text("Sobre"))
        let first = try #require(presenter.windows[.about])
        presenter.close(.about)
        #expect(presenter.windows[.about] == nil)
        #expect(first.contentViewController == nil)

        presenter.present(.about, content: Text("Sobre"))
        #expect(presenter.windows[.about] !== first)
        presenter.closeAll()
        #expect(presenter.windows.isEmpty)
    }

    @Test("A janela abre no centro do monitor e cabe na área útil")
    func newWindowOpensCentered() throws {
        let visible = CGRect(x: 0, y: 40, width: 1440, height: 860)
        let centered = UAPPMacWindowPresenter.centeredFrame(for: CGSize(width: 600, height: 400), in: visible)
        #expect(centered == CGRect(x: 420, y: 270, width: 600, height: 400))
        let oversized = UAPPMacWindowPresenter.centeredFrame(for: CGSize(width: 2000, height: 1200), in: visible)
        #expect(oversized == visible)

        let presenter = UAPPMacWindowPresenter()
        presenter.ordersWindowsFront = false
        presenter.hostWindowProvider = { nil }
        defer { presenter.closeAll() }
        presenter.present(.reviews, content: Text("Avaliações"))
        let window = try #require(presenter.windows[.reviews])
        if let screen = NSScreen.main {
            #expect(abs(window.frame.midX - screen.visibleFrame.midX) <= 1)
            #expect(abs(window.frame.midY - screen.visibleFrame.midY) <= 1)
        }
    }

    @Test("Tamanhos e pilha de navegação acompanham o tipo de tela")
    func screenMetrics() {
        for screen in UAPPPresentedScreen.allCases {
            #expect(screen.contentSize.width >= screen.minimumSize.width)
            #expect(screen.contentSize.height >= screen.minimumSize.height)
            #expect(uappLocalized(screen.titleKey) != screen.titleKey)
        }
        #expect(!UAPPPresentedScreen.feedback.wrapsInNavigationStack)
        #expect(!UAPPPresentedScreen.roadmap.wrapsInNavigationStack)
        #expect(UAPPPresentedScreen.changelog.wrapsInNavigationStack)
        #expect(UAPPPresentedScreen.account.wrapsInNavigationStack)
    }
}
#endif
