#if canImport(SwiftUI)
import NaturalLanguage
import SwiftUI
#if canImport(Translation)
@preconcurrency import Translation
#endif

enum UAPPReviewTranslation {
    static func shouldTranslate(_ text: String, targetIdentifier: String) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue != Locale(identifier: targetIdentifier).language.languageCode?.identifier
    }

    static func sourceIdentifier(for text: String, targetIdentifier: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage?.rawValue,
              language != Locale(identifier: targetIdentifier).language.languageCode?.identifier
        else { return nil }
        return language
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

    init(text: String, targetIdentifier: String, model: UAPPReviewTextModel? = nil, rendersMarkdown: Bool = false,
         lineLimit: Int? = nil, displayTransform: @escaping (String) -> String = { $0 }) {
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
           model.translated == nil,
           UAPPReviewTranslation.shouldTranslate(text, targetIdentifier: targetIdentifier)
        {
            content.translationTask(
                source: UAPPReviewTranslation.sourceIdentifier(for: text, targetIdentifier: targetIdentifier)
                    .map { Locale.Language(identifier: $0) },
                target: Locale.Language(identifier: targetIdentifier)
            ) { session in
                await model.translate(waitForPending: rendersMarkdown) { text in
                    nonisolated(unsafe) let session = session
                    if rendersMarkdown {
                        return try await uappTranslateChangelogMarkdown(text, usingBatch: { fragments in
                            nonisolated(unsafe) let requests = fragments.enumerated().map { index, fragment in
                                TranslationSession.Request(sourceText: fragment, clientIdentifier: String(index))
                            }
                            let responses = try await session.translations(from: requests)
                            return responses.map(\.targetText)
                        })
                    }
                    let response = try await session.translate(text)
                    return response.targetText
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
