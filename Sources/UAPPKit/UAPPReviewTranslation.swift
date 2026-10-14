#if canImport(SwiftUI)
import NaturalLanguage
import SwiftUI
#if canImport(Translation)
@preconcurrency import Translation
#endif

enum UAPPReviewTranslation {
    /// Termos de produto usados do mesmo jeito em qualquer idioma; um texto só com eles fica como está.
    static let untranslatedTerms: Set<String> = [
        "app", "bug", "bugs", "changelog", "feedback", "login", "logout", "ok", "roadmap"
    ]

    /// Abaixo desta confiança o idioma detectado é um palpite. Acontece em textos curtos, como
    /// "Bug" ou "Dark mode", e traduzir a partir de um palpite falha ou distorce o texto.
    static let minimumLanguageConfidence = 0.6

    static func shouldTranslate(_ text: String, targetIdentifier: String) -> Bool {
        sourceIdentifier(for: text, targetIdentifier: targetIdentifier) != nil
    }

    static func containsOnlyUntranslatedTerms(_ text: String) -> Bool {
        let words = text.lowercased().split { !$0.isLetter }
        return !words.isEmpty && words.allSatisfy { untranslatedTerms.contains(String($0)) }
    }

    /// Traduz o texto inteiro ou, em Markdown, somente os fragmentos de texto em lote.
    static func translate(
        _ text: String,
        rendersMarkdown: Bool,
        single: @Sendable (String) async throws -> String,
        batch: @Sendable ([String]) async throws -> [String]
    ) async throws -> String {
        if rendersMarkdown {
            return try await uappTranslateChangelogMarkdown(text, usingBatch: batch)
        }
        return try await single(text)
    }

    /// Idioma de origem quando vale traduzir; `nil` para texto vazio, só com termos que não se
    /// traduzem, já no idioma de destino ou de idioma incerto.
    static func sourceIdentifier(for text: String, targetIdentifier: String) -> String? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !containsOnlyUntranslatedTerms(text)
        else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage,
              let confidence = recognizer.languageHypotheses(withMaximum: 1)[language],
              confidence >= minimumLanguageConfidence,
              language.rawValue != Locale(identifier: targetIdentifier).language.languageCode?.identifier
        else { return nil }
        return language.rawValue
    }
}

private struct UAPPSystemTranslationEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

public extension EnvironmentValues {
    /// Permite desligar a tradução automática do sistema onde ela não está disponível,
    /// como nos testes, mantendo o texto original sem acionar o framework Translation.
    /// Vale para avaliações, requisições e a biografia da tela Sobre.
    var uappSystemTranslationEnabled: Bool {
        get { self[UAPPSystemTranslationEnabledKey.self] }
        set { self[UAPPSystemTranslationEnabledKey.self] = newValue }
    }
}

struct UAPPReviewTranslatedText: View {
    let text: String
    let targetIdentifier: String
    var cache: UAPPReviewTranslationCache?
    var rendersMarkdown = false
    var lineLimit: Int?
    var displayTransform: (String) -> String = { $0 }

    var body: some View {
        UAPPReviewTranslationContent(
            text: text, targetIdentifier: targetIdentifier,
            model: cache?.model(for: text, targetIdentifier: targetIdentifier),
            rendersMarkdown: rendersMarkdown, lineLimit: lineLimit, displayTransform: displayTransform
        )
        .id("\(targetIdentifier)|\(text)")
    }
}

struct UAPPReviewTranslationContent: View {
    let text: String
    let targetIdentifier: String
    @StateObject private var model: UAPPReviewTextModel
    let rendersMarkdown: Bool
    let lineLimit: Int?
    let displayTransform: (String) -> String
    @Environment(\.uappSystemTranslationEnabled) private var systemTranslationEnabled

    init(
        text: String,
        targetIdentifier: String,
        model: UAPPReviewTextModel? = nil,
        rendersMarkdown: Bool = false,
        lineLimit: Int? = nil,
        displayTransform: @escaping (String) -> String = { $0 }
    ) {
        self.text = text
        self.targetIdentifier = targetIdentifier
        _model = StateObject(wrappedValue: model ?? UAPPReviewTextModel(original: text))
        self.rendersMarkdown = rendersMarkdown
        self.lineLimit = lineLimit
        self.displayTransform = displayTransform
    }

    var body: some View {
        #if canImport(Translation)
        if #available(iOS 18.0, macOS 15.0, *),
           systemTranslationEnabled,
           model.translated == nil,
           UAPPReviewTranslation.shouldTranslate(text, targetIdentifier: targetIdentifier)
        {
            content.translationTask(
                source: UAPPReviewTranslation.sourceIdentifier(for: text, targetIdentifier: targetIdentifier)
                    .map { Locale.Language(identifier: $0) },
                target: Locale.Language(identifier: targetIdentifier)
            ) { session in
                nonisolated(unsafe) let session = session
                await model.translate(waitForPending: rendersMarkdown) { text in
                    try await UAPPReviewTranslation.translate(
                        text, rendersMarkdown: rendersMarkdown,
                        single: { try await session.translate($0).targetText },
                        batch: { fragments in
                            nonisolated(unsafe) let requests = fragments.enumerated().map { index, fragment in
                                TranslationSession.Request(sourceText: fragment, clientIdentifier: String(index))
                            }
                            return try await session.translations(from: requests).map(\.targetText)
                        }
                    )
                }
            }
        } else {
            content
        }
        #else
        content
        #endif
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.isTranslating {
                formattedText(text)
                    .lineLimit(lineLimit)
                    .fixedSize(horizontal: false, vertical: true)
                    .redacted(reason: .placeholder)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: uappLocalized("about.translation_in_progress")))
            } else {
                formattedText(model.displayText)
                    .lineLimit(lineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if model.hasError {
                Text(verbatim: uappLocalized("reviews.translation_unavailable"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formattedText(_ value: String) -> Text {
        let displayed = displayTransform(value)
        return rendersMarkdown ? Text(uappChangelogMarkdown(displayed)) : Text(verbatim: displayed)
    }
}
#endif
