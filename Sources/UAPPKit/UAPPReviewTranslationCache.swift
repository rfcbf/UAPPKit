#if canImport(SwiftUI)
import SwiftUI

/// Estado de tradução compartilhado pelas linhas durante a apresentação da lista.
@MainActor
final class UAPPReviewTranslationCache {
    private struct Key: Hashable {
        let text: String
        let targetIdentifier: String
    }

    private var models: [Key: UAPPReviewTextModel] = [:]

    func model(for text: String, targetIdentifier: String) -> UAPPReviewTextModel {
        let key = Key(text: text, targetIdentifier: targetIdentifier)
        if let model = models[key] {
            return model
        }
        let model = UAPPReviewTextModel(original: text)
        models[key] = model
        return model
    }
}
#endif
