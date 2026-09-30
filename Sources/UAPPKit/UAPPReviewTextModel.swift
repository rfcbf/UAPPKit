#if canImport(SwiftUI)
import SwiftUI

@MainActor
final class UAPPReviewTextModel: ObservableObject {
    let original: String
    @Published private(set) var translated: String?
    @Published private(set) var hasError = false
    @Published private(set) var isTranslating = false
    private var generation = 0
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    init(original: String) {
        self.original = original
    }

    var displayText: String {
        translated ?? original
    }

    func translate(waitForPending: Bool = false, using translate: (String) async throws -> String) async {
        guard !Task.isCancelled else { return }
        if waitForPending, isTranslating {
            let waiterID = UUID()
            await withTaskCancellationHandler {
                await withCheckedContinuation { waiters[waiterID] = $0 }
            } onCancel: {
                Task { @MainActor [weak self] in
                    self?.waiters.removeValue(forKey: waiterID)?.resume()
                }
            }
            guard !Task.isCancelled else { return }
            await self.translate(waitForPending: true, using: translate)
            return
        }
        guard translated == nil, !isTranslating else { return }
        generation += 1
        let currentGeneration = generation
        isTranslating = true
        hasError = false
        defer {
            if generation == currentGeneration {
                isTranslating = false
                resumeWaiters()
            }
        }
        await withTaskCancellationHandler {
            do {
                let result = try await translate(original)
                guard generation == currentGeneration, !Task.isCancelled else { return }
                guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    hasError = true
                    translated = nil
                    return
                }
                translated = result
            } catch {
                guard generation == currentGeneration, !Task.isCancelled else { return }
                translated = nil
                hasError = true
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelTranslation(generation: currentGeneration)
            }
        }
    }

    func reset() {
        generation += 1
        translated = nil
        hasError = false
        isTranslating = false
        resumeWaiters()
    }

    private func resumeWaiters() {
        let pending = Array(waiters.values)
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }

    /// A native session may not return promptly after its view disappears.
    /// Release the cached loading state immediately so another view can retry.
    private func cancelTranslation(generation cancelledGeneration: Int) {
        guard generation == cancelledGeneration else { return }
        generation += 1
        isTranslating = false
        resumeWaiters()
    }
}
#endif
