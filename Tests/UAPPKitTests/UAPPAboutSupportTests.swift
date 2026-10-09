import SwiftUI
import Testing
@testable import UAPPKit

@Test("Suporte do Sobre usa o e-mail do servidor antes do link da configuração")
func aboutSupportPrefersServerEmail() {
    let link = URL(string: "https://example.com/suporte")
    let configuration = UAPPAboutConfiguration(supportURL: link)

    #expect(
        UAPPAboutScreen.supportURL(configuration: configuration, serverEmail: " suporte@example.com ")?
            .absoluteString == "mailto:suporte@example.com"
    )
    #expect(UAPPAboutScreen.supportURL(configuration: configuration, serverEmail: nil) == link)
    #expect(UAPPAboutScreen.supportURL(configuration: configuration, serverEmail: "  ") == link)
    #expect(UAPPAboutScreen.supportURL(configuration: configuration, serverEmail: "sem-arroba") == link)
    #expect(UAPPAboutScreen.supportURL(configuration: configuration, serverEmail: "a b@example.com") == link)
    #expect(UAPPAboutScreen.supportURL(configuration: .init(), serverEmail: nil) == nil)
}

@Test("Sobre do desenvolvedor decodifica o e-mail de suporte quando o servidor o envia")
func aboutDecodesSupportEmail() throws {
    let with = try JSONDecoder().decode(
        UAPPAbout.self,
        from: json(#"{"developer_name":"Ana","support_email":"suporte@example.com"}"#)
    )
    #expect(with.supportEmail == "suporte@example.com")

    let without = try JSONDecoder().decode(UAPPAbout.self, from: json(#"{"developer_name":"Ana"}"#))
    #expect(without.supportEmail == nil)
}

@Test("Configuração do Sobre guarda a opção de avaliações")
func aboutConfigurationKeepsReviewOptions() {
    let standard = UAPPAboutConfiguration()
    #expect(!standard.showsReviews && standard.reviewsPageSize == 10)

    let custom = UAPPAboutConfiguration(showsReviews: true, reviewsPageSize: 25)
    #expect(custom.showsReviews && custom.reviewsPageSize == 25)
    #expect(custom != standard)
}

@Test("Sobre monta a ação de avaliações e o suporte por e-mail")
@MainActor
func aboutRendersReviewsAndSupportRows() async {
    let palette = UAPPTheme.system.resolved(for: .light)
    await render(UAPPAboutResources(
        configuration: UAPPAboutConfiguration(showsReviews: true),
        palette: palette,
        isOpeningAppStoreReview: false,
        onOpenAppStoreReview: nil,
        onOpenChangelog: nil,
        supportURL: URL(string: "mailto:suporte@example.com"),
        onOpenReviews: {}
    ))
    await render(UAPPAboutResources(
        configuration: UAPPAboutConfiguration(showsReviews: true),
        palette: palette,
        isOpeningAppStoreReview: false,
        onOpenAppStoreReview: nil,
        onOpenChangelog: nil
    ))

    let client = makeClient { _ in
        response(#"{"about":{"developer_name":"Ana","support_email":"suporte@example.com"}}"#)
    }
    await render(NavigationStack {
        UAPPAboutScreen(configuration: UAPPAboutConfiguration(showsReviews: true), client: client)
    })
}
