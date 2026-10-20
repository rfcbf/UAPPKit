#if canImport(SwiftUI) && (canImport(UIKit) || os(macOS))
import SwiftUI

/// Itens de menu do UAPPKit para a barra de menus do Mac (e do iPad com teclado).
///
/// ```swift
/// WindowGroup { ContentView() }
///     .commands { UAPPKitCommands() }
/// ```
///
/// Os itens entram no fim do menu Ajuda e abrem as janelas do pacote. Com
/// `aboutConfiguration`, o item "Sobre" do menu do aplicativo passa a abrir a tela Sobre do
/// UAPPKit no lugar do painel padrão do sistema.
public struct UAPPKitCommands: Commands {
    /// Ações disponíveis no menu Ajuda, na ordem em que são informadas.
    public enum Item: String, CaseIterable, Hashable, Sendable {
        case feedback
        case roadmap
        case changelog
        case reviews
        case rateOnAppStore
        case developerAbout
    }

    private let items: [Item]
    private let aboutConfiguration: UAPPAboutConfiguration?

    /// - Parameters:
    ///   - items: ações acrescentadas ao menu Ajuda.
    ///   - aboutConfiguration: quando informado, substitui o item "Sobre" do menu do aplicativo
    ///     pela tela Sobre do UAPPKit com esta configuração.
    public init(
        items: [Item] = [.feedback, .roadmap, .changelog, .rateOnAppStore],
        aboutConfiguration: UAPPAboutConfiguration? = nil
    ) {
        self.items = items
        self.aboutConfiguration = aboutConfiguration
    }

    public var body: some Commands {
        if let aboutConfiguration {
            CommandGroup(replacing: .appInfo) {
                Button(Self.aboutTitle(appName: UAPPAppMetadata().name)) {
                    try? UAPPKit.showAbout(configuration: aboutConfiguration)
                }
            }
        }
        CommandGroup(after: .help) {
            if !items.isEmpty {
                Divider()
            }
            ForEach(items, id: \.self) { item in
                Button(Self.title(for: item)) {
                    Self.perform(item)
                }
            }
        }
    }

    static func aboutTitle(appName: String) -> String {
        String(format: uappLocalized("menu.about_app"), appName)
    }

    static func title(for item: Item) -> String {
        switch item {
        case .feedback: uappLocalized("menu.feedback")
        case .roadmap: uappLocalized("screen.roadmap")
        case .changelog: uappLocalized("screen.changelog")
        case .reviews: uappLocalized("screen.reviews")
        case .rateOnAppStore: uappLocalized("about.rate_app")
        case .developerAbout: uappLocalized("screen.developer_about")
        }
    }

    /// Sem `UAPPKit.setup`, o item não faz nada: o menu não deve interromper o aplicativo.
    @MainActor
    static func perform(_ item: Item) {
        switch item {
        case .feedback: try? UAPPKit.showFeedback()
        case .roadmap: try? UAPPKit.showRoadmap()
        case .changelog: try? UAPPKit.showChangelog()
        case .reviews: try? UAPPKit.showReviews(pageSize: 20)
        case .developerAbout: try? UAPPKit.showDeveloperAbout()
        case .rateOnAppStore: Task { try? await UAPPKit.openAppStoreReview() }
        }
    }
}
#endif
