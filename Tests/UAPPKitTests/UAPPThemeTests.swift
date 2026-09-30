import SwiftUI
import Testing
@testable import UAPPKit

private struct NavigationModifierProbe: View {
    var body: some View {
        Text("Conteúdo")
            .modifier(UAPPNavigationBarModifier(title: Text(verbatim: "Título"), accentColor: .blue))
    }
}

@Test("tema resolve paletas independentes para claro e escuro")
func themeResolvesIndependentPalettes() {
    let lightAccent = Color.purple
    let darkAccent = Color.indigo
    let theme = UAPPTheme(
        light: .init(background: .white, accent: lightAccent),
        dark: .init(background: .black, accent: darkAccent)
    )

    #expect(theme.resolved(for: .light).accent == lightAccent)
    #expect(theme.resolved(for: .light).background == .white)
    #expect(theme.resolved(for: .dark).accent == darkAccent)
    #expect(theme.resolved(for: .dark).background == .black)
    #expect(theme.resolved(for: .light).buttonText == .white)
    #expect(UAPPTheme.system.resolved(for: .light).accent == nil)
}

@Test("tema e modificador de navegação constroem views")
@MainActor
func themeViewsBuild() async {
    await render(NavigationModifierProbe())
    await render(UAPPThemePresentationBackground())
}
