import Foundation
import SwiftUI
import Testing
@testable import UAPPKit

@MainActor
struct UAPPApplicationIconTests {
    private let palette = UAPPTheme.system.resolved(for: .light)

    @Test("Ícone remoto carrega imagem local e volta ao ícone do app quando falha")
    func remoteIconRenders() async throws {
        let icon = try temporaryFile(sampleJPEG(width: 32, height: 32))
        defer { try? FileManager.default.removeItem(at: icon) }
        await render(UAPPApplicationIcon(palette: palette, remoteURL: icon), settling: true)
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("uappkit-icone-ausente.png")
        await render(UAPPApplicationIcon(palette: palette, remoteURL: missing), settling: true)
        await render(UAPPApplicationIcon(palette: palette, remoteURL: nil))
    }

    #if canImport(UIKit)
    @Test("Busca local consulta o catálogo do bundle e ignora bundles sem ícone")
    func localIconLookup() {
        #expect(UAPPApplicationIcon.iconNames(from: .module).isEmpty)
        #expect(UAPPApplicationIcon.loadUIKitImage(from: .module) == nil)
        #expect(UAPPApplicationIcon.loadUIKitImage(from: Bundle(for: BundleToken.self)) == nil)
    }
    #endif
}

private final class BundleToken {}
