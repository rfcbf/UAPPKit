#if os(macOS)
import AppKit
import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

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

        for screen in [UAPPPresentedScreen.changelog, .reviews, .about, .developerAbout] {
            presenter.present(screen, content: Text("Tela"))
            let window = try #require(presenter.windows[screen])
            #expect(window.styleMask.contains(.resizable))
            #expect(!window.styleMask.contains(.miniaturizable))
            #expect(window.standardWindowButton(.zoomButton)?.isHidden != false)
            #expect(window.standardWindowButton(.miniaturizeButton)?.isHidden != false)
        }
        #expect(window.styleMask.contains(.miniaturizable))
        #expect(presenter.windows.count == 6)
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

    @Test("Quem abre a janela é avisado uma vez quando ela fecha ou passa para outra tela")
    func closeHandlerRunsOnceOnCloseOrReplacement() throws {
        let presenter = UAPPMacWindowPresenter()
        presenter.ordersWindowsFront = false
        defer { presenter.closeAll() }
        var first = 0
        var second = 0

        presenter.present(.account, content: Text("Conta"), onClose: { first += 1 })
        let window = try #require(presenter.windows[.account])
        // Outra tela abre a mesma janela: a primeira deixa de ser dona e é avisada.
        presenter.present(.account, content: Text("Conta"), onClose: { second += 1 })
        #expect(presenter.windows[.account] === window)
        #expect(first == 1)
        #expect(second == 0)

        presenter.close(.account)
        #expect(first == 1)
        #expect(second == 1)

        // Sem aviso registrado, fechar não chama nada nem guarda o aviso anterior.
        presenter.present(.account, content: Text("Conta"))
        presenter.close(.account)
        #expect(first == 1)
        #expect(second == 1)
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
