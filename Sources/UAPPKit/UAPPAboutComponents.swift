#if canImport(SwiftUI)
import Foundation
import SwiftUI
#if canImport(Translation)
@preconcurrency import Translation
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct UAPPAboutAppIdentity: View {
    let metadata: UAPPAppMetadata
    let configuration: UAPPAboutConfiguration
    let presentationLanguageIdentifier: String
    let palette: UAPPResolvedPalette
    let remoteIconURL: URL?
    /// Descrição configurada no UAPP para o projeto; tem precedência sobre a da configuração.
    var serverDescription: UAPPAboutDescription?

    /// Descrição exibida: a do servidor ou, na falta dela, a passada pelo aplicativo.
    var description: UAPPAboutDescription? {
        serverDescription ?? UAPPAboutDescription(
            text: configuration.shortDescription,
            languageIdentifier: configuration.descriptionLanguageIdentifier
        )
    }

    var body: some View {
        VStack(spacing: 14) {
            UAPPApplicationIcon(palette: palette, remoteURL: remoteIconURL)
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                .accessibilityLabel(Text(verbatim: metadata.name))

            Text(verbatim: metadata.name)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let description {
                UAPPTranslatedDescription(
                    sourceText: description.text,
                    sourceLanguageIdentifier: description.languageIdentifier,
                    targetLanguageIdentifier: presentationLanguageIdentifier
                )
                .font(.body)
                .foregroundStyle(palette.secondaryText)
                // Texto longo e com listas lê melhor alinhado à esquerda; ícone, nome e versão ficam centrados.
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            let versionLabel = metadata.versionText.map {
                uappLocalizedFormat("about.version", $0)
            } ?? uappLocalized("about.version_unavailable")

            Label {
                Text(verbatim: versionLabel)
            } icon: {
                Image(systemName: "tag.fill")
                    .accessibilityHidden(true)
            }
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(palette.accent ?? .accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(VersionPillBackground(accent: palette.accent ?? .accentColor))

            kitVersionLabel
        }
        .frame(maxWidth: .infinity)
    }

    /// Versão do UAPPKit em tom neutro, para não se confundir com a versão do aplicativo na cor de destaque.
    private var kitVersionLabel: some View {
        Label {
            Text(verbatim: Self.kitVersionText)
        } icon: {
            Image(systemName: "shippingbox.fill")
                .accessibilityHidden(true)
        }
        .font(.caption.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(palette.secondaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(palette.secondaryText.opacity(0.12)))
        .padding(.top, -6)
    }

    static var kitVersionText: String {
        uappLocalizedFormat("about.kit_version", UAPPKit.version)
    }
}

/// Texto de apresentação do aplicativo e o idioma em que foi escrito.
struct UAPPAboutDescription: Equatable {
    let text: String
    let languageIdentifier: String?

    /// `nil` quando o texto está vazio, para a tela não reservar espaço.
    init?(text: String?, languageIdentifier: String?) {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.text = trimmed
        self.languageIdentifier = languageIdentifier
    }
}

private struct VersionPillBackground: View {
    let accent: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Capsule().fill(accent.opacity(UAPPSurface.selectionFillOpacity(colorScheme)))
    }
}

private struct UAPPTranslatedDescription: View {
    let sourceText: String
    let sourceLanguageIdentifier: String?
    let targetLanguageIdentifier: String
    @State private var translatedText: String?
    @Environment(\.uappSystemTranslationEnabled) private var systemTranslationEnabled

    var body: some View {
        content
            .id("\(sourceText)|\(sourceLanguageIdentifier ?? "")|\(targetLanguageIdentifier)")
    }

    @ViewBuilder
    private var content: some View {
        if #available(iOS 18.0, macOS 15.0, *), systemTranslationEnabled, let sourceLanguageIdentifier {
            text
                .translationTask(
                    source: Locale.Language(identifier: sourceLanguageIdentifier),
                    target: Locale.Language(identifier: targetLanguageIdentifier)
                ) { session in
                    guard sourceLanguageIdentifier != targetLanguageIdentifier else {
                        translatedText = sourceText
                        return
                    }

                    do {
                        translatedText = try await session.translate(sourceText).targetText
                    } catch {
                        translatedText = sourceText
                    }
                }
        } else {
            text
        }
    }

    private var text: some View {
        Text(uappChangelogMarkdown(translatedText ?? sourceText))
    }
}

struct UAPPAboutResources: View {
    let configuration: UAPPAboutConfiguration
    let palette: UAPPResolvedPalette
    let isOpeningAppStoreReview: Bool
    let onOpenAppStoreReview: (() -> Void)?
    let onOpenChangelog: (() -> Void)?
    /// Suporte efetivo: o e-mail do servidor ou, na falta dele, o link da configuração.
    var supportURL: URL?
    var onOpenReviews: (() -> Void)?
    /// Com e-mail de suporte, a linha Suporte oferece os motivos do contato e abre a mensagem.
    var onContactSupport: ((UAPPSupportTopic) -> Void)?
    @State var isChoosingSupportTopic = false

    var body: some View {
        let links: [(String, String, URL)] = [
            ("about.website", "globe", configuration.websiteURL),
            ("about.support", "questionmark.circle", supportURL ?? configuration.supportURL),
            ("about.privacy", "hand.raised", configuration.privacyPolicyURL),
            ("about.terms", "doc.text", configuration.termsOfUseURL)
        ].compactMap { titleKey, icon, url in
            guard let url else { return nil }
            return (titleKey, icon, url)
        }

        VStack(alignment: .leading, spacing: 10) {
            if !links.isEmpty || configuration.license != nil {
                Text(verbatim: uappLocalized("about.resources"))
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
            }
            if configuration.showsChangelog, let onOpenChangelog {
                Button(action: onOpenChangelog) {
                    linkRow(
                        title: uappLocalized("about.changelog"),
                        systemImage: "clock.arrow.circlepath"
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.primaryText)
            }
            if configuration.showsReviews, let onOpenReviews {
                Button(action: onOpenReviews) {
                    linkRow(
                        title: uappLocalized("screen.reviews"),
                        systemImage: "star.bubble"
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.primaryText)
            }
            if configuration.showsAppStoreReview, let onOpenAppStoreReview {
                Button(action: onOpenAppStoreReview) {
                    linkRow(
                        title: uappLocalized("about.rate_app"),
                        systemImage: "star",
                        showsProgress: isOpeningAppStoreReview
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.primaryText)
                .disabled(isOpeningAppStoreReview)
            }
            ForEach(links, id: \.0) { titleKey, icon, url in
                if titleKey == "about.support", let onContactSupport {
                    Button {
                        isChoosingSupportTopic = true
                    } label: {
                        linkRow(title: uappLocalized(titleKey), systemImage: icon)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.primaryText)
                    .sheet(isPresented: $isChoosingSupportTopic) {
                        UAPPSupportTopicSheet(palette: palette) { topic in
                            isChoosingSupportTopic = false
                            onContactSupport(topic)
                        }
                    }
                } else {
                    Link(destination: url) {
                        linkRow(title: uappLocalized(titleKey), systemImage: icon)
                    }
                    .foregroundStyle(palette.primaryText)
                    .accessibilityHint(Text(verbatim: uappLocalized("about.open_link")))
                }
            }
            if let license = configuration.license,
               !license.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                infoRow(
                    title: uappLocalized("about.license"),
                    value: license,
                    systemImage: "doc.text"
                )
            }
        }
    }

    private func linkRow(
        title: String,
        systemImage: String,
        showsProgress: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            UAPPAccentIconBadge(
                systemImage: systemImage, accent: palette.accent ?? .accentColor,
                size: 34, cornerRadius: 10, font: .subheadline.weight(.semibold)
            )
            Text(verbatim: title)
                .font(.body)
            Spacer(minLength: 0)
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .uappCardSurface(palette)
        .contentShape(RoundedRectangle(cornerRadius: UAPPSurface.largeCornerRadius, style: .continuous))
    }

    private func infoRow(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            UAPPAccentIconBadge(
                systemImage: systemImage, accent: palette.accent ?? .accentColor,
                size: 34, cornerRadius: 10, font: .subheadline.weight(.semibold)
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                Text(verbatim: value)
                    .font(.body)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .uappCardSurface(palette)
        .accessibilityElement(children: .combine)
    }
}

struct UAPPAboutDeveloperContent: View {
    let about: UAPPAbout
    let project: UAPPProject?
    let selectedLanguage: String
    let palette: UAPPResolvedPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if let imageURL = about.imageURL {
                UAPPCachedImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if phase.error != nil {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().scaledToFit().foregroundStyle(.secondary)
                    } else {
                        UAPPImageLoadingPlaceholder()
                    }
                }
                .frame(width: 112, height: 112)
                .clipShape(Circle())
                .padding(4)
                .overlay {
                    Circle().strokeBorder((palette.accent ?? .accentColor).opacity(0.35), lineWidth: 2)
                }
                .frame(maxWidth: .infinity)
            }
            if let developerName = about.developerName, !developerName.isEmpty {
                Text(verbatim: developerName)
                    .font(.title3.weight(.semibold))
            }
            if let bio = about.bio, !bio.isEmpty {
                UAPPAboutBio(
                    text: bio,
                    defaultLanguageIdentifier: about.bioDefaultLanguage,
                    translations: about.bioTranslations,
                    targetIdentifier: selectedLanguage
                )
            }
            if !about.apps.isEmpty {
                section("about.apps") {
                    VStack(spacing: 10) {
                        ForEach(about.apps) { app in
                            app.appStoreDestination.map { destination in
                                Button {
                                    openAppStore(destination)
                                } label: {
                                    appCard(app)
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint(Text(verbatim: uappLocalized("about.open_app_store")))
                            }
                        }
                    }
                }
            }
            if let project, let destination = publicAppURL(for: project) {
                appDiscoveryCard(destination: destination)
            }
            if !about.socialLinks.isEmpty {
                section("about.social") {
                    let networks = about.socialLinks.keys.sorted()
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(networks, id: \.self) { name in
                            if let url = about.socialLinks[name] {
                                Link(destination: url) {
                                    HStack(spacing: 12) {
                                        UAPPSocialNetworkIcon(name)
                                            .frame(width: 22, height: 22)
                                            .accessibilityHidden(true)
                                        Text(socialName(for: name))
                                            .font(.body)
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(palette.secondaryText)
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                                    .uappCardSurface(palette)
                                    .contentShape(Rectangle())
                                }
                                .foregroundStyle(palette.primaryText)
                            }
                        }
                    }
                }
            }
        }
    }

    private func section(_ titleKey: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(verbatim: uappLocalized(titleKey))
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func publicAppURL(for project: UAPPProject) -> URL? {
        guard let url = project.publicBaseURL,
              url.scheme?.lowercased() == "https",
              url.host != nil
        else { return nil }

        return url
    }

    private func appDiscoveryCard(destination: URL) -> some View {
        Link(destination: destination) {
            HStack(spacing: 16) {
                UAPPAccentIconBadge(
                    systemImage: "square.grid.2x2.fill", accent: palette.accent ?? .accentColor,
                    size: 52, cornerRadius: 16
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: uappLocalized("about.discovery.title"))
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)
                    Text(verbatim: uappLocalized("about.discovery.message"))
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .uappCardSurface(palette)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(verbatim: uappLocalized("about.open_public_page")))
    }

    private func appCard(_ app: UAPPAboutApp) -> some View {
        HStack(spacing: 12) {
            if let iconURL = app.iconURL {
                UAPPCachedImage(url: iconURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if phase.error != nil {
                        Image(systemName: "app.fill")
                            .foregroundStyle(palette.secondaryText)
                    } else {
                        UAPPImageLoadingPlaceholder()
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(palette.separator.opacity(0.5), lineWidth: 1)
                }
                .accessibilityHidden(true)
            } else {
                UAPPAccentIconBadge(
                    systemImage: "app.fill", accent: palette.accent ?? .accentColor,
                    size: 36, cornerRadius: 10, font: .body.weight(.semibold)
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.headline)
                if let subtitle = app.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .uappCardSurface(palette)
        .contentShape(RoundedRectangle(cornerRadius: UAPPSurface.largeCornerRadius, style: .continuous))
    }

    @MainActor
    private func openAppStore(_ url: URL) {
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }

    private func socialName(for name: String) -> String {
        switch name.lowercased() {
        case "youtube": "YouTube"
        case "instagram": "Instagram"
        case "tiktok": "TikTok"
        case "linkedin": "LinkedIn"
        case "facebook": "Facebook"
        case "x": "X"
        default: name.capitalized
        }
    }
}

#endif
