#if canImport(SwiftUI)
import SwiftUI

#if os(macOS)
import AppKit
#endif

private struct UAPPSplitDetailKey: EnvironmentKey {
    static let defaultValue = false
}

private struct UAPPToolbarItemsHiddenKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Verdadeiro na coluna de detalhe da divisão lista/detalhe do Mac.
    var uappIsSplitDetail: Bool {
        get { self[UAPPSplitDetailKey.self] }
        set { self[UAPPSplitDetailKey.self] = newValue }
    }

    /// Verdadeiro enquanto a tela ainda não conhece a cor do projeto: idioma, conta, busca e
    /// ações da barra só aparecem depois, já na cor de destaque. Fechar continua visível.
    var uappToolbarItemsHidden: Bool {
        get { self[UAPPToolbarItemsHiddenKey.self] }
        set { self[UAPPToolbarItemsHiddenKey.self] = newValue }
    }
}

/// Fecha a tela pelo meio certo: a sheet ou a navegação com `dismiss` e, no Mac, a janela aberta
/// por `UAPPKit.show…` quando a tela está nela, e não em uma sheet.
///
/// No Mac, `isPresented` é verdadeiro até na raiz de uma janela; por isso a tela lê a janela real
/// em que está (`windowReader`). "Fechar" só aparece dentro de uma sheet: em uma janela, do
/// pacote ou do próprio aplicativo, vale o botão de fechar da janela.
struct UAPPScreenCloser: DynamicProperty {
    @Environment(\.dismiss) private var dismiss
    #if os(macOS)
    @State private var hostWindow = UAPPWeakWindow()
    @State private var isInPackageWindow = false
    /// `nil` enquanto a janela ainda não é conhecida.
    @State private var isInSheet: Bool?
    #endif

    /// A tela não está em uma sheet; o botão de fechar da janela já cumpre o papel. Enquanto a
    /// janela não é conhecida também vale verdadeiro, para "Fechar" não piscar.
    @MainActor var closesWindow: Bool {
        #if os(macOS)
        isInSheet != true
        #else
        false
        #endif
    }

    /// Instale no fundo da tela para descobrir a janela que a hospeda. Vazio fora do Mac.
    @MainActor var windowReader: some View {
        #if os(macOS)
        UAPPHostingWindowReader { window in
            // Ao navegar, a tela sai da janela por um instante; isso não muda onde ela está.
            guard let window else { return }
            hostWindow.window = window
            isInPackageWindow = UAPPMacWindowPresenter.isPackageWindow(window)
            isInSheet = window.isSheet || window.sheetParent != nil
        }
        #else
        EmptyView()
        #endif
    }

    @MainActor func callAsFunction() {
        #if os(macOS)
        if isInPackageWindow, isInSheet != true, let window = hostWindow.window {
            window.performClose(nil)
            return
        }
        #endif
        dismiss()
    }
}

#if os(macOS)
/// Referência fraca à janela, para a tela não manter viva a janela que a contém.
final class UAPPWeakWindow {
    weak var window: NSWindow?
}

/// Informa a janela em que a view foi colocada, inclusive quando ela muda de janela.
struct UAPPHostingWindowReader: NSViewRepresentable {
    let onWindow: @MainActor (NSWindow?) -> Void

    func makeNSView(context _: Context) -> UAPPHostingWindowView {
        let view = UAPPHostingWindowView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ view: UAPPHostingWindowView, context _: Context) {
        view.onWindow = onWindow
    }
}

final class UAPPHostingWindowView: NSView {
    var onWindow: (@MainActor (NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let window = window
        // Fora da atualização da view, para o SwiftUI aceitar a mudança de estado.
        Task { @MainActor [weak self] in
            self?.onWindow?(window)
        }
    }
}
#endif

extension Color {
    /// Ícones da barra de ferramentas: cor de destaque no iPhone e no iPad; no Mac, a cor padrão
    /// do sistema, que continua legível sobre o material da janela.
    static func uappToolbarIcon(_ accent: Color) -> Color {
        #if os(macOS)
        .primary
        #else
        accent
        #endif
    }
}

extension View {
    /// Fundo do tema na tela inteira. No Mac, a área da barra de ferramentas fica com o material
    /// da janela, igual nas duas colunas da divisão lista/detalhe.
    func uappScreenBackground(_ color: Color) -> some View {
        #if os(macOS)
        background(color)
        #else
        background(color.ignoresSafeArea())
        #endif
    }

    /// Fundo dos estados vazios e de erro: um cartão no iPhone e no iPad; no Mac, sem caixa nem
    /// contorno, direto sobre o fundo da janela.
    @ViewBuilder
    func uappEmptyStateSurface(_ palette: UAPPResolvedPalette) -> some View {
        #if os(macOS)
        self
        #else
        uappCardSurface(palette, cornerRadius: 28)
        #endif
    }

    /// Tamanho de uma sheet no Mac, que se ajusta ao conteúdo e ficaria estreita com listas e
    /// rolagens. No iPhone e no iPad não muda nada.
    @ViewBuilder
    func uappMacSheetFrame(width: CGFloat, height: CGFloat, minHeight: CGFloat? = nil) -> some View {
        #if os(macOS)
        frame(minWidth: width, idealWidth: width, minHeight: minHeight ?? height, idealHeight: height)
        #else
        self
        #endif
    }
}

/// Ações da barra de ferramentas das listas no Mac: "Enviar feedback" (⌘N) e "Atualizar" (⌘R).
/// No iPhone e no iPad a lista usa o botão flutuante e a atualização automática.
struct UAPPMacFeedbackCommands: ViewModifier {
    var showsNewFeedback = false
    let accentColor: Color
    var isRefreshing = false
    var onNewFeedback: () -> Void = {}
    let onRefresh: () -> Void
    @Environment(\.uappToolbarItemsHidden) private var itemsHidden

    func body(content: Content) -> some View {
        #if os(macOS)
        content.toolbar {
            if !itemsHidden {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: onRefresh) {
                        Label(uappLocalized("common.refresh"), systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .help(Text(verbatim: uappLocalized("common.refresh")))
                    .disabled(isRefreshing)
                    if showsNewFeedback {
                        Button(action: onNewFeedback) {
                            Label(uappLocalized("feedback.send"), systemImage: "square.and.pencil")
                        }
                        .keyboardShortcut("n", modifiers: .command)
                        .help(Text(verbatim: uappLocalized("feedback.send")))
                    }
                }
            }
        }
        #else
        content
        #endif
    }
}
#endif
