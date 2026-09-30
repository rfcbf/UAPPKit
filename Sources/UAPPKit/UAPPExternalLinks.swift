import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
func uappOpenExternalURL(_ url: URL) {
    Task { @MainActor in
        _ = await uappOpenExternalURLAndReportSuccess(url)
    }
}

@MainActor
func uappOpenExternalURLAndReportSuccess(_ url: URL) async -> Bool {
    #if canImport(UIKit)
    return await withCheckedContinuation { continuation in
        UIApplication.shared.open(url, options: [:]) { success in
            guard !success, let fallbackURL = uappAppStoreWebFallback(for: url) else {
                continuation.resume(returning: success)
                return
            }
            UIApplication.shared.open(fallbackURL, options: [:]) { fallbackSuccess in
                continuation.resume(returning: fallbackSuccess)
            }
        }
    }
    #elseif canImport(AppKit)
    return NSWorkspace.shared.open(url)
    #else
    return false
    #endif
}

private func uappAppStoreWebFallback(for url: URL) -> URL? {
    guard url.scheme?.lowercased() == "itms-apps" else { return nil }
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.scheme = "https"
    if components?.host?.lowercased() == "itunes.apple.com" {
        components?.host = "apps.apple.com"
    }
    return components?.url
}
