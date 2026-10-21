#if os(macOS)
import AppKit
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Seleção de foto no Mac: app Fotos ou arquivo do Finder, recorte circular ajustável e
/// compressão no kit. Mesma API do iPhone e do iPad; a câmera não é oferecida no Mac.
@MainActor
public struct UAPPProfilePhotoPicker: View {
    @Binding private var photo: Data?
    @State private var selection: PhotosPickerItem?
    @State private var showsLibrary = false
    @State private var showsFileImporter = false
    @State private var cropSource: UAPPProfileCropSource?
    @State private var isProcessing = false
    @State private var errorKey: String?
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

    /// Estado inicial injetável para renderizar processamento, erros e o recorte nos testes.
    init(
        photo: Binding<Data?>,
        theme: UAPPTheme = .system,
        languageIdentifier: String? = nil,
        isProcessing: Bool,
        errorKey: String?,
        cropImage: CGImage? = nil
    ) {
        self.init(photo: photo, theme: theme, languageIdentifier: languageIdentifier)
        _isProcessing = State(initialValue: isProcessing)
        _errorKey = State(initialValue: errorKey)
        _cropSource = State(initialValue: cropImage.map(UAPPProfileCropSource.init(image:)))
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

    private var badgeSize: CGFloat {
        avatarSize < 72 ? 22 : 30
    }

    public var body: some View {
        Group {
            if avatarOnly != nil {
                photoMenu
            } else {
                HStack(spacing: 16) {
                    photoMenu
                    Text(verbatim: localized(isProcessing ? "photo.processing" : "photo.hint"))
                        .font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .uappOnChange(of: errorKey) { key in avatarOnly?.onError?(key) }
        .photosPicker(isPresented: $showsLibrary, selection: $selection, matching: .images)
        .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.image]) { result in
            prepareFile(result)
        }
        .uappToast(message: Binding(
            get: { avatarOnly?.onError == nil ? errorKey.map { localized($0) } : nil },
            set: {
                if $0 == nil {
                    errorKey = nil
                }
            }
        ))
        .task(id: selection) {
            guard let selection else { return }
            isProcessing = true
            errorKey = nil
            defer {
                isProcessing = false
                self.selection = nil
            }
            do {
                let data = try await selection.loadTransferable(type: Data.self)
                guard !Task.isCancelled else { return }
                prepare(data)
            } catch {
                if !Task.isCancelled {
                    errorKey = "photo.error"
                }
            }
        }
        .sheet(item: $cropSource) { source in
            UAPPProfilePhotoCropper(
                image: source.image,
                accent: accent,
                localized: localized,
                onCancel: { cropSource = nil },
                onCrop: { data in
                    if let data, let compressed = UAPPProfileImageProcessor.compressedJPEG(from: data) {
                        photo = compressed
                    } else {
                        errorKey = "photo.error"
                    }
                    cropSource = nil
                }
            )
        }
    }

    private var photoMenu: some View {
        Menu {
            Button { showsLibrary = true } label: {
                Label(localized("photo.library"), systemImage: "photo.on.rectangle")
            }
            Button { showsFileImporter = true } label: {
                Label(localized("photo.choose_file"), systemImage: "folder")
            }
            if canRemove {
                Divider()
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
                    .font(.system(size: badgeSize * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: badgeSize, height: badgeSize)
                    .background(accent, in: Circle())
                    .accessibilityHidden(true)
            }
            .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(Text(verbatim: localized("photo.change")))
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
        } else if let photo, let image = NSImage(data: photo) {
            Image(nsImage: image).resizable().scaledToFill()
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

    /// Lê o arquivo escolhido no Finder, que fica fora da sandbox até o acesso ser liberado.
    func prepareFile(_ result: Result<URL, any Error>) {
        guard case let .success(url) = result else {
            errorKey = "photo.error"
            return
        }
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        prepare(try? Data(contentsOf: url))
    }

    /// Abre o recorte com a imagem já orientada e reduzida, ou avisa quando ela não pode ser lida.
    func prepare(_ data: Data?) {
        guard let data, let image = UAPPProfilePhotoCropper.orientedImage(from: data) else {
            errorKey = "photo.error"
            return
        }
        errorKey = nil
        cropSource = UAPPProfileCropSource(image: image)
    }

    private func localized(_ key: String) -> String {
        let identifier = languageIdentifier ?? locale.identifier
        let value = uappLocalized(key, languageIdentifier: identifier)
        return value == key ? uappLocalized(key, languageIdentifier: "en") : value
    }
}

/// Imagem aguardando o recorte; cada escolha abre uma sheet nova.
struct UAPPProfileCropSource: Identifiable {
    let id = UUID()
    let image: CGImage
}
#endif
