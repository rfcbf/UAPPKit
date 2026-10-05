#if canImport(SwiftUI)
import SwiftUI

struct UAPPFeedbackTranslatedText: View {
    let text: String
    var lineLimit: Int?
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier
    @Environment(\.uappFeedbackTranslationCache) private var cache

    var body: some View {
        UAPPReviewTranslatedText(
            text: text, targetIdentifier: selectedLanguage, cache: cache, lineLimit: lineLimit,
            displayTransform: { value in
                guard let lineLimit else { return value }
                return uappFeedbackDescriptionPreview(value, maximumLines: lineLimit)
            }
        )
        .truncationMode(.tail)
    }
}

func uappFeedbackDescriptionPreview(_ text: String, maximumLines: Int) -> String {
    guard maximumLines > 0 else { return text }
    let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
    guard lines.count > maximumLines,
          !lines.dropFirst(maximumLines).joined(separator: "\n")
          .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
    var preview = lines.prefix(maximumLines).joined(separator: "\n")
    // Se o corte cair numa linha vazia, mostre as reticências após o último texto visível.
    while preview.last?.isWhitespace == true {
        preview.removeLast()
    }
    return preview + "…"
}

func uappFeedbackStatusTitle(_ status: UAPPRoadmapColumn.Status?, languageIdentifier: String? = nil) -> String {
    let language = languageIdentifier ?? UserDefaults.standard.string(forKey: UAPPLocalizationPreferences.presentationStorageKey)
        ?? UAPPLocalizationPreferences.hostIdentifier
    guard let status else { return uappLocalized("feedback.status.none", languageIdentifier: language) }
    let key = "status.\(status.key == "done" ? "shipped" : status.key)"
    let translated = uappLocalized(key, languageIdentifier: language)
    return translated == key ? status.name : translated
}

private struct UAPPFeedbackTranslationCacheKey: EnvironmentKey {
    static let defaultValue: UAPPReviewTranslationCache? = nil
}

extension EnvironmentValues {
    var uappFeedbackTranslationCache: UAPPReviewTranslationCache? {
        get { self[UAPPFeedbackTranslationCacheKey.self] }
        set { self[UAPPFeedbackTranslationCacheKey.self] = newValue }
    }
}
#endif
