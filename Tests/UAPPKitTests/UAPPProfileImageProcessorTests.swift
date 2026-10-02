import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import UAPPKit

struct UAPPProfileImageProcessorTests {
    @Test("Foto é exportada como JPEG quadrado, sem ampliar imagens pequenas", arguments: [1200, 96])
    func dimensions(_ size: Int) throws {
        let data = try image(width: size, height: size)
        let processed = try #require(UAPPProfileImageProcessor.compressedJPEG(from: data))
        let source = try #require(CGImageSourceCreateWithData(processed as CFData, nil))
        let result = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(result.width == min(size, 512))
        #expect(result.height == result.width)
        #expect(CGImageSourceGetType(source) as String? == UTType.jpeg.identifier)
    }

    @Test("Foto retangular é normalizada para um quadrado dentro do limite")
    func rectangle() throws {
        let data = try image(width: 1200, height: 800)
        let processed = try #require(UAPPProfileImageProcessor.compressedJPEG(from: data))
        let source = try #require(CGImageSourceCreateWithData(processed as CFData, nil))
        let result = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(result.width == result.height)
        #expect(result.width <= 512)
    }

    @Test("Dados inválidos não substituem uma foto válida")
    func invalidData() {
        #expect(UAPPProfileImageProcessor.compressedJPEG(from: Data()) == nil)
        #expect(UAPPProfileImageProcessor.compressedJPEG(from: Data("invalid".utf8)) == nil)
    }

    private func image(width: Int, height: Int) throws -> Data {
        let bitmap = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        bitmap.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(bitmap.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
