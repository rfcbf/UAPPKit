import Foundation
import Testing
@testable import UAPPKit

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

        #if canImport(UIKit) && canImport(SwiftUI)
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
        UAPPKit.reset()
        for _ in 0 ..< 100 {
            if await client.currentIdentity() == nil {
                break
            }
            await Task.yield()
        }
        #expect(await client.currentIdentity() == nil)
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
