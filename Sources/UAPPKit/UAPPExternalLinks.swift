import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Abre um link e informa se o sistema aceitou. Injetável para testes sem abrir apps externos.
typealias UAPPURLOpener = @MainActor (URL) async -> Bool

@MainActor
func uappOpenExternalURL(_ url: URL) {
    Task { @MainActor in
        _ = await uappOpenExternalURLAndReportSuccess(url)
    }
}

/// Tenta o destino original e, para links `itms-apps` recusados, a página web da App Store.
@MainActor
func uappOpenExternalURLAndReportSuccess(
    _ url: URL,
    opener: UAPPURLOpener = uappSystemOpenURL
) async -> Bool {
    if await opener(url) { return true }
    guard let fallbackURL = uappAppStoreWebFallback(for: url) else { return false }
    return await opener(fallbackURL)
}

@MainActor
func uappSystemOpenURL(_ url: URL) async -> Bool {
    #if canImport(UIKit)
    return await withCheckedContinuation { continuation in
        UIApplication.shared.open(url, options: [:]) { continuation.resume(returning: $0) }
    }
    #elseif canImport(AppKit)
    return NSWorkspace.shared.open(url)
    #else
    return false
    #endif
}

func uappAppStoreWebFallback(for url: URL) -> URL? {
    guard url.scheme?.lowercased() == "itms-apps" else { return nil }
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.scheme = "https"
    if components?.host?.lowercased() == "itunes.apple.com" {
        components?.host = "apps.apple.com"
    }
    return components?.url
}
