import Foundation
import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

/// Telas de anexos do feedback renderizadas com imagens locais, sem rede.
@MainActor
struct UAPPFeedbackImageViewsTests {
    private let palette = UAPPTheme.system.resolved(for: .light)

    @Test("Galeria carrega imagem local, mostra falha e organiza as miniaturas")
    func galleryRendersLoadedAndFailedImages() async throws {
        let valid = try temporaryFile(sampleJPEG())
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("uappkit-ausente.jpg")
        defer { try? FileManager.default.removeItem(at: valid) }
        await render(UAPPFeedbackImageGallery(urls: [valid, missing]), settling: true)
        await render(UAPPFeedbackImageGallery(urls: []))
        await render(ScrollView(.horizontal) { UAPPFeedbackImageGallery(urls: [valid]) }, settling: true)
    }

    @Test("Seletor compacto mostra miniaturas válidas e ignora dados inválidos")
    func compactPickerRendersThumbnails() async {
        var data = [sampleJPEG(), Data([0x00, 0x01])]
        var isProcessing = false
        let dataBinding = Binding(get: { data }, set: { data = $0 })
        let processingBinding = Binding(get: { isProcessing }, set: { isProcessing = $0 })
        await render(UAPPFeedbackImagePicker(data: dataBinding, isProcessing: processingBinding))
        isProcessing = true
        await render(UAPPFeedbackImagePicker(data: dataBinding, isProcessing: processingBinding))
        #expect(data.count == 2)
    }

    @Test("Anexos do compositor mostram miniaturas, processamento e limite")
    func composerAttachmentsRender() async {
        for (images, processing) in [([sampleJPEG()], false), ([sampleJPEG(), sampleJPEG()], false), ([], true)] {
            var data = images
            var isProcessing = processing
            await render(UAPPFeedbackComposerAttachments(
                data: Binding(get: { data }, set: { data = $0 }),
                isProcessing: Binding(get: { isProcessing }, set: { isProcessing = $0 }),
                accent: .orange, palette: palette
            ))
            await render(UAPPFeedbackComposerAttachments(
                data: Binding(get: { data }, set: { data = $0 }),
                isProcessing: .constant(processing), accent: .orange, palette: palette
            ).disabled(true).environment(\.colorScheme, .dark))
        }
    }

    @Test("Avatar usa iniciais sem foto e imagem local quando disponível")
    func avatarRenders() async throws {
        let photo = try temporaryFile(sampleJPEG())
        defer { try? FileManager.default.removeItem(at: photo) }
        await render(UAPPFeedbackAvatar(name: "Ana Maria Souza", url: nil))
        await render(UAPPFeedbackAvatar(name: "Ana", url: photo, size: 56), settling: true)
    }

    @Test("Preparação recusa dados que não formam imagem")
    func preparationRejectsInvalidData() {
        #expect(throws: UAPPKitError.invalidResponse) { try UAPPFeedbackImagePreparation.jpeg(from: Data()) }
        #expect(throws: UAPPKitError.invalidResponse) {
            try UAPPFeedbackImagePreparation.jpeg(from: Data([0xFF, 0xD8, 0xFF, 0xE0]))
        }
        #expect((try? UAPPFeedbackImagePreparation.jpeg(from: sampleJPEG())) != nil)
    }
}
