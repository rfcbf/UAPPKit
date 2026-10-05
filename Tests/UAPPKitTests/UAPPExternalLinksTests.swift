import Foundation
import Testing
@testable import UAPPKit

@MainActor
private final class OpenerRecorder {
    var opened: [URL] = []
    var accepted: Set<String> = []

    func open(_ url: URL) async -> Bool {
        opened.append(url)
        return accepted.contains(url.scheme ?? "")
    }
}

@MainActor
struct UAPPExternalLinksTests {
    @Test("Link aceito pelo sistema não tenta alternativa")
    func acceptedLinkOpensOnce() async throws {
        let recorder = OpenerRecorder()
        recorder.accepted = ["https"]
        let url = try #require(URL(string: "https://example.test/terms"))
        #expect(await uappOpenExternalURLAndReportSuccess(url, opener: recorder.open))
        #expect(recorder.opened == [url])
    }

    @Test("App Store recusada abre a página web equivalente")
    func appStoreFallsBackToWeb() async throws {
        let recorder = OpenerRecorder()
        recorder.accepted = ["https"]
        let url = try #require(URL(string: "itms-apps://itunes.apple.com/app/id123456789?action=write-review"))
        #expect(await uappOpenExternalURLAndReportSuccess(url, opener: recorder.open))
        #expect(recorder.opened.map(\.absoluteString) == [
            url.absoluteString,
            "https://apps.apple.com/app/id123456789?action=write-review"
        ])
    }

    @Test("Falha sem alternativa e falha da alternativa informam erro")
    func failuresReportFalse() async throws {
        let recorder = OpenerRecorder()
        let web = try #require(URL(string: "https://example.test"))
        #expect(await !uappOpenExternalURLAndReportSuccess(web, opener: recorder.open))
        let store = try #require(URL(string: "itms-apps://apps.apple.com/app/id123456789"))
        #expect(await !uappOpenExternalURLAndReportSuccess(store, opener: recorder.open))
        #expect(recorder.opened.count == 3)
        #expect(recorder.opened.last?.absoluteString == "https://apps.apple.com/app/id123456789")
    }

    @Test("Somente links itms-apps recebem alternativa web")
    func fallbackOnlyForAppStoreScheme() throws {
        #expect(try uappAppStoreWebFallback(for: #require(URL(string: "https://example.test"))) == nil)
        #expect(try uappAppStoreWebFallback(for: #require(URL(string: "mailto:suporte@example.test"))) == nil)
        #expect(try uappAppStoreWebFallback(for: #require(URL(string: "ITMS-APPS://apps.apple.com/app/id1")))?
            .absoluteString == "https://apps.apple.com/app/id1")
    }
}
