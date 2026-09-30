#if canImport(SwiftUI)
import SwiftUI

#if canImport(Translation)
import Translation
#endif

struct UAPPAboutBio: View {
    let text: String
    let defaultLanguageIdentifier: String
    let translations: [String: String]
    let targetIdentifier: String

    var body: some View {
        if shouldOfferTranslation {
            #if canImport(Translation)
            if #available(iOS 18.0, macOS 15.0, *) {
                UAPPAppleTranslatedBio(
                    text: text,
                    sourceIdentifier: defaultLanguageIdentifier,
                    targetIdentifier: targetIdentifier
                )
                .id(translationKey)
            } else {
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            #else
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            #endif
        } else {
            Text(translationForTarget ?? text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var shouldOfferTranslation: Bool {
        translationForTarget == nil && languageFamily(defaultLanguageIdentifier) != languageFamily(targetIdentifier)
    }

    private var translationKey: String {
        "\(defaultLanguageIdentifier)|\(targetIdentifier)|\(text)"
    }

    private var translationForTarget: String? {
        let normalizedTarget = normalizedIdentifier(targetIdentifier)
        if let exactMatch = translations.first(where: { normalizedIdentifier($0.key) == normalizedTarget }) {
            return nonempty(exactMatch.value)
        }

        let languageCode = Locale(identifier: targetIdentifier).language.languageCode?.identifier.lowercased()
        guard let languageCode else { return nil }
        return translations.first(where: {
            normalizedIdentifier($0.key) == languageCode
        }).flatMap { nonempty($0.value) }
    }

    private func normalizedIdentifier(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: "-").lowercased()
    }

    private func languageFamily(_ identifier: String) -> String {
        let normalized = normalizedIdentifier(identifier)
        if normalized.hasPrefix("zh-hans") {
            return "zh-hans"
        }
        if normalized.hasPrefix("zh-hant") {
            return "zh-hant"
        }
        return normalized.split(separator: "-").first.map(String.init) ?? normalized
    }

    private func nonempty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#if canImport(Translation)
@available(iOS 18.0, macOS 15.0, *)
private struct UAPPAppleTranslatedBio: View {
    let text: String
    let sourceIdentifier: String
    let targetIdentifier: String
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var translatedText: String?
    @State private var isTranslating = false

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(translatedText ?? text)
                .fixedSize(horizontal: false, vertical: true)

            if translatedText != nil {
                Button {
                    translatedText = nil
                    translationConfiguration = nil
                } label: {
                    Label {
                        Text(verbatim: uappLocalized("about.show_original"))
                    } icon: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(palette.accent ?? .accentColor)
            } else {
                Button(action: requestTranslation) {
                    HStack(spacing: 8) {
                        if isTranslating {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Label {
                            Text(verbatim: isTranslating
                                ? uappLocalized("about.translation_in_progress")
                                : uappLocalized("about.translate"))
                        } icon: {
                            Image(systemName: isTranslating ? "ellipsis" : "character.bubble")
                        }
                    }
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(palette.accent ?? .accentColor)
                .disabled(isTranslating)
            }
        }
        .translationTask(translationConfiguration) { session in
            do {
                nonisolated(unsafe) let session = session
                let response = try await session.translate(text)
                guard !Task.isCancelled else { return }
                translatedText = response.targetText
                isTranslating = false
            } catch is CancellationError {
                isTranslating = false
            } catch {
                guard !Task.isCancelled else { return }
                isTranslating = false
                translationConfiguration = nil
            }
        }
    }

    private func requestTranslation() {
        isTranslating = true
        translationConfiguration = TranslationSession.Configuration(
            source: Locale.Language(identifier: sourceIdentifier),
            target: Locale.Language(identifier: targetIdentifier)
        )
    }
}
#endif
#endif
