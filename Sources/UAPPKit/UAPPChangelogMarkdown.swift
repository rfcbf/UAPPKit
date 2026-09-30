import Foundation

/// SwiftUI Text renders inline Markdown, but ignores block presentation intents.
/// Preserve block separators and list markers explicitly before parsing inline styles.
func uappChangelogMarkdown(_ value: String) -> AttributedString {
    let lines = value.replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
    var result = AttributedString()
    for (index, line) in lines.enumerated() {
        if index > 0 {
            result.append(AttributedString("\n"))
        }
        let heading = line.range(of: "^#{1,6}[ \\t]+", options: .regularExpression)
        let text = heading.map { String(line[$0.upperBound...]) } ?? line
        let marked = text
            .replacingOccurrences(of: "^([ \\t]*)[-+*][ \\t]+", with: "$1• ", options: .regularExpression)
            .replacingOccurrences(of: "^([ \\t]*)([0-9]+)\\)[ \\t]+", with: "$1$2. ", options: .regularExpression)
        var attributed = (try? AttributedString(
            markdown: marked, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(marked)
        if heading != nil {
            for run in attributed.runs {
                attributed[run.range].inlinePresentationIntent =
                    (run.inlinePresentationIntent ?? []).union(.stronglyEmphasized)
            }
        }
        result.append(attributed)
    }
    return result
}
