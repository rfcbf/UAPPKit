#if canImport(SwiftUI)
import Foundation
import ImageIO
import SwiftUI

/// Indicador compartilhado para o espaço ocupado por uma imagem em carregamento.
public struct UAPPImageLoadingPlaceholder: View {
    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().fill(Color(white: 0.93))
                ProgressView().controlSize(.small).tint(.gray)
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel(Text(verbatim: uappLocalized("photo.processing")))
    }
}

/// Imagem remota ou local com cache compartilhado entre as telas do kit e do aplicativo.
@MainActor
public struct UAPPCachedImage<Content: View>: View {
    private let url: URL?
    private let content: (AsyncImagePhase) -> Content
    @State private var phase: AsyncImagePhase = .empty
    @State private var loadedURL: URL?

    public init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    public var body: some View {
        content(displayPhase)
            .task(id: url) {
                loadedURL = url
                phase = .empty
                guard let url else { return }
                do {
                    let image = try await UAPPRemoteImageCache.shared.load(url)
                    guard !Task.isCancelled, loadedURL == url else { return }
                    phase = .success(image)
                } catch {
                    guard !Task.isCancelled, loadedURL == url else { return }
                    phase = .failure(error)
                }
            }
    }

    private var displayPhase: AsyncImagePhase {
        if let url, let image = UAPPRemoteImageCache.shared.cachedImage(for: url) {
            return .success(image)
        }
        return loadedURL == url ? phase : .empty
    }
}

/// Limpeza explícita do cache de imagens, por exemplo ao trocar de conta.
@MainActor
public enum UAPPImageCache {
    public static func removeAll() {
        UAPPRemoteImageCache.shared.removeAll()
    }
}

@MainActor
final class UAPPRemoteImageCache {
    private final class Entry {
        let image: Image
        let expiresAt: Date
        init(image: Image, expiresAt: Date) {
            self.image = image
            self.expiresAt = expiresAt
        }
    }

    private struct Download: Sendable {
        let data: Data
        let lifetime: TimeInterval
    }

    static let shared: UAPPRemoteImageCache = {
        let diskCache = URLCache(
            memoryCapacity: 16 * 1024 * 1024,
            diskCapacity: 64 * 1024 * 1024,
            diskPath: "UAPPKit.Images"
        )
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = diskCache
        configuration.requestCachePolicy = .useProtocolCachePolicy
        return UAPPRemoteImageCache(
            transport: URLSessionTransport(session: URLSession(configuration: configuration)),
            diskCache: diskCache
        )
    }()

    private let memory = NSCache<NSURL, Entry>()
    private var pending: [URL: Task<Download, Error>] = [:]
    private let transport: any UAPPTransport
    private let diskCache: URLCache?
    private var generation = 0

    init(transport: any UAPPTransport, diskCache: URLCache? = nil) {
        self.transport = transport
        self.diskCache = diskCache
        memory.totalCostLimit = 32 * 1024 * 1024
        memory.countLimit = 100
    }

    func cachedImage(for url: URL) -> Image? {
        guard let entry = memory.object(forKey: url as NSURL) else { return nil }
        guard entry.expiresAt > Date() else {
            memory.removeObject(forKey: url as NSURL)
            return nil
        }
        return entry.image
    }

    func load(_ url: URL) async throws -> Image {
        if let image = cachedImage(for: url) {
            return image
        }
        guard let scheme = url.scheme?.lowercased(), ["https", "http", "file"].contains(scheme) else {
            throw URLError(.unsupportedURL)
        }
        let capturedGeneration = generation
        let task: Task<Download, Error>
        let ownsRequest: Bool
        if let existing = pending[url] {
            task = existing
            ownsRequest = false
        } else {
            let transport = transport
            task = Task {
                if url.isFileURL {
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size > 0, size <= 10 * 1024 * 1024 else { throw URLError(.badServerResponse) }
                    let data = try Data(contentsOf: url)
                    guard !data.isEmpty, data.count <= 10 * 1024 * 1024 else { throw URLError(.badServerResponse) }
                    return Download(data: data, lifetime: 300)
                }
                let (data, response) = try await transport.send(URLRequest(url: url))
                guard (200 ..< 300).contains(response.statusCode),
                      !data.isEmpty, data.count <= 10 * 1024 * 1024
                else {
                    throw URLError(.badServerResponse)
                }
                let directives = (response.value(forHTTPHeaderField: "Cache-Control") ?? "")
                    .lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let lifetime: TimeInterval
                if directives.contains("no-store") || directives.contains("no-cache") {
                    lifetime = 0
                } else {
                    let maxAge = directives.first { $0.hasPrefix("max-age=") }
                        .flatMap { TimeInterval($0.dropFirst(8).replacingOccurrences(of: "\"", with: "")) }
                    let age = TimeInterval(response.value(forHTTPHeaderField: "Age") ?? "0") ?? 0
                    lifetime = max(0, min(300, (maxAge ?? 300) - age))
                }
                return Download(data: data, lifetime: lifetime)
            }
            pending[url] = task
            ownsRequest = true
        }
        defer {
            if ownsRequest, capturedGeneration == generation {
                pending[url] = nil
            }
        }
        let download = try await task.value
        guard capturedGeneration == generation else { throw CancellationError() }
        if let image = cachedImage(for: url) {
            return image
        }
        guard let source = uappImageSource(from: download.data),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 2048
              ] as CFDictionary) else { throw URLError(.cannotDecodeContentData) }
        let result = Image(decorative: image, scale: 1)
        if download.lifetime > 0 {
            memory.setObject(
                Entry(image: result, expiresAt: Date().addingTimeInterval(download.lifetime)),
                forKey: url as NSURL,
                cost: image.bytesPerRow * image.height
            )
        }
        return result
    }

    func removeAll() {
        generation += 1
        pending.values.forEach { $0.cancel() }
        pending.removeAll()
        memory.removeAllObjects()
        diskCache?.removeAllCachedResponses()
    }
}
#endif
