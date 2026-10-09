#if canImport(SwiftUI)
import SwiftUI

/// Marca de uma rede social aceita no perfil do desenvolvedor: `youtube`, `x`,
/// `instagram`, `tiktok`, `linkedin` ou `facebook`. Outros nomes mostram um
/// símbolo de link.
public struct UAPPSocialNetworkIcon: View {
    private let network: String

    public init(_ network: String) {
        self.network = network
    }

    /// Nome do recurso de imagem da rede; `nil` para redes sem marca no pacote.
    static func assetName(for network: String) -> String? {
        switch network.lowercased() {
        case "youtube": "SocialYouTube"
        case "instagram": "SocialInstagram"
        case "tiktok": "SocialTikTok"
        case "linkedin": "SocialLinkedIn"
        case "facebook": "SocialFacebook"
        case "x": "SocialX"
        default: nil
        }
    }

    public var body: some View {
        if let name = Self.assetName(for: network) {
            Image(name, bundle: .module)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "link")
        }
    }
}
#endif
