#if canImport(SwiftUI)
import SwiftUI

struct UAPPChangelogSearchModifier: ViewModifier {
    let enabled: Bool
    @Binding var query: String
    @Binding var isPresented: Bool
    let accentColor: Color
    var promptKey: String = "changelog.search"
    /// Texto pronto do aplicativo; quando presente, substitui a chave do pacote.
    var promptText: String?

    private var prompt: String {
        promptText ?? uappLocalized(promptKey)
    }

    func body(content: Content) -> some View {
        if enabled {
            #if os(iOS)
            if #available(iOS 26, *) {
                if isPresented {
                    content
                        .searchable(
                            text: $query, isPresented: $isPresented, placement: .toolbar,
                            prompt: Text(verbatim: prompt)
                        )
                        .searchToolbarBehavior(.automatic)
                        .toolbar { DefaultToolbarItem(kind: .search, placement: .bottomBar) }
                        .tint(accentColor)
                } else {
                    content
                }
            } else {
                legacySearch(content)
            }
            #else
            legacySearch(content)
            #endif
        } else {
            content
        }
    }

    private func legacySearch(_ content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            if isPresented {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(accentColor)
                    TextField(prompt, text: $query)
                        .textFieldStyle(.plain)
                }
                .padding()
                .background(.regularMaterial, in: Capsule())
                .padding()
            }
        }
    }
}
#endif
