import Foundation
import ImageIO
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

/// Normaliza a foto de perfil para recorte circular em JPEG de até 512 pixels.
public enum UAPPProfileImageProcessor {
    public static func compressedJPEG(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 512
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let side = min(image.width, image.height)
        let rect = CGRect(x: (image.width - side) / 2, y: (image.height - side) / 2, width: side, height: side)
        guard let square = image.cropping(to: rect),
              let bitmap = CGContext(
                  data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        bitmap.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        bitmap.fill(bounds)
        bitmap.addEllipse(in: bounds)
        bitmap.clip()
        bitmap.interpolationQuality = .high
        bitmap.draw(square, in: bounds)
        guard let circular = bitmap.makeImage() else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, circular, [kCGImageDestinationLossyCompressionQuality: 0.72] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    #if os(iOS)
    public static func compressedJPEG(from image: UIImage) -> Data? {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        return compressedJPEG(from: data)
    }
    #endif
}
