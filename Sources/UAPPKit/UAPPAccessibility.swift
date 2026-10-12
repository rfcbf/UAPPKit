#if canImport(SwiftUI)
import SwiftUI

/// Accessibility rules shared by every UAPPKit screen.
enum UAPPAccessibility {
    /// Largest text size the screens follow: two steps above the system default. Above it cards
    /// and grids lose their composition, so text stops growing there.
    static let maximumTextSize = DynamicTypeSize.xLarge
}

extension View {
    /// Caps the text size at what UAPPKit layouts support. Applied at the root of each screen.
    func uappTextSizeLimit() -> some View {
        dynamicTypeSize(...UAPPAccessibility.maximumTextSize)
    }

    /// A transition with movement (slide, scale) that becomes a fade when the person asked the
    /// system to reduce motion.
    func uappMotionTransition(_ transition: AnyTransition) -> some View {
        modifier(UAPPMotionTransition(transition: transition))
    }
}

private struct UAPPMotionTransition: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let transition: AnyTransition

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? .opacity : transition)
    }
}

#Preview("Transição que respeita Reduzir Movimento") {
    Text(verbatim: "UAPPKit")
        .uappMotionTransition(.scale.combined(with: .opacity))
        .uappTextSizeLimit()
        .padding()
}
#endif
