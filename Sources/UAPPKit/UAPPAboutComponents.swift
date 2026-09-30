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

            if let shortDescription = configuration.shortDescription,
               !shortDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                UAPPTranslatedDescription(
                    sourceText: shortDescription,
                    sourceLanguageIdentifier: configuration.descriptionLanguageIdentifier,
                    targetLanguageIdentifier: presentationLanguageIdentifier
                )
                .font(.body)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }

            let versionLabel = metadata.versionText.map {
                uappLocalizedFormat("about.version", $0)
            } ?? uappLocalized("about.version_unavailable")

            Text(verbatim: versionLabel)
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct UAPPTranslatedDescription: View {
    let sourceText: String
    let sourceLanguageIdentifier: String?
    let targetLanguageIdentifier: String
    @State private var translatedText: String?

    var body: some View {
        content
            .id("\(sourceText)|\(sourceLanguageIdentifier ?? "")|\(targetLanguageIdentifier)")
    }

    @ViewBuilder
    private var content: some View {
        if #available(iOS 18.0, macOS 15.0, *), let sourceLanguageIdentifier {
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
        Text(verbatim: translatedText ?? sourceText)
    }
}

struct UAPPAboutResources: View {
    let configuration: UAPPAboutConfiguration
    let palette: UAPPResolvedPalette
    let isOpeningAppStoreReview: Bool
    let onOpenAppStoreReview: (() -> Void)?
    let onOpenChangelog: (() -> Void)?

    var body: some View {
        let links: [(String, String, URL)] = [
            ("about.website", "globe", configuration.websiteURL),
            ("about.support", "questionmark.circle", configuration.supportURL),
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
                Link(destination: url) {
                    linkRow(title: uappLocalized(titleKey), systemImage: icon)
                }
                .foregroundStyle(palette.primaryText)
                .accessibilityHint(Text(verbatim: uappLocalized("about.open_link")))
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
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.accent ?? .accentColor)
                .frame(width: 24)
                .accessibilityHidden(true)
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
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
    }

    private func infoRow(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.accent ?? .accentColor)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                Text(verbatim: value)
                    .font(.body)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 16))
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
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 112, height: 112)
                .clipShape(Circle())
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
                                        socialMark(for: name)
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
                                    .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 16))
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
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(palette.accent ?? .accentColor)
                    .frame(width: 60, height: 60)
                    .accessibilityHidden(true)

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
            .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(verbatim: uappLocalized("about.open_public_page")))
    }

    private func appCard(_ app: UAPPAboutApp) -> some View {
        HStack(spacing: 12) {
            if let iconURL = app.iconURL {
                AsyncImage(url: iconURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(palette.background)
                        .overlay { ProgressView() }
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(palette.accent ?? .accentColor)
                    .frame(width: 36, height: 36)
                    .background(palette.background, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
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
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    @MainActor
    private func openAppStore(_ url: URL) {
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }

    @ViewBuilder
    private func socialMark(for name: String) -> some View {
        switch name.lowercased() {
        case "youtube": Image("SocialYouTube", bundle: .module)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
        case "instagram": Image("SocialInstagram", bundle: .module)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
        case "tiktok": Image("SocialTikTok", bundle: .module)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
        case "linkedin": Image("SocialLinkedIn", bundle: .module)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
        case "facebook": Image("SocialFacebook", bundle: .module)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
        case "x": Image("SocialX", bundle: .module)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
        default: Image(systemName: "link")
        }
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
