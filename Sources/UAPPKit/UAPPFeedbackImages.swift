#if canImport(SwiftUI)
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
#if canImport(PhotosUI)
import PhotosUI
#endif

struct UAPPFeedbackAvatar: View {
    let name: String
    let url: URL?
    var size: CGFloat = 40
    @Environment(\.uappTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        UAPPCachedImage(url: url) { phase in
            switch phase {
            case let .success(image): image.resizable().scaledToFill()
            case .empty where url != nil: UAPPImageLoadingPlaceholder()
            default:
                Text(verbatim: initials)
                    .font(.system(size: size * 0.32, weight: .semibold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.resolved(for: colorScheme).secondaryText.opacity(0.07))
            }
        }
        .frame(width: size, height: size).clipShape(Circle())
        .accessibilityLabel(Text(verbatim: name))
    }

    private var initials: String {
        name.split(whereSeparator: \.isWhitespace).prefix(2)
            .compactMap(\.first).map(String.init).joined().uppercased()
    }
}

struct UAPPFeedbackAttachment: Identifiable {
    let url: URL

    var id: String {
        guard url.path.contains("/storage/v1/object/sign/feedback-images/"),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return url.absoluteString
        }
        components.query = nil
        components.fragment = nil
        return components.string ?? url.absoluteString
    }
}

struct UAPPFeedbackImageGallery: View {
    let urls: [URL]

    var body: some View {
        UAPPFeedbackImageRow {
            ForEach(urls.map { UAPPFeedbackAttachment(url: $0) }) { attachment in
                UAPPFeedbackRemoteImage(url: attachment.url)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct UAPPFeedbackImageRow: Layout {
    private let spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let sizes = imageSizes(width: proposal.width, subviews: subviews)
        return CGSize(
            width: sizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(0, sizes.count - 1)),
            height: sizes.map(\.height).max() ?? 0
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let sizes = imageSizes(width: proposal.width, subviews: subviews)
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(sizes[index])
            )
            x += sizes[index].width + spacing
        }
    }

    private func imageSizes(width: CGFloat?, subviews: Subviews) -> [CGSize] {
        guard !subviews.isEmpty else { return [] }
        let gaps = spacing * CGFloat(subviews.count - 1)
        let available = max(0, (width ?? (140 * CGFloat(subviews.count) + gaps)) - gaps)
        let imageWidth = min(140, available / CGFloat(subviews.count))
        return subviews.map { $0.sizeThatFits(ProposedViewSize(width: imageWidth, height: 100)) }
    }
}

struct UAPPFeedbackRemoteImage: View {
    let url: URL
    @State private var showsImage = false
    @State private var phase: AsyncImagePhase = .empty
    @State private var loadedIdentity: String?
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier

    var body: some View {
        Button { showsImage = true } label: {
            thumbnail
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: uappLocalized("feedback.image.view", languageIdentifier: selectedLanguage)))
        .sheet(isPresented: $showsImage) {
            ZStack {
                Color.black.ignoresSafeArea()
                remoteImage.padding(.horizontal, 16).padding(.vertical, 60)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                Button { showsImage = false } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.65), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: uappLocalized("navigation.close", languageIdentifier: selectedLanguage)))
                .padding(12)
            }
            .tint(.white)
            .preferredColorScheme(.dark)
        }
        .task(id: url) {
            let identity = UAPPFeedbackAttachment(url: url).id
            if loadedIdentity == identity, case .success = phase {
                return
            }
            if loadedIdentity != identity {
                phase = .empty
            }
            do {
                let image = try await UAPPRemoteImageCache.shared.load(url)
                try Task.checkCancellation()
                loadedIdentity = identity
                phase = .success(image)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failure(error)
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if case let .success(image) = phase {
            image.resizable().scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            remoteImage
        }
    }

    @ViewBuilder
    private var remoteImage: some View {
        switch phase {
        case let .success(image): image.resizable().scaledToFit()
        case .failure:
            Label(uappLocalized("photo.error"), systemImage: "photo")
                .font(.caption).foregroundStyle(.secondary)
        default: ProgressView()
        }
    }
}

struct UAPPFeedbackImagePicker: View {
    @Binding var data: [Data]
    @Binding var isProcessing: Bool
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier
    @State private var error = false
    #if canImport(PhotosUI)
    @State private var selection: PhotosPickerItem?
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(data.indices, id: \.self) { index in
                    if let source = CGImageSourceCreateWithData(data[index] as CFData, nil),
                       let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
                    {
                        Rectangle().fill(.clear)
                            .aspectRatio(4 / 3, contentMode: .fit)
                            .overlay {
                                Image(decorative: image, scale: 1).resizable().scaledToFill()
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(alignment: .topTrailing) {
                                Button(role: .destructive) { data.remove(at: index) } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(.black.opacity(0.65), in: Circle())
                                        .frame(width: 44, height: 44, alignment: .topTrailing)
                                }
                                .buttonStyle(.plain)
                                .disabled(isProcessing)
                                .accessibilityLabel(Text(verbatim: uappLocalized("photo.remove")))
                            }
                    }
                }
            }
            #if canImport(PhotosUI)
            PhotosPicker(selection: $selection, matching: .images) {
                Image(systemName: "paperclip")
                    .accessibilityLabel(Text(verbatim: uappLocalized("feedback.image.attach")))
                    .font(.body).frame(width: 44, height: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .disabled(isProcessing || data.count >= 2)
            .task(id: selection) {
                guard let selection, data.count < 2 else { return }
                isProcessing = true
                error = false
                defer { isProcessing = false; self.selection = nil }
                do {
                    let prepared = try await UAPPFeedbackImagePreparation.load(selection)
                    try Task.checkCancellation()
                    data.append(prepared)
                } catch is CancellationError { return }
                catch { self.error = true }
            }
            #endif
            if isProcessing {
                ProgressView()
            }
            if error {
                Text(verbatim: uappLocalized("photo.error", languageIdentifier: selectedLanguage))
                    .font(.caption).foregroundStyle(.red)
            }
        }
    }
}

/// Anexos do compositor de feedback: miniaturas grandes e um bloco para adicionar
/// até `limit` imagens, preparadas com a mesma compressão do seletor compacto.
struct UAPPFeedbackComposerAttachments: View {
    static let limit = 2

    @Binding var data: [Data]
    @Binding var isProcessing: Bool
    let accent: Color
    let palette: UAPPResolvedPalette
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @State private var error = false
    #if canImport(PhotosUI)
    @State private var selection: PhotosPickerItem?
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(data.indices, id: \.self) { index in
                    thumbnail(at: index)
                }
                if data.count < Self.limit {
                    addTile
                }
            }
            if error {
                Label {
                    Text(verbatim: uappLocalized("photo.error"))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.footnote)
                .foregroundStyle(.red)
            }
        }
        #if canImport(PhotosUI)
        .task(id: selection) {
            guard let selection, data.count < Self.limit else { return }
            isProcessing = true
            error = false
            defer { isProcessing = false; self.selection = nil }
            do {
                let prepared = try await UAPPFeedbackImagePreparation.load(selection)
                try Task.checkCancellation()
                data.append(prepared)
            } catch is CancellationError { return }
            catch { self.error = true }
        }
        #endif
    }

    @ViewBuilder
    private func thumbnail(at index: Int) -> some View {
        if let source = CGImageSourceCreateWithData(data[index] as CFData, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        {
            Rectangle().fill(.clear)
                .aspectRatio(4 / 3, contentMode: .fit)
                .overlay {
                    Image(decorative: image, scale: 1).resizable().scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(palette.separator.opacity(0.5), lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    Button(role: .destructive) {
                        data.remove(at: index)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(.black.opacity(0.6), in: Circle())
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing)
                    .accessibilityLabel(Text(verbatim: uappLocalized("photo.remove")))
                }
        }
    }

    private var addTile: some View {
        #if canImport(PhotosUI)
        // O rótulo do PhotosPicker é um closure Sendable: captura apenas valores.
        let accent = accent
        let isProcessing = isProcessing
        let isEnabled = isEnabled
        let fillOpacity = colorScheme == .dark ? 0.12 : 0.06
        let title = uappLocalized(isProcessing ? "photo.processing" : "feedback.image.attach")
        return PhotosPicker(selection: $selection, matching: .images) {
            Self.addTileLabel(
                accent: accent,
                fillOpacity: fillOpacity,
                isProcessing: isProcessing,
                isEnabled: isEnabled,
                title: title
            )
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        #else
        return EmptyView()
        #endif
    }

    private nonisolated static func addTileLabel(
        accent: Color,
        fillOpacity: Double,
        isProcessing: Bool,
        isEnabled: Bool,
        title: String
    ) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(accent.opacity(fillOpacity))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(accent.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                VStack(spacing: 8) {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.title2)
                            .accessibilityHidden(true)
                    }
                    Text(verbatim: title)
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(accent)
                .padding(10)
            }
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

enum UAPPFeedbackImagePreparation {
    static let maximumJPEGBytes = 512 * 1024

    #if canImport(PhotosUI)
    /// Carrega a imagem escolhida e devolve o JPEG preparado para envio.
    static func load(_ item: PhotosPickerItem) async throws -> Data {
        guard let original = try await item.loadTransferable(type: Data.self) else {
            throw UAPPKitError.invalidResponse
        }
        return try jpeg(from: original)
    }
    #endif

    /// Redimensiona e reencoda sem metadados de localização da imagem original.
    static func jpeg(from data: Data) throws -> Data {
        guard let source = uappImageSource(from: data) else {
            throw UAPPKitError.invalidResponse
        }
        for pixelSize in [1600, 1280, 1024] {
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: pixelSize
            ] as CFDictionary) else { throw UAPPKitError.invalidResponse }
            for quality in [0.75, 0.6, 0.45] {
                let output = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
                    throw UAPPKitError.invalidResponse
                }
                CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
                guard CGImageDestinationFinalize(destination) else { throw UAPPKitError.invalidResponse }
                if output.length <= maximumJPEGBytes {
                    return output as Data
                }
            }
        }
        throw UAPPKitError.invalidResponse
    }
}
#endif
