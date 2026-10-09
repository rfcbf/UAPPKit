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
                Text(uappChangelogMarkdown(text))
                    .fixedSize(horizontal: false, vertical: true)
            }
            #else
            Text(uappChangelogMarkdown(text))
                .fixedSize(horizontal: false, vertical: true)
            #endif
        } else {
            Text(uappChangelogMarkdown(translationForTarget ?? text))
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

/// Resultado da tradução da biografia, separado da sessão do sistema para ser testável.
enum UAPPBioTranslationOutcome: Equatable {
    case translated(String)
    case cancelled
    case failed
    /// A tarefa foi cancelada depois de falhar; o estado da tela não deve mudar.
    case ignored

    static func resolve(_ translate: () async throws -> String) async -> Self {
        do {
            let value = try await translate()
            return Task.isCancelled ? .ignored : .translated(value)
        } catch is CancellationError {
            return .cancelled
        } catch {
            return Task.isCancelled ? .ignored : .failed
        }
    }
}

#if canImport(Translation)
@available(iOS 18.0, macOS 15.0, *)
struct UAPPAppleTranslatedBio: View {
    let text: String
    let sourceIdentifier: String
    let targetIdentifier: String
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var translatedText: String?
    @State private var isTranslating: Bool

    init(
        text: String,
        sourceIdentifier: String,
        targetIdentifier: String,
        translatedText: String? = nil,
        isTranslating: Bool = false
    ) {
        self.text = text
        self.sourceIdentifier = sourceIdentifier
        self.targetIdentifier = targetIdentifier
        _translatedText = State(initialValue: translatedText)
        _isTranslating = State(initialValue: isTranslating)
    }

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(uappChangelogMarkdown(translatedText ?? text))
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
            nonisolated(unsafe) let session = session
            let outcome = await UAPPBioTranslationOutcome.resolve { try await session.translate(text).targetText }
            switch outcome {
            case let .translated(value):
                translatedText = value
                isTranslating = false
            case .cancelled:
                isTranslating = false
            case .failed:
                isTranslating = false
                translationConfiguration = nil
            case .ignored:
                break
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
