#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import ImageIO
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@MainActor
struct UAPPImageCacheTests {
    @Test("Avatar local carrega sem rede e rejeita conteúdo inválido")
    func localAvatar() async throws {
        let recorder = RequestRecorder()
        let cache = UAPPRemoteImageCache(transport: StubTransport { request in
            recorder.record(request)
            return response("unexpected network")
        })
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).png")
        defer { try? FileManager.default.removeItem(at: url) }
        try imageData().write(to: url)
        _ = try await cache.load(url)
        #expect(cache.cachedImage(for: url) != nil)
        cache.removeAll()
        try Data("invalid image".utf8).write(to: url)
        await #expect(throws: URLError.self) { try await cache.load(url) }
        #expect(cache.cachedImage(for: url) == nil)
        #expect(recorder.requests.isEmpty)
    }

    @Test("Imagem válida é reutilizada, e limpar o cache exige novo download")
    func reuseAndClear() async throws {
        let recorder = RequestRecorder()
        let data = try imageData()
        let cache = UAPPRemoteImageCache(transport: StubTransport { request in
            recorder.record(request)
            return (200, data)
        })
        let url = try #require(URL(string: "https://example.test/avatar.png"))
        _ = try await cache.load(url)
        _ = try await cache.load(url)
        #expect(recorder.requests.count == 1)
        #expect(cache.cachedImage(for: url) != nil)
        cache.removeAll()
        #expect(cache.cachedImage(for: url) == nil)
        _ = try await cache.load(url)
        #expect(recorder.requests.count == 2)
    }

    @Test("Resposta inválida não entra no cache e permite nova tentativa")
    func invalidImage() async throws {
        let recorder = RequestRecorder()
        let cache = UAPPRemoteImageCache(transport: StubTransport { request in
            recorder.record(request)
            return response("not an image")
        })
        let url = try #require(URL(string: "https://example.test/invalid.png"))
        for _ in 0 ..< 2 {
            await #expect(throws: URLError.self) { try await cache.load(url) }
        }
        #expect(recorder.requests.count == 2)
        #expect(cache.cachedImage(for: url) == nil)
    }

    @Test("Solicitações simultâneas compartilham um único download")
    func sharedDownload() async throws {
        let recorder = RequestRecorder()
        let data = try imageData()
        let cache = UAPPRemoteImageCache(transport: StubTransport { request in
            recorder.record(request)
            await Task.yield()
            return (200, data)
        })
        let url = try #require(URL(string: "https://example.test/shared.png"))
        let first = Task { @MainActor in _ = try await cache.load(url) }
        let second = Task { @MainActor in _ = try await cache.load(url) }
        try await first.value
        try await second.value
        #expect(recorder.requests.count == 1)
    }

    @Test("Cache-Control no-store impede retenção em memória")
    func noStore() async throws {
        let recorder = RequestRecorder()
        let transport = try ImageHeaderTransport(data: imageData(), recorder: recorder)
        let cache = UAPPRemoteImageCache(transport: transport)
        let url = try #require(URL(string: "https://example.test/private.png"))
        _ = try await cache.load(url)
        #expect(cache.cachedImage(for: url) == nil)
        _ = try await cache.load(url)
        #expect(recorder.requests.count == 2)
    }

    private func imageData() throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
        return data as Data
    }
}

private struct ImageHeaderTransport: UAPPTransport {
    let data: Data
    let recorder: RequestRecorder

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        recorder.record(request)
        let url = try #require(request.url)
        let response = try #require(HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: nil, headerFields: ["Cache-Control": "no-store"]
        ))
        return (data, response)
    }
}
#endif
