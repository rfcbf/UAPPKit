import Foundation

/// Formata nomes para exibição sem alterar o perfil original.
public enum UAPPDisplayName {
    public static func abbreviated(_ name: String) -> String {
        let words = name.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let particles: Set = ["de", "da", "do", "das", "dos", "e", "d'"]
        let indices = words.indices.filter { !particles.contains(words[$0].lowercased()) }
        guard indices.count > 3, let last = indices.last else { return words.joined(separator: " ") }
        let preserved = Set(indices.prefix(2)).union([last])
        return words.enumerated().map { index, word in
            guard !preserved.contains(index), !particles.contains(word.lowercased()),
                  let initial = word.first else { return word }
            return "\(initial)."
        }.joined(separator: " ")
    }
}
