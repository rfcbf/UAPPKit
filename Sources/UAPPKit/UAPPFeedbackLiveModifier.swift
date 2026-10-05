import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct UAPPFeedbackLiveModifier: ViewModifier {
    let client: UAPPClient?
    let onChange: @MainActor () async -> Void
    var updates: (UAPPFeedbackLiveConfiguration) throws -> AsyncThrowingStream<Void, any Error> = {
        try UAPPFeedbackLive.updates($0)
    }

    var debounce: Duration = .milliseconds(250)
    var reconnectDelay: Duration = .seconds(10)
    var fallbackInterval: Duration = .seconds(15)
    @Environment(\.scenePhase) private var scenePhase
    #if canImport(UIKit)
    @State private var isForeground = UIApplication.shared.applicationState != .background
    #endif

    private var canRefresh: Bool {
        #if canImport(UIKit)
        isForeground
        #else
        scenePhase != .background
        #endif
    }

    func body(content: Content) -> some View {
        content
            .task(id: canRefresh) {
                guard let client, canRefresh else { return }
                while !Task.isCancelled {
                    do {
                        let configuration = try await client.feedbackLiveConfiguration()
                        for try await _ in try updates(configuration) {
                            try await Task.sleep(for: debounce)
                            await onChange()
                        }
                    } catch is CancellationError { return }
                    catch { /* Reconnect while the periodic fallback remains available. */ }
                    do { try await Task.sleep(for: reconnectDelay) } catch { return }
                }
            }
            .task(id: canRefresh) {
                guard client != nil, canRefresh else { return }
                await onChange()
                while !Task.isCancelled {
                    do { try await Task.sleep(for: fallbackInterval) } catch { return }
                    await onChange()
                }
            }
            #if canImport(UIKit)
            // A standalone UIHostingController may not receive the host's scenePhase.
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                isForeground = false
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                isForeground = true
            }
            #endif
    }
}
