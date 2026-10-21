#if os(iOS)
import AVFoundation
import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit
import UIKit

@MainActor
struct UAPPProfilePhotoPickerTests {
    @Test("Seletor mostra foto, ausência de foto, processamento e erro")
    func pickerStatesRender() async {
        var photo: Data? = sampleJPEG()
        let binding = Binding(get: { photo }, set: { photo = $0 })
        await render(UAPPProfilePhotoPicker(photo: binding, theme: .init(light: .init(accent: .purple))))
        await render(UAPPProfilePhotoPicker(photo: .constant(nil), languageIdentifier: "en").controlSize(.small))
        await render(UAPPProfilePhotoPicker(photo: .constant(nil), isProcessing: true, errorKey: nil))
        await render(UAPPProfilePhotoPicker(
            photo: .constant(nil),
            languageIdentifier: "xx",
            isProcessing: false,
            errorKey: "photo.camera_denied"
        ))
        #expect(photo != nil)
    }

    @Test("Avatar editável do perfil mostra foto local, URL remota e ausência de foto")
    func avatarOnlyStatesRender() async {
        var reported: [String?] = []
        let avatarOnly = UAPPProfilePhotoPicker.AvatarOnly(
            remoteURL: URL(string: "https://example.test/avatar.jpg"), size: 104
        ) { reported.append($0) }
        await render(UAPPProfilePhotoPicker(
            photo: .constant(sampleJPEG()),
            theme: .system,
            languageIdentifier: "pt-BR",
            avatarOnly: avatarOnly
        ))
        await render(UAPPProfilePhotoPicker(
            photo: .constant(nil),
            theme: .system,
            languageIdentifier: "en",
            avatarOnly: avatarOnly
        ))
        await render(UAPPProfilePhotoPicker(
            photo: .constant(nil),
            theme: .init(light: .init(accent: .purple)),
            languageIdentifier: nil,
            avatarOnly: .init(remoteURL: nil, size: 56) { _ in }
        ))
        #expect(reported.isEmpty)
    }

    @Test("Câmera exige descrição de uso e respeita a permissão do sistema")
    func cameraAccessRules() async {
        typealias Picker = UAPPProfilePhotoPicker
        #expect(await Picker.cameraAccess(usageDescription: nil, status: .authorized) { true } == .unavailable)
        #expect(await Picker.cameraAccess(usageDescription: "Foto", status: .authorized) { false } == .allowed)
        #expect(await Picker.cameraAccess(usageDescription: "Foto", status: .notDetermined) { true } == .allowed)
        #expect(await Picker.cameraAccess(usageDescription: "Foto", status: .notDetermined) { false } == .denied)
        #expect(await Picker.cameraAccess(usageDescription: "Foto", status: .denied) { true } == .denied)
        #expect(await Picker.cameraAccess(usageDescription: "Foto", status: .restricted) { true } == .denied)
    }

    @Test("Coordenador da câmera entrega a foto tirada ou nada ao cancelar")
    func cameraCoordinatorDeliversImage() {
        var received: [UIImage?] = []
        let picker = UAPPProfileCameraPicker { received.append($0) }
        let coordinator = picker.makeCoordinator()
        let controller = UIImagePickerController()
        let image = UIImage(data: sampleJPEG())
        coordinator.imagePickerController(controller, didFinishPickingMediaWithInfo: [.originalImage: image as Any])
        coordinator.imagePickerControllerDidCancel(controller)
        #expect(received.count == 2)
        #expect(received.first??.size == image?.size)
        #expect(received.last == nil)
    }

    @Test("Avatar público mostra a foto remota e oferece remover quando o aplicativo trata a remoção")
    func publicAvatarRendersWithAndWithoutRemoval() async {
        var removed = 0
        await render(UAPPProfilePhotoPicker(
            photo: .constant(nil),
            remoteURL: URL(string: "https://example.test/avatar.jpg"),
            onRemove: { removed += 1 }
        ))
        await render(UAPPProfilePhotoPicker(photo: .constant(sampleJPEG()), remoteURL: nil, size: 72))
        #expect(removed == 0)
    }
}
#endif
