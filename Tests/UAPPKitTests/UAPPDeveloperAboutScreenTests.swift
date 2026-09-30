import SwiftUI
import Testing
@testable import UAPPKit

@Test("UAPPDeveloperAboutScreen constrói estados vazio, erro e conteúdo carregado")
@MainActor
func developerAboutScreenBuildsAllStates() async throws {
    let client = makeClient { _ in response(#"{"ok":true}"#) }
    let app = UAPPAboutApp(
        name: "App X",
        subtitle: "Resumo",
        appStoreURL: "https://apps.apple.com/app/id123456789",
        appleAppId: "123456789",
        iconURL: URL(string: "https://cdn.example/icon.png")
    )
    let about = try UAPPAbout(
        developerName: "Renato",
        imageURL: URL(string: "https://cdn.example/dev.png"),
        bio: "Uma bio pública",
        apps: [app],
        socialLinks: [
            "youtube": #require(URL(string: "https://youtube.com/@uapp")),
            "instagram": #require(URL(string: "https://instagram.com/uapp")),
            "tiktok": #require(URL(string: "https://tiktok.com/@uapp")),
            "linkedin": #require(URL(string: "https://linkedin.com/company/uapp")),
            "facebook": #require(URL(string: "https://facebook.com/uapp")),
            "x": #require(URL(string: "https://x.com/uapp")),
            "website": #require(URL(string: "https://uapp.com"))
        ]
    )
    let project = UAPPProject(
        slug: "meu-app",
        displayName: "Meu App",
        iconURL: nil,
        publicBaseURL: URL(string: "https://uapp.com/meu-app"),
        primaryColor: "#2D7A52",
        locale: "pt-BR"
    )

    await render(UAPPDeveloperAboutScreen(client: client, testingAbout: nil, isLoading: false))
    await render(UAPPDeveloperAboutScreen(client: client, testingAbout: nil, isLoading: false, hasError: true))
    await render(UAPPDeveloperAboutScreen(
        client: client,
        testingAbout: about,
        project: project,
        isLoading: false
    ))
}

#if canImport(UIKit) || canImport(AppKit)
@Test("UAPPDeveloperAboutScreen renderiza o perfil por um host SwiftUI")
@MainActor
func developerAboutScreenRendersContentInHost() async throws {
    let client = makeClient { _ in response(#"{"ok":true}"#) }
    let about = try UAPPAbout(
        developerName: "Renato",
        imageURL: nil,
        bio: "Bio",
        apps: [UAPPAboutApp(
            name: "App X",
            subtitle: "Resumo",
            appStoreURL: "https://apps.apple.com/app/id123456789",
            appleAppId: "123456789",
            iconURL: nil
        )],
        socialLinks: [
            "youtube": #require(URL(string: "https://youtube.com/@uapp")),
            "instagram": #require(URL(string: "https://instagram.com/uapp")),
            "website": #require(URL(string: "https://uapp.com"))
        ]
    )
    let project = UAPPProject(
        slug: "meu-app",
        displayName: "Meu App",
        iconURL: nil,
        publicBaseURL: URL(string: "https://uapp.com/meu-app"),
        primaryColor: nil,
        locale: nil
    )

    await render(UAPPDeveloperAboutScreen(
        client: client,
        testingAbout: about,
        project: project,
        isLoading: false
    ))
}
#endif
