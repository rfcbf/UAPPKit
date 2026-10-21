#if os(macOS)
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Recorte circular da foto de perfil no Mac: arrastar posiciona a imagem e o controle de zoom
/// aproxima. Substitui o editor usado no iPhone e no iPad, que depende do UIKit.
struct UAPPProfilePhotoCropper: View {
    static let viewportSide: CGFloat = 320
    static let zoomRange: ClosedRange<CGFloat> = 1 ... 4

    let image: CGImage
    let accent: Color
    let localized: (String) -> String
    let onCancel: () -> Void
    let onCrop: (Data?) -> Void

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize?

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text(verbatim: localized("photo.crop_title"))
                    .font(.headline)
                Text(verbatim: localized("photo.crop_hint"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            viewport
            HStack(spacing: 10) {
                Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
                Slider(value: $zoom, in: Self.zoomRange)
                    .accessibilityLabel(Text(verbatim: localized("photo.zoom")))
                Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
            }
            .frame(width: Self.viewportSide)
            .uappOnChange(of: zoom) { _ in
                offset = clamped(offset)
            }
            HStack {
                Spacer()
                Button(localized("common.cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(localized("photo.use")) {
                    onCrop(Self.croppedImageData(image, zoom: zoom, offset: offset, side: Self.viewportSide))
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: Self.viewportSide + 48)
        .tint(accent)
    }

    private var viewport: some View {
        let scale = Self.displayScale(for: image, zoom: zoom, side: Self.viewportSide)
        return Image(decorative: image, scale: 1)
            .resizable()
            .frame(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
            .offset(offset)
            .frame(width: Self.viewportSide, height: Self.viewportSide)
            .clipped()
            .overlay {
                // Escurece o que fica fora do círculo, como o recorte final.
                Rectangle()
                    .fill(.black.opacity(0.45))
                    .mask {
                        Rectangle()
                            .overlay { Circle().blendMode(.destinationOut) }
                            .compositingGroup()
                    }
                    .allowsHitTesting(false)
                Circle()
                    .strokeBorder(.white.opacity(0.85), lineWidth: 2)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let start = dragStart ?? offset
                        dragStart = start
                        offset = clamped(CGSize(
                            width: start.width + value.translation.width,
                            height: start.height + value.translation.height
                        ))
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: localized("photo.avatar")))
    }

    private func clamped(_ proposed: CGSize) -> CGSize {
        Self.clampedOffset(proposed, image: image, zoom: zoom, side: Self.viewportSide)
    }

    /// Pontos por pixel com o zoom aplicado; em zoom 1 a menor dimensão preenche o recorte.
    static func displayScale(for image: CGImage, zoom: CGFloat, side: CGFloat) -> CGFloat {
        let shortest = CGFloat(max(1, min(image.width, image.height)))
        return side / shortest * min(max(zoom, zoomRange.lowerBound), zoomRange.upperBound)
    }

    /// Mantém a imagem cobrindo todo o recorte, sem faixas vazias nas bordas.
    static func clampedOffset(_ offset: CGSize, image: CGImage, zoom: CGFloat, side: CGFloat) -> CGSize {
        let scale = displayScale(for: image, zoom: zoom, side: side)
        let limitX = max(0, (CGFloat(image.width) * scale - side) / 2)
        let limitY = max(0, (CGFloat(image.height) * scale - side) / 2)
        return CGSize(
            width: min(max(offset.width, -limitX), limitX),
            height: min(max(offset.height, -limitY), limitY)
        )
    }

    /// Recorta o quadrado visível no círculo e devolve um PNG, que o processador do kit
    /// reduz, arredonda e converte em JPEG.
    static func croppedImageData(_ image: CGImage, zoom: CGFloat, offset: CGSize, side: CGFloat) -> Data? {
        let scale = displayScale(for: image, zoom: zoom, side: side)
        let offset = clampedOffset(offset, image: image, zoom: zoom, side: side)
        let cropSide = side / scale
        let centerX = CGFloat(image.width) / 2 - offset.width / scale
        let centerY = CGFloat(image.height) / 2 - offset.height / scale
        let rect = CGRect(
            x: centerX - cropSide / 2, y: centerY - cropSide / 2, width: cropSide, height: cropSide
        ).integral
        guard let cropped = image.cropping(to: rect) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, cropped, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// Lê a imagem já na orientação da foto e limitada a 2048 pixels, o suficiente para o recorte.
    static func orientedImage(from data: Data) -> CGImage? {
        guard let source = uappImageSource(from: data) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
#endif
