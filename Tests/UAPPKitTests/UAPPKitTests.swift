import Foundation
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

#if os(macOS)
import AppKit
import SwiftUI
#endif

#if canImport(UIKit) && canImport(SwiftUI)
import UIKit

@MainActor
private final class PresentationProbeViewController: UIViewController {
    private(set) var presentedViewControllerCount = 0
    private(set) var lastPresentedViewController: UIViewController?

    override func present(
        _ viewController: UIViewController,
        animated _: Bool,
        completion: (() -> Void)? = nil
    ) {
        presentedViewControllerCount += 1
        lastPresentedViewController = viewController
        completion?()
    }
}
#endif

/// Registra os links abertos pelo SDK sem acionar o sistema.
@MainActor
private final class OpenerProbe {
    var opened: [URL] = []
    var accepts = true
}

@Suite(.serialized)
struct UAPPKitTests {
    @Test("UAPPKit exige configuração antes de criar cliente e aceita setup/reset")
    @MainActor
    func appKitConfigurationLifecycle() async throws {
        UAPPKit.reset()
        do {
            _ = try UAPPKit.makeClient()
            Issue.record("makeClient deveria exigir setup")
        } catch {
            #expect(error as? UAPPKitError == .notConfigured)
        }

        #if canImport(SwiftUI) && (canImport(UIKit) || os(macOS))
        let presentations: [@MainActor () throws -> Void] = [
            { try UAPPKit.showFeedback() },
            { try UAPPKit.showRoadmap() },
            { try UAPPKit.showChangelog() },
            { try UAPPKit.showReviews(pageSize: 10) },
            { try UAPPKit.showAbout() }
        ]
        for presentation in presentations {
            do {
                try presentation()
                Issue.record("a apresentação deveria exigir setup")
            } catch {
                #expect(error as? UAPPKitError == .notConfigured)
            }
        }
        #endif

        let demoURL = try #require(URL(string: "https://demo.example"))
        UAPPKit.setup(projectId: "demo", host: demoURL)
        let client = try UAPPKit.makeClient()
        UAPPKit.identify(userId: "user", email: "user@example.test", displayName: "User", traits: ["tier": "pro"])
        for _ in 0 ..< 100 {
            if await client.currentIdentity()?.userId == "user" {
                break
            }
            await Task.yield()
        }
        #expect(await client.currentIdentity()?.userId == "user")
        let scopedProfile = UAPPIdentity(userId: "feedback-user")
        let participation = try await UAPPKit.makeClient(
            identity: scopedProfile, accessTokenProvider: { "later-session" }
        )
        #expect(await participation.currentIdentity() == scopedProfile)
        #expect(await client.currentIdentity()?.userId == "user")
        UAPPKit.reset()
        for _ in 0 ..< 100 {
            if await client.currentIdentity() == nil {
                break
            }
            await Task.yield()
        }
        #expect(await client.currentIdentity() == nil)
    }

    @Test("Setup público acessa sempre o servidor de produção")
    @MainActor
    func appKitSetupUsesProductionServer() async {
        let previousTransport = UAPPKit.makeTransport
        defer {
            UAPPKit.makeTransport = previousTransport
            UAPPKit.reset()
        }
        let recorder = RequestRecorder()
        UAPPKit.makeTransport = {
            StubTransport { request in
                recorder.record(request)
                return (200, Data(#"{"items":[],"statuses":[]}"#.utf8))
            }
        }
        UAPPKit.setup(projectId: "somente-producao")
        _ = try? await UAPPKit.makeClient().feedbackPage(limit: 1)
        #expect(recorder.requests.first?.url?.host == UAPPConfiguration.defaultHost.host)
    }

    @Test("Feedback/Roadmap usam login automático e compartilham conta sem afetar conteúdo público")
    @MainActor
    func automaticParticipationClient() throws {
        UAPPKit.setup(projectId: "automatic-demo")
        let publicClient = try UAPPKit.makeClient()
        let participation = try UAPPKit.makeParticipationClient()
        #expect(publicClient.authentication == nil)
        #expect(participation.authentication?.methods == [.email])
        #expect(try UAPPKit.makeParticipationClient() === participation)
        UAPPKit.setup(projectId: "automatic-demo", theme: .system)
        #expect(try UAPPKit.makeParticipationClient() === participation)
        UAPPKit.setup(projectId: "another-project")
        #expect(try UAPPKit.makeParticipationClient() !== participation)
    }

    @Test("UAPPKit expõe a preferência de idioma e atualiza o locale")
    @MainActor
    func appKitLocaleLifecycle() async {
        let defaults = UserDefaults.standard
        let key = UAPPKit.localePreferenceKey
        let previousValue = defaults.object(forKey: key)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
            UAPPKit.reset()
        }

        defaults.removeObject(forKey: key)
        UAPPKit.setLocale(Locale(identifier: "en-US"))
        #expect(defaults.string(forKey: key) == "en")

        UAPPKit.setLocale(Locale(identifier: "de-DE"))
        await Task.yield()
        #expect(defaults.string(forKey: key) == "de")

        UAPPKit.setLocale(Locale(identifier: "language-that-does-not-exist"))
        await Task.yield()
        #expect(defaults.string(forKey: key) == "pt-BR")
    }

    @Test("Avaliação na App Store abre o destino do projeto e informa falhas")
    @MainActor
    func appKitOpensAppStoreReview() async throws {
        let previousTransport = UAPPKit.makeTransport
        let previousOpener = UAPPKit.urlOpener
        defer {
            UAPPKit.makeTransport = previousTransport
            UAPPKit.urlOpener = previousOpener
            UAPPKit.reset()
        }
        let host = try #require(URL(string: "https://review.example"))
        let opener = OpenerProbe()
        UAPPKit.urlOpener = { url in
            opener.opened.append(url)
            return opener.accepts
        }
        UAPPKit.makeTransport = {
            StubTransport { _ in response(#"{"project":{"slug":"review-test","apple_app_id":"123456789"},"about":{}}"#) }
        }
        UAPPKit.setup(projectId: "review-test", host: host)
        try await UAPPKit.openAppStoreReview()
        #expect(opener.opened.first?.absoluteString.contains("id123456789") == true)

        opener.accepts = false
        await #expect(throws: UAPPKitError.appStoreURLCouldNotOpen) { try await UAPPKit.openAppStoreReview() }

        UAPPKit.makeTransport = { StubTransport { _ in response(#"{"about":{"about_apps":[]}}"#) } }
        UAPPKit.setup(projectId: "review-empty", host: host)
        await #expect(throws: UAPPKitError.appStoreURLUnavailable) { try await UAPPKit.openAppStoreReview() }
    }

    #if os(macOS)
    /// Fica nesta suíte serializada porque altera a configuração global do UAPPKit.
    @Test("Cada item do menu Ajuda abre a janela correspondente")
    @MainActor
    func commandsOpenWindows() async throws {
        let presenter = UAPPMacWindowPresenter()
        presenter.ordersWindowsFront = false
        let previousPresenter = UAPPKit.windowPresenter
        let previousTransport = UAPPKit.makeTransport
        let previousOpener = UAPPKit.urlOpener
        defer {
            presenter.closeAll()
            UAPPKit.windowPresenter = previousPresenter
            UAPPKit.makeTransport = previousTransport
            UAPPKit.urlOpener = previousOpener
            UAPPKit.reset()
        }
        UAPPKit.windowPresenter = presenter
        UAPPKit.makeTransport = { StubTransport { _ in response("{}") } }
        UAPPKit.urlOpener = { _ in true }
        let host = try #require(URL(string: "https://commands.example"))
        UAPPKit.setup(projectId: "commands-test", host: host)

        for item in UAPPKitCommands.Item.allCases {
            UAPPKitCommands.perform(item)
        }
        await Task.yield()
        #expect(Set(presenter.windows.keys) == [.feedback, .roadmap, .changelog, .reviews, .developerAbout])
    }

    @Test("No Mac, UAPPKit abre cada tela pública em uma janela própria")
    @MainActor
    func appKitPresentsEveryScreenInMacWindows() async throws {
        let presenter = UAPPMacWindowPresenter()
        presenter.ordersWindowsFront = false
        let previousPresenter = UAPPKit.windowPresenter
        let previousTransport = UAPPKit.makeTransport
        defer {
            presenter.closeAll()
            UAPPKit.windowPresenter = previousPresenter
            UAPPKit.makeTransport = previousTransport
            UAPPKit.reset()
        }
        UAPPKit.windowPresenter = presenter
        UAPPKit.makeTransport = { StubTransport { _ in response("{}") } }
        let host = try #require(URL(string: "https://mac-windows.example"))
        UAPPKit.setup(projectId: "mac-windows-test", host: host, theme: .init(light: .init(accent: .purple)))
        let authentication = StubAuthentication()
        let session = UAPPAuthenticationSession(identity: .init(userId: "verified"), accessToken: "token")

        try UAPPKit.showFeedback()
        try await UAPPKit.showFeedback(authentication: authentication)
        try await UAPPKit.showFeedback(accessTokenProvider: { "token" })
        try UAPPKit.showRoadmap()
        try await UAPPKit.showRoadmap(authentication: authentication)
        try await UAPPKit.showRoadmap(accessTokenProvider: nil)
        try UAPPKit.showChangelog()
        try UAPPKit.showReviews(pageSize: 10)
        try UAPPKit.showAbout(configuration: .init(showsChangelog: true))
        try UAPPKit.showDeveloperAbout()
        try UAPPKit.showUser(session: session, authentication: authentication)
        try UAPPKit.showAuthentication(authentication: authentication)

        #expect(Set(presenter.windows.keys) == Set(UAPPPresentedScreen.allCases))
        let feedback = try #require(presenter.windows[.feedback])
        #expect(feedback.contentViewController is NSHostingController<AnyView>)
    }
    #endif

    #if canImport(UIKit) && canImport(SwiftUI)
    @Test("UAPPKit apresenta uma tela nativa pelo presenter disponível")
    @MainActor
    func appKitPresentsNativeScreen() throws {
        let presenter = PresentationProbeViewController()
        let previousProvider = UAPPKit.presenterProvider
        defer {
            UAPPKit.presenterProvider = previousProvider
            UAPPKit.reset()
        }

        let host = try #require(URL(string: "https://presentation.example"))
        UAPPKit.presenterProvider = { presenter }
        UAPPKit.setup(projectId: "presentation-test", host: host)

        try UAPPKit.showAbout()

        #expect(presenter.presentedViewControllerCount == 1)
        #expect(presenter.lastPresentedViewController?.modalPresentationStyle == .pageSheet)
        #expect(presenter.lastPresentedViewController?.sheetPresentationController?.detents.count == 1)
        #expect(presenter.lastPresentedViewController?.sheetPresentationController?.detents.first?.identifier == .large)
    }

    @Test("UAPPKit apresenta todas as telas públicas com conta, token e configuração")
    @MainActor
    func appKitPresentsEveryScreen() async throws {
        let presenter = PresentationProbeViewController()
        let previousProvider = UAPPKit.presenterProvider
        let previousTransport = UAPPKit.makeTransport
        defer {
            UAPPKit.presenterProvider = previousProvider
            UAPPKit.makeTransport = previousTransport
            UAPPKit.reset()
        }
        UAPPKit.presenterProvider = { presenter }
        UAPPKit.makeTransport = { StubTransport { _ in response("{}") } }
        let host = try #require(URL(string: "https://screens.example"))
        UAPPKit.setup(projectId: "screens-test", host: host, theme: .init(light: .init(accent: .purple)))
        let authentication = StubAuthentication()
        let session = UAPPAuthenticationSession(identity: .init(userId: "verified"), accessToken: "token")
        let callback = try #require(URL(string: "uappkit-test://auth"))
        _ = try UAPPKit.makeAuthentication(callbackURL: callback)

        try UAPPKit.showFeedback()
        try UAPPKit.showUser(session: session, authentication: authentication)
        try UAPPKit.showAuthentication(authentication: authentication)
        try await UAPPKit.showFeedback(authentication: authentication)
        try await UAPPKit.showFeedback(accessTokenProvider: { "token" })
        try UAPPKit.showRoadmap()
        try await UAPPKit.showRoadmap(authentication: authentication)
        try await UAPPKit.showRoadmap(accessTokenProvider: nil)
        try UAPPKit.showChangelog()
        try UAPPKit.showReviews(pageSize: 10)
        try UAPPKit.showAbout(configuration: .init(showsChangelog: true))
        try UAPPKit.showDeveloperAbout()

        #expect(presenter.presentedViewControllerCount == 12)
        let hosted = try #require(presenter.lastPresentedViewController)
        hosted.overrideUserInterfaceStyle = .dark
        hosted.view.layoutIfNeeded()
        #expect(hosted.view.backgroundColor != nil)
    }

    @Test("UAPPKit não falha quando não há presenter ativo")
    @MainActor
    func appKitPresentationWithoutActivePresenterIsSafe() throws {
        defer {
            UAPPKit.reset()
        }

        let host = try #require(URL(string: "https://no-presenter.example"))
        UAPPKit.setup(
            projectId: "no-presenter-test",
            host: host
        )

        try UAPPKit.showFeedback()
        try UAPPKit.showRoadmap()
        try UAPPKit.showChangelog()
        try UAPPKit.showReviews(pageSize: 20)
        try UAPPKit.showAbout()
    }
    #endif
}

@Test("UAPPKit.version acompanha a versão atual do CHANGELOG.md")
func kitVersionMatchesChangelog() throws {
    let changelogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("CHANGELOG.md")
    let changelog = try String(contentsOf: changelogURL, encoding: .utf8)
    // Mesma regra do workflow de tag: o primeiro título `## X.Y.Z` é a versão atual.
    let current = changelog.split(separator: "\n").lazy.compactMap { line -> String? in
        guard line.hasPrefix("## ") else { return nil }
        let version = line.dropFirst(3).split(separator: " ").first.map(String.init) ?? ""
        let parts = version.split(separator: ".")
        guard parts.count == 3, parts.allSatisfy({ Int($0) != nil }) else { return nil }
        return version
    }.first
    #expect(UAPPKit.version == current)
}
