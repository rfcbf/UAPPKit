import Foundation
#if os(macOS) && canImport(SwiftUI)
import AppKit
import SwiftUI
#endif

/// Telas apresentadas por `UAPPKit.show*`. No Mac, cada uma abre em uma janela própria.
enum UAPPPresentedScreen: String, CaseIterable {
    case feedback
    case roadmap
    case changelog
    case reviews
    case about
    case developerAbout
    case account
    case user
}

#if os(macOS) && canImport(SwiftUI)
extension UAPPPresentedScreen {
    var titleKey: String {
        switch self {
        case .feedback: "screen.feedback"
        case .roadmap: "screen.roadmap"
        case .changelog: "screen.changelog"
        case .reviews: "screen.reviews"
        case .about: "screen.about"
        case .developerAbout: "screen.developer_about"
        case .account: "auth.title"
        case .user: "user.account"
        }
    }

    /// Tamanho inicial da janela; listas com detalhe abrem largas, conta e Sobre, estreitas.
    var contentSize: CGSize {
        switch self {
        case .feedback: CGSize(width: 1180, height: 720)
        // Quadro com várias colunas de status lado a lado.
        case .roadmap: CGSize(width: 1180, height: 720)
        case .changelog: CGSize(width: 720, height: 720)
        case .reviews: CGSize(width: 680, height: 720)
        case .about, .developerAbout: CGSize(width: 560, height: 680)
        // Alta o bastante para o cadastro caber sem rolagem; encolhe em monitores menores.
        case .account: CGSize(width: 500, height: 960)
        case .user: CGSize(width: 500, height: 660)
        }
    }

    var minimumSize: CGSize {
        switch self {
        case .feedback, .roadmap: CGSize(width: 720, height: 480)
        case .changelog, .reviews: CGSize(width: 480, height: 480)
        case .about, .developerAbout, .account, .user: CGSize(width: 420, height: 480)
        }
    }

    /// Feedback e Roadmap montam a própria divisão lista/detalhe; as demais telas navegam em pilha.
    var wrapsInNavigationStack: Bool {
        switch self {
        case .feedback, .roadmap: false
        default: true
        }
    }

    /// Conta e Perfil são janelas de tarefa curta: só o botão de fechar, sem minimizar,
    /// maximizar nem redimensionar.
    var isCompactPanel: Bool {
        switch self {
        case .account, .user: true
        default: false
        }
    }
}

/// Abre as telas do pacote em janelas nativas do Mac. Cada tela tem uma única janela: chamar de
/// novo troca o conteúdo e traz a janela para a frente, como os painéis de Ajuda dos apps do Mac.
@MainActor
final class UAPPMacWindowPresenter: NSObject, NSWindowDelegate {
    private(set) var windows: [UAPPPresentedScreen: NSWindow] = [:]
    /// Janela ativa do aplicativo; a tela abre centralizada no monitor dela.
    var hostWindowProvider: @MainActor () -> NSWindow? = { NSApp.keyWindow ?? NSApp.mainWindow }
    /// Desligado nos testes, para não exibir janelas nem roubar o foco.
    var ordersWindowsFront = true

    func present(_ screen: UAPPPresentedScreen, content: some View) {
        let window = windows[screen] ?? makeWindow(for: screen)
        let controller = NSHostingController(rootView: AnyView(content))
        // A janela segue o tamanho escolhido pela pessoa; o SwiftUI só impõe o mínimo.
        controller.sizingOptions = [.minSize]
        // Título e barra de ferramentas do SwiftUI passam para a janela a partir do macOS 14.
        if #available(macOS 14, *) {
            controller.sceneBridgingOptions = [.title, .toolbars]
        }
        let frame = window.frame
        window.contentViewController = controller
        if screen.isCompactPanel {
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }
        if windows[screen] == nil {
            window.setContentSize(screen.contentSize)
            position(window)
            windows[screen] = window
        } else {
            window.setFrame(frame, display: false)
        }
        if ordersWindowsFront {
            if #available(macOS 14, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
            window.makeKeyAndOrderFront(nil)
        }
    }

    static let windowIdentifierPrefix = "UAPPKit."

    /// Janela aberta por `UAPPKit.show…`. Sheets e janelas do aplicativo não contam.
    static func isPackageWindow(_ window: NSWindow?) -> Bool {
        window?.identifier?.rawValue.hasPrefix(windowIdentifierPrefix) == true
    }

    func close(_ screen: UAPPPresentedScreen) {
        windows[screen]?.close()
    }

    func closeAll() {
        windows.values.forEach { $0.close() }
    }

    private func makeWindow(for screen: UAPPPresentedScreen) -> NSWindow {
        var style: NSWindow.StyleMask = [.titled, .closable]
        if !screen.isCompactPanel {
            style.formUnion([.miniaturizable, .resizable])
        }
        // Com a barra de ferramentas unificada do SwiftUI (macOS 14+), o conteúdo passa por baixo
        // dela como nas janelas do próprio SwiftUI.
        if #available(macOS 14, *) {
            style.insert(.fullSizeContentView)
        }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: screen.contentSize),
            styleMask: style,
            backing: .buffered,
            defer: true
        )
        window.title = uappLocalized(screen.titleKey)
        window.identifier = NSUserInterfaceItemIdentifier(Self.windowIdentifierPrefix + screen.rawValue)
        window.contentMinSize = screen.minimumSize
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.toolbarStyle = .unified
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.delegate = self
        return window
    }

    /// Cada abertura aparece no centro do monitor da janela ativa do aplicativo (ou do monitor
    /// principal), reduzida quando não cabe na área útil da tela.
    private func position(_ window: NSWindow) {
        guard let visible = (hostWindowProvider()?.screen ?? NSScreen.main ?? window.screen)?.visibleFrame else {
            window.center()
            return
        }
        window.setFrame(Self.centeredFrame(for: window.frame.size, in: visible), display: false)
    }

    static func centeredFrame(for size: CGSize, in visible: CGRect) -> CGRect {
        let width = min(size.width, visible.width)
        let height = min(size.height, visible.height)
        return CGRect(
            x: (visible.midX - width / 2).rounded(),
            y: (visible.midY - height / 2).rounded(),
            width: width,
            height: height
        )
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let identifier = ObjectIdentifier(window)
        MainActor.assumeIsolated {
            guard let screen = windows.first(where: { ObjectIdentifier($0.value) == identifier })?.key else { return }
            windows[screen] = nil
            // Libera a tela e suas tarefas (atualização ao vivo, carregamentos) ao fechar.
            window.contentViewController = nil
        }
    }
}
#endif
