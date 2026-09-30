#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum UAPPChangelogAutoplay {
    static func isEnabled(
        configuration: UAPPChangelogConfiguration,
        imageCount: Int,
        isVisible: Bool,
        isApplicationActive: Bool,
        voiceOver: Bool,
        reduceMotion: Bool
    ) -> Bool {
        configuration.automaticallyScrolls && imageCount > 1 && isVisible
            && isApplicationActive && !voiceOver && !reduceMotion
    }
}

/// SDK hosting controllers don't necessarily inherit a SwiftUI scene phase.
struct UAPPChangelogApplicationActivity: ViewModifier {
    @Binding var isActive: Bool

    func body(content: Content) -> some View {
        #if canImport(UIKit)
        content
            .onAppear { isActive = UIApplication.shared.applicationState == .active }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                isActive = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                isActive = false
            }
        #elseif canImport(AppKit)
        content
            .onAppear { isActive = NSApplication.shared.isActive }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                isActive = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                isActive = false
            }
        #else
        content
        #endif
    }
}
#endif
