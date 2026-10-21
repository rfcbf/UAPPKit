#if os(macOS)
import ImageIO
import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@MainActor
struct UAPPProfilePhotoCropperTests {
    private func image(width: Int = 640, height: Int = 320) throws -> CGImage {
        let data = sampleJPEG(width: width, height: height)
        return try #require(UAPPProfilePhotoCropper.orientedImage(from: data))
    }

    @Test("Em zoom 1, a menor dimensão da foto preenche o recorte")
    func displayScaleFillsViewport() throws {
        let photo = try image()
        #expect(UAPPProfilePhotoCropper.displayScale(for: photo, zoom: 1, side: 320) == 1)
        #expect(UAPPProfilePhotoCropper.displayScale(for: photo, zoom: 2, side: 320) == 2)
        // Valores fora da faixa do controle são limitados.
        #expect(UAPPProfilePhotoCropper.displayScale(for: photo, zoom: 10, side: 320) == 4)
        #expect(UAPPProfilePhotoCropper.displayScale(for: photo, zoom: 0.1, side: 320) == 1)
    }

    @Test("O deslocamento mantém a foto cobrindo todo o recorte")
    func offsetIsClampedToImageBounds() throws {
        let photo = try image()
        let clamped = UAPPProfilePhotoCropper.clampedOffset(
            CGSize(width: 1000, height: 1000), image: photo, zoom: 1, side: 320
        )
        #expect(clamped == CGSize(width: 160, height: 0))
        let zoomed = UAPPProfilePhotoCropper.clampedOffset(
            CGSize(width: -1000, height: -1000), image: photo, zoom: 2, side: 320
        )
        #expect(zoomed == CGSize(width: -480, height: -160))
    }

    @Test("O recorte devolve um quadrado do trecho visível")
    func croppedImageIsSquare() throws {
        let photo = try image()
        let centered = try #require(UAPPProfilePhotoCropper.croppedImageData(photo, zoom: 1, offset: .zero, side: 320))
        let source = try #require(CGImageSourceCreateWithData(centered as CFData, nil))
        let cropped = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(cropped.width == 320)
        #expect(cropped.height == 320)

        let zoomed = try #require(UAPPProfilePhotoCropper.croppedImageData(
            photo, zoom: 2, offset: CGSize(width: 400, height: 50), side: 320
        ))
        let zoomedSource = try #require(CGImageSourceCreateWithData(zoomed as CFData, nil))
        let zoomedImage = try #require(CGImageSourceCreateImageAtIndex(zoomedSource, 0, nil))
        #expect(zoomedImage.width == 160)
        #expect(zoomedImage.height == 160)
        #expect(UAPPProfileImageProcessor.compressedJPEG(from: zoomed) != nil)
    }

    @Test("Dados que não são imagem não abrem o recorte")
    func invalidDataHasNoImage() {
        #expect(UAPPProfilePhotoCropper.orientedImage(from: Data("não é imagem".utf8)) == nil)
    }

    @Test("O recorte constrói a interface com a foto")
    func cropperRenders() async throws {
        var result: Data??
        var cancelled = false
        try await render(UAPPProfilePhotoCropper(
            image: image(width: 300, height: 600),
            accent: .purple,
            localized: { uappLocalized($0, languageIdentifier: "pt-BR") },
            onCancel: { cancelled = true },
            onCrop: { result = $0 }
        ))
        #expect(result == nil)
        #expect(!cancelled)
    }
}

@MainActor
struct UAPPProfilePhotoPickerMacTests {
    @Test("Seletor do Mac mostra foto, ausência de foto, processamento, erro e recorte")
    func pickerStatesRender() async throws {
        var photo: Data? = sampleJPEG()
        let binding = Binding(get: { photo }, set: { photo = $0 })
        await render(UAPPProfilePhotoPicker(photo: binding, theme: .init(light: .init(accent: .purple))))
        await render(UAPPProfilePhotoPicker(photo: .constant(nil), languageIdentifier: "en").controlSize(.small))
        await render(UAPPProfilePhotoPicker(photo: .constant(nil), isProcessing: true, errorKey: nil))
        await render(UAPPProfilePhotoPicker(
            photo: .constant(nil), languageIdentifier: "xx", isProcessing: false, errorKey: "photo.error"
        ))
        let cropImage = try #require(UAPPProfilePhotoCropper.orientedImage(from: sampleJPEG()))
        await render(UAPPProfilePhotoPicker(
            photo: .constant(nil), isProcessing: false, errorKey: nil, cropImage: cropImage
        ))
        #expect(photo != nil)
    }

    @Test("Avatar editável do Mac mostra foto local, URL remota e remoção")
    func avatarOnlyStatesRender() async {
        var reported: [String?] = []
        let avatarOnly = UAPPProfilePhotoPicker.AvatarOnly(
            remoteURL: URL(string: "https://example.test/avatar.jpg"), size: 104,
            onError: { reported.append($0) }, onRemove: {}
        )
        await render(UAPPProfilePhotoPicker(
            photo: .constant(sampleJPEG()), theme: .system, languageIdentifier: "pt-BR", avatarOnly: avatarOnly
        ))
        await render(UAPPProfilePhotoPicker(
            photo: .constant(nil), remoteURL: nil, size: 56, languageIdentifier: "en", onRemove: {}
        ))
        #expect(reported.isEmpty)
    }

    @Test("Arquivo ou dados inválidos mostram o aviso de foto")
    func preparingInvalidSourcesReportsError() {
        let picker = UAPPProfilePhotoPicker(photo: .constant(nil))
        picker.prepare(nil)
        picker.prepare(Data("inválido".utf8))
        picker.prepare(sampleJPEG())
        picker.prepareFile(.failure(TestError.expected))
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("uapp-sem-foto.jpg")
        picker.prepareFile(.success(missing))
    }
}
#endif
