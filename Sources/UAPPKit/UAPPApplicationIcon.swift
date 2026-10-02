#if canImport(SwiftUI)
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct UAPPApplicationIcon: View {
    let palette: UAPPResolvedPalette
    let remoteURL: URL?

    var body: some View {
        if let remoteURL {
            UAPPCachedImage(url: remoteURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else if phase.error != nil {
                    localIcon
                } else {
                    UAPPImageLoadingPlaceholder()
                }
            }
        } else {
            localIcon
        }
    }

    @ViewBuilder
    private var localIcon: some View {
        #if canImport(UIKit)
        if let image = Self.loadUIKitImage() {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            placeholder
        }
        #elseif canImport(AppKit)
        if let image = NSImage(named: NSImage.applicationIconName) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            placeholder
        }
        #else
        placeholder
        #endif
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.cardBackground)
            Image(systemName: "app.fill")
                .font(.system(size: 34))
                .foregroundStyle(palette.accent ?? palette.secondaryText)
        }
    }

    #if canImport(UIKit)
    static func loadUIKitImage(from bundle: Bundle = .main) -> UIImage? {
        let names = iconNames(from: bundle)
        // Sem catálogo nem ícones declarados (ex.: runner de testes), não consulta o CoreUI.
        let hasAssetCatalog = bundle.url(forResource: "Assets", withExtension: "car") != nil
        guard hasAssetCatalog || !names.isEmpty else { return nil }
        for name in names {
            if let image = UIImage(named: name, in: bundle, compatibleWith: nil) {
                return image
            }
        }
        return hasAssetCatalog ? UIImage(named: "AppIcon", in: bundle, compatibleWith: nil) : nil
    }

    static func iconNames(from bundle: Bundle) -> [String] {
        var names: [String] = []
        for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
            guard let icons = bundle.object(forInfoDictionaryKey: key) as? [String: Any],
                  let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
                  let files = primary["CFBundleIconFiles"] as? [String]
            else { continue }
            names.append(contentsOf: files.reversed())
        }
        if let files = bundle.object(forInfoDictionaryKey: "CFBundleIconFiles") as? [String] {
            names.append(contentsOf: files.reversed())
        }
        return names
    }
    #endif
}
#endif
