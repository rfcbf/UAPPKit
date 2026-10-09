#if os(iOS)
import AVFoundation
import Mantis
import PhotosUI
import SwiftUI
import UIKit

/// Seleção de foto com biblioteca/câmera, edição circular e compressão no kit.
@MainActor
public struct UAPPProfilePhotoPicker: View {
    @Binding private var photo: Data?
    @State private var selection: PhotosPickerItem?
    @State private var showsLibrary = false
    @State private var showsCamera = false
    @State private var cameraImage: UIImage?
    @State private var imageToCrop: UIImage?
    @State private var isProcessing = false
    @State private var errorKey: String?
    @State private var showsPermissionAlert = false
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlSize) private var controlSize
    private let theme: UAPPTheme
    private let languageIdentifier: String?
    private let avatarOnly: AvatarOnly?

    /// Apresentação reduzida ao avatar editável, usada no cabeçalho do perfil conectado.
    /// Exibe `remoteURL` enquanto não há foto local. Com `onError`, os erros são repassados em vez de
    /// aparecerem em aviso; com `onRemove`, o menu oferece remover a foto atual.
    struct AvatarOnly {
        var remoteURL: URL?
        var size: CGFloat
        var onError: (@MainActor (String?) -> Void)?
        var onRemove: (@MainActor () -> Void)?

        init(
            remoteURL: URL?,
            size: CGFloat,
            onError: (@MainActor (String?) -> Void)? = nil,
            onRemove: (@MainActor () -> Void)? = nil
        ) {
            self.remoteURL = remoteURL
            self.size = size
            self.onError = onError
            self.onRemove = onRemove
        }
    }

    public init(photo: Binding<Data?>, theme: UAPPTheme = .system, languageIdentifier: String? = nil) {
        _photo = photo
        self.theme = theme
        self.languageIdentifier = languageIdentifier
        avatarOnly = nil
    }

    /// Avatar editável sem o texto de apoio, para o aplicativo encaixar no próprio formulário.
    /// Mostra `remoteURL` enquanto não há foto escolhida. Com `onRemove`, o menu oferece remover a
    /// foto atual: a foto escolhida é descartada e a ação é chamada para o aplicativo limpar a remota.
    public init(
        photo: Binding<Data?>,
        remoteURL: URL?,
        size: CGFloat = 104,
        theme: UAPPTheme = .system,
        languageIdentifier: String? = nil,
        onRemove: (@MainActor () -> Void)? = nil
    ) {
        self.init(
            photo: photo,
            theme: theme,
            languageIdentifier: languageIdentifier,
            avatarOnly: AvatarOnly(remoteURL: remoteURL, size: size, onRemove: onRemove)
        )
    }

    init(photo: Binding<Data?>, theme: UAPPTheme, languageIdentifier: String?, avatarOnly: AvatarOnly) {
        _photo = photo
        self.theme = theme
        self.languageIdentifier = languageIdentifier
        self.avatarOnly = avatarOnly
    }

    /// Estado inicial injetável para renderizar processamento e erros nos testes.
    init(
        photo: Binding<Data?>,
        theme: UAPPTheme = .system,
        languageIdentifier: String? = nil,
        isProcessing: Bool,
        errorKey: String?
    ) {
        self.init(photo: photo, theme: theme, languageIdentifier: languageIdentifier)
        _isProcessing = State(initialValue: isProcessing)
        _errorKey = State(initialValue: errorKey)
    }

    private var accent: Color {
        theme.resolved(for: colorScheme).accent ?? .accentColor
    }

    private var avatarSize: CGFloat {
        if let avatarOnly {
            return avatarOnly.size
        }
        return controlSize == .small || controlSize == .mini ? 56 : 88
    }

    private var cameraBadgeSize: CGFloat {
        if avatarOnly != nil {
            return 36
        }
        return controlSize == .small || controlSize == .mini ? 24 : 36
    }

    public var body: some View {
        Group {
            if avatarOnly != nil {
                photoMenu
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        photoMenu
                        if isProcessing {
                            Text(verbatim: localized("photo.processing"))
                                .font(.footnote).foregroundStyle(.secondary)
                        } else {
                            Text(verbatim: localized("photo.hint"))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .uappOnChange(of: errorKey) { key in avatarOnly?.onError?(key) }
        .photosPicker(isPresented: $showsLibrary, selection: $selection, matching: .images)
        .uappToast(message: Binding(
            get: { avatarOnly?.onError == nil ? errorKey.map { localized($0) } : nil },
            set: {
                if $0 == nil {
                    errorKey = nil
                }
            }
        ))
        .uappToast(
            message: Binding(
                get: { showsPermissionAlert ? localized("photo.camera_denied") : nil },
                set: {
                    if $0 == nil {
                        showsPermissionAlert = false
                    }
                }
            ),
            title: localized("photo.camera_access"),
            actionTitle: localized("photo.settings"),
            action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        )
        .task(id: selection) {
            guard let selection else { return }
            isProcessing = true
            errorKey = nil
            defer {
                isProcessing = false
                self.selection = nil
            }
            do {
                guard let data = try await selection.loadTransferable(type: Data.self),
                      let image = UIImage(data: data)
                else {
                    errorKey = "photo.error"
                    return
                }
                guard !Task.isCancelled else { return }
                imageToCrop = image
            } catch {
                if !Task.isCancelled {
                    errorKey = "photo.error"
                }
            }
        }
        .sheet(isPresented: $showsCamera, onDismiss: {
            if let cameraImage {
                imageToCrop = cameraImage
                self.cameraImage = nil
            }
        }) {
            UAPPProfileCameraPicker { image in
                cameraImage = image
                showsCamera = false
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: Binding(
            get: { imageToCrop != nil },
            set: {
                if !$0 {
                    imageToCrop = nil
                }
            }
        )) {
            if let imageToCrop {
                ImageCropper(image: imageToCrop)
                    .cropShape(.circle)
                    .aspectRatio(.fixed(1))
                    .onCrop { result in
                        if let data = UAPPProfileImageProcessor.compressedJPEG(from: result.croppedImage) {
                            photo = data
                        } else {
                            errorKey = "photo.error"
                        }
                        self.imageToCrop = nil
                    }
                    .onCancel { self.imageToCrop = nil }
            }
        }
    }

    private var photoMenu: some View {
        Menu {
            Button { showsLibrary = true } label: {
                Label(localized("photo.library"), systemImage: "photo.on.rectangle")
            }
            Button { Task { await openCamera() } } label: {
                Label(localized("photo.camera"), systemImage: "camera")
            }
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            if canRemove {
                Button(role: .destructive) {
                    photo = nil
                    avatarOnly?.onRemove?()
                } label: {
                    Label(localized("photo.remove"), systemImage: "trash")
                }
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                avatar
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                Image(systemName: "camera.fill")
                    .font(.system(size: cameraBadgeSize == 24 ? 12 : 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: cameraBadgeSize, height: cameraBadgeSize)
                    .background(accent, in: Circle())
                    .accessibilityHidden(true)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: localized("photo.change")))
        .accessibilityValue(isProcessing ? Text(verbatim: localized("photo.processing")) : Text(verbatim: ""))
        .disabled(isProcessing)
    }

    /// No formulário completo, remove a foto escolhida; no avatar, só quando o aplicativo trata a remoção.
    private var canRemove: Bool {
        guard let avatarOnly else { return photo != nil }
        return avatarOnly.onRemove != nil && (photo != nil || avatarOnly.remoteURL != nil)
    }

    @ViewBuilder
    private var avatar: some View {
        if isProcessing {
            UAPPImageLoadingPlaceholder()
        } else if let photo, let image = UIImage(data: photo) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let url = avatarOnly?.remoteURL {
            UAPPCachedImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else if phase.error != nil {
                    emptyAvatar
                } else {
                    UAPPImageLoadingPlaceholder()
                }
            }
        } else {
            emptyAvatar
        }
    }

    private var emptyAvatar: some View {
        Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundStyle(.secondary)
    }

    private func openCamera() async {
        errorKey = nil
        let access = await Self.cameraAccess()
        guard !Task.isCancelled else { return }
        switch access {
        case .allowed:
            showsCamera = true
        case .unavailable:
            errorKey = "photo.camera_unavailable"
        case .denied:
            errorKey = "photo.camera_denied"
            showsPermissionAlert = true
        }
    }

    enum CameraAccess: Equatable { case allowed, denied, unavailable }

    /// Exige a descrição de uso da câmera no app e pede permissão apenas quando ainda não foi decidida.
    static func cameraAccess(
        usageDescription: String? = Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String,
        status: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video),
        requestAccess: () async -> Bool = { await AVCaptureDevice.requestAccess(for: .video) }
    ) async -> CameraAccess {
        guard usageDescription != nil else { return .unavailable }
        switch status {
        case .authorized: return .allowed
        case .notDetermined: return await requestAccess() ? .allowed : .denied
        default: return .denied
        }
    }

    private func localized(_ key: String) -> String {
        let identifier = languageIdentifier ?? locale.identifier
        let value = uappLocalized(key, languageIdentifier: identifier)
        return value == key ? uappLocalized(key, languageIdentifier: "en") : value
    }
}

@MainActor
struct UAPPProfileCameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}
    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage?) -> Void
        init(onImage: @escaping (UIImage?) -> Void) {
            self.onImage = onImage
        }

        func imagePickerController(
            _: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onImage(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            onImage(nil)
        }
    }
}
#endif
