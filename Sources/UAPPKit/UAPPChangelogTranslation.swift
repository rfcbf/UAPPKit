#if canImport(SwiftUI)
import SwiftUI

enum UAPPChangelogTranslationError: Error {
    case emptyResult
    case incompleteResult
}

/// Translate prose without letting the translation service change Markdown layout.
@MainActor
func uappTranslateChangelogMarkdown(
    _ text: String,
    using translate: (String) async throws -> String
) async throws -> String {
    try await uappTranslateChangelogMarkdown(text, usingBatch: { fragments in
        var results: [String] = []
        for fragment in fragments {
            try await results.append(translate(fragment))
        }
        return results
    })
}

@MainActor
func uappTranslateChangelogMarkdown(
    _ text: String,
    usingBatch translate: ([String]) async throws -> [String]
) async throws -> String {
    let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
    var output = lines
    var fragments: [String] = []
    var locations: [(index: Int, prefix: String)] = []
    var isCodeBlock = false
    for (index, line) in lines.enumerated() {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
            isCodeBlock.toggle()
            continue
        }
        guard !isCodeBlock, !trimmed.isEmpty else {
            continue
        }
        let range = line.range(
            of: "^[ \\t]*(?:(?:#{1,6}|[-+*]|[0-9]+[.)])[ \\t]+)?",
            options: .regularExpression
        )
        let end = range?.upperBound ?? line.startIndex
        let prefix = String(line[..<end])
        fragments.append(String(line[end...]))
        locations.append((index, prefix))
    }
    guard !fragments.isEmpty else { return output.joined(separator: "\n") }
    let results = try await translate(fragments)
    guard results.count == locations.count else { throw UAPPChangelogTranslationError.incompleteResult }
    for (location, result) in zip(locations, results) {
        let translated = result
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !translated.isEmpty else { throw UAPPChangelogTranslationError.emptyResult }
        output[location.index] = location.prefix + translated
    }
    return output.joined(separator: "\n")
}

struct UAPPChangelogTranslatedText: View {
    let text: String
    var lineLimit: Int?
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier
    @Environment(\.uappChangelogTranslationCache) private var cache

    var body: some View {
        UAPPReviewTranslatedText(
            text: text, targetIdentifier: selectedLanguage, cache: cache,
            rendersMarkdown: true, lineLimit: lineLimit
        )
    }
}

private struct UAPPChangelogTranslationCacheKey: EnvironmentKey {
    static let defaultValue: UAPPReviewTranslationCache? = nil
}

extension EnvironmentValues {
    var uappChangelogTranslationCache: UAPPReviewTranslationCache? {
        get { self[UAPPChangelogTranslationCacheKey.self] }
        set { self[UAPPChangelogTranslationCacheKey.self] = newValue }
    }
}
#endif
