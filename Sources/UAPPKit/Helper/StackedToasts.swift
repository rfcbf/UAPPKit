// Adapted from StackedToasts by Balaji Venkatesh (09/08/26).
import SwiftUI

/// Severity also controls whether a notification can disappear automatically.
public enum UAPPToastKind: String, Sendable, CaseIterable {
    case error, success, information

    var symbol: String {
        switch self {
        case .error: "exclamationmark.triangle.fill"
        case .success: "checkmark.circle.fill"
        case .information: "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .error: .red
        case .success: .green
        case .information: .accentColor
        }
    }

    /// Title shown above the message when the caller does not provide one.
    var titleKey: String {
        "toast.title.\(rawValue)"
    }

    var autoDismissInterval: Duration? {
        self == .success ? .seconds(6) : nil
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let kind: UAPPToastKind
}

@MainActor
struct StackedToasts: View {
    @Binding var toasts: [Toast]
    var title: String?
    var actionTitle: String?
    var action: (@MainActor () -> Void)?
    var onDismiss: @MainActor () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(Array(toasts.enumerated()), id: \.element.id) { index, toast in
                // Only the two toasts right behind the newest one stay visible.
                let depth = toasts.count - index - 1
                ToastView(toast: toast, title: title, actionTitle: actionTitle, action: action) {
                    toasts.removeAll { $0.id == toast.id }
                    onDismiss()
                }
                .scaleEffect(1 - min(CGFloat(depth) * 0.05, 0.1), anchor: .bottom)
                .offset(y: min(CGFloat(depth) * 10, 20))
                .opacity(depth > 2 ? 0 : 1)
                .zIndex(Double(index))
                .allowsHitTesting(depth == 0)
                .accessibilityHidden(depth != 0)
                .transition(reduceMotion ? .opacity : ToastTransition.stacked)
            }
        }
        .frame(maxWidth: .infinity)
        // Lifts the stack so the toasts pushed behind the newest one stay on screen.
        .padding(.bottom, min(CGFloat(max(toasts.count - 1, 0)) * 12.5, 25))
        .modifier(ToastSwipeContainer())
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 1), value: toasts)
        .allowsHitTesting(!toasts.isEmpty)
    }
}

private enum ToastTransition {
    /// Rises from below and leaves to the leading edge, both through a blur.
    @MainActor static var stacked: AnyTransition {
        let insertion = AnyTransition.offset(y: 500)
        let removal = AnyTransition.move(edge: .leading)
        if #available(iOS 17.0, macOS 14.0, *) {
            return .asymmetric(
                insertion: insertion.combined(with: AnyTransition(.blurReplace)),
                removal: removal.combined(with: AnyTransition(.blurReplace))
            )
        }
        return .asymmetric(
            insertion: insertion.combined(with: .opacity),
            removal: removal.combined(with: .opacity)
        )
    }
}

@MainActor
private struct ToastView: View {
    let toast: Toast
    let title: String?
    let actionTitle: String?
    let action: (@MainActor () -> Void)?
    let onDismiss: @MainActor () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var shownAt = Date()

    /// Time until the toast closes by itself. Errors, recovery actions and accessibility
    /// notifications stay until dismissed.
    private var dismissInterval: Duration? {
        guard action == nil, !voiceOverEnabled, !dynamicTypeSize.isAccessibilitySize else { return nil }
        return toast.kind.autoDismissInterval
    }

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: toast.kind.symbol)
                .font(.title)
                .foregroundStyle(toast.kind.color.gradient)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: title ?? uappLocalized(toast.kind.titleKey, languageIdentifier: locale.identifier))
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(verbatim: toast.message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                Spacer(minLength: 0)
                Button(actionTitle, action: action)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(toast.kind.color)
                    .frame(minHeight: 44)
            } else if let dismissInterval {
                Spacer(minLength: 0)
                ToastCountdownRing(
                    start: shownAt,
                    total: ToastCountdown.seconds(dismissInterval),
                    color: toast.kind.color
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 310, alignment: .leading)
        .frame(minHeight: 65)
        .background { ToastTintBackground(color: toast.kind.color) }
        .modifier(ToastGlassSurface())
        .contentShape(Capsule())
        .buttonStyle(.plain)
        .compositingGroup()
        .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 10)
        // A tap anywhere on the toast closes it; the action button keeps its own tap.
        .onTapGesture(perform: onDismiss)
        .modifier(ToastSwipeToDismiss(onDismiss: onDismiss))
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text(verbatim: uappLocalized("navigation.close", languageIdentifier: locale.identifier)), onDismiss)
        .task(id: toast.id) {
            guard let dismissInterval else { return }
            shownAt = Date()
            do {
                try await Task.sleep(for: dismissInterval)
                guard !Task.isCancelled else { return }
                onDismiss()
            } catch { /* A removed notification cancels its timer. */ }
        }
    }
}

/// Countdown shown by a toast that closes by itself.
enum ToastCountdown {
    static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    /// Share of the time still left, from 1 down to 0.
    static func fraction(total: Double, elapsed: Double) -> Double {
        guard total > 0 else { return 0 }
        return min(max(1 - elapsed / total, 0), 1)
    }

    /// Whole seconds still left, rounded up so the ring never reads zero while it is on screen.
    static func secondsLeft(total: Double, elapsed: Double) -> Int {
        Int((fraction(total: total, elapsed: elapsed) * total).rounded(.up))
    }
}

/// Ring that empties as the toast runs out of time, with the seconds left inside.
private struct ToastCountdownRing: View {
    let start: Date
    let total: Double
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let elapsed = context.date.timeIntervalSince(start)
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: ToastCountdown.fraction(total: total, elapsed: elapsed))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(verbatim: String(ToastCountdown.secondsLeft(total: total, elapsed: elapsed)))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }
}

/// Subtle gradient in the toast color, stronger at the top (inspired by the Siri bubble).
private struct ToastTintBackground: View {
    let color: Color

    var body: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: Array(repeating: color.opacity(0.15), count: 3)
                    + Array(repeating: color.opacity(0.1), count: 3)
                    + Array(repeating: Color.clear, count: 3)
            )
            .clipShape(Capsule())
        } else {
            LinearGradient(colors: [color.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)
                .clipShape(Capsule())
        }
    }
}

/// The toast surface is the system glass and nothing else behind it, so its transparency follows
/// what the person chose in Settings (clear or tinted Liquid Glass, Reduce Transparency).
private struct ToastGlassSurface: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
        #else
        content.background(.regularMaterial, in: Capsule())
        #endif
    }
}

/// Swiping the toast to the leading edge dismisses it. iOS 27 uses the system swipe action;
/// earlier systems follow the finger.
@MainActor
private struct ToastSwipeToDismiss: ViewModifier {
    let onDismiss: @MainActor () -> Void
    @State private var drag: CGFloat = 0

    func body(content: Content) -> some View {
        #if os(iOS) && compiler(>=6.4)
        if #available(iOS 27.0, *) {
            content.swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: onDismiss) {
                    Image(systemName: "checkmark")
                }
            }
        } else {
            dragging(content)
        }
        #else
        dragging(content)
        #endif
    }

    private func dragging(_ content: Content) -> some View {
        // Only a drag toward the leading edge moves the toast.
        let travel: CGFloat = max(-drag, 0)
        let fade: CGFloat = min(travel / 200, 0.6)
        return content
            .offset(x: -travel)
            .opacity(Double(1 - fade))
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { drag = $0.translation.width }
                    .onEnded { value in
                        if value.translation.width < -80 {
                            onDismiss()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 1)) { drag = 0 }
                        }
                    }
            )
    }
}

private struct ToastSwipeContainer: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS) && compiler(>=6.4)
        if #available(iOS 27.0, *) {
            content.swipeActionsContainer()
        } else {
            content
        }
        #else
        content
        #endif
    }
}

@MainActor
private struct UAPPToastModifier: ViewModifier {
    @Binding var message: String?
    let kind: UAPPToastKind
    let title: String?
    let actionTitle: String?
    let action: (@MainActor () -> Void)?
    @State private var toasts: [Toast] = []

    func body(content: Content) -> some View {
        content
            // Floats over the content, as a system banner; it never pushes the screen up.
            .overlay(alignment: .bottom) {
                StackedToasts(toasts: $toasts, title: title, actionTitle: actionTitle, action: action) {
                    message = nil
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .onAppear { update(message) }
            .uappOnChange(of: message) { update($0) }
            .uappOnChange(of: kind) { _ in update(message) }
    }

    private func update(_ message: String?) {
        guard let message, !message.isEmpty else {
            toasts.removeAll()
            return
        }
        guard toasts.last?.message != message || toasts.last?.kind != kind else { return }
        toasts = [Toast(message: message, kind: kind)]
    }
}

public extension View {
    /// Presents a localized notification. Dismissal clears the originating state.
    /// Full-screen loading failures should keep their persistent retry state.
    @MainActor
    func uappToast(
        message: Binding<String?>,
        kind: UAPPToastKind = .error,
        title: String? = nil,
        actionTitle: String? = nil,
        action: (@MainActor () -> Void)? = nil
    ) -> some View {
        modifier(UAPPToastModifier(message: message, kind: kind, title: title, actionTitle: actionTitle, action: action))
    }
}

/// Preview-only gallery: every kind, with and without title and action, plus the stack.
@MainActor
private struct ToastGallery: View {
    @State private var toasts: [Toast] = []
    @State private var showsTitle = false
    @State private var showsAction = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $showsTitle) { Text(verbatim: "Título próprio") }
                    Toggle(isOn: $showsAction) { Text(verbatim: "Botão de ação") }
                }
                Section {
                    row("Erro", kind: .error, message: "Não foi possível salvar. Tente novamente.")
                    row("Sucesso (some em 6 s)", kind: .success, message: "Alterações salvas.")
                    row("Informação", kind: .information, message: "A sincronização continua em segundo plano.")
                    row(
                        "Mensagem longa", kind: .error,
                        message: "O acesso à câmera foi negado. Libere o acesso nos Ajustes para tirar uma foto."
                    )
                }
                Section {
                    Button(role: .destructive) { toasts.removeAll() } label: { Text(verbatim: "Limpar") }
                }
            }
            .navigationTitle(Text(verbatim: "Avisos"))
        }
        .overlay(alignment: .bottom) {
            stack
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }

    private var stack: StackedToasts {
        var stack = StackedToasts(toasts: $toasts)
        if showsTitle {
            stack.title = "Acesso à câmera"
        }
        if showsAction {
            stack.actionTitle = "Ajustes"
            stack.action = {}
        }
        return stack
    }

    private func row(_ label: String, kind: UAPPToastKind, message: String) -> some View {
        Button { toasts.append(Toast(message: message, kind: kind)) } label: {
            Label { Text(verbatim: label) } icon: {
                Image(systemName: kind.symbol).foregroundStyle(kind.color)
            }
        }
    }
}

#Preview("Galeria de avisos") {
    ToastGallery()
}

#Preview("Galeria de avisos — escuro") {
    ToastGallery().preferredColorScheme(.dark)
}

#Preview("Todos os tipos") {
    VStack(spacing: 16) {
        ForEach(UAPPToastKind.allCases, id: \.self) { kind in
            StackedToasts(toasts: .constant([Toast(message: uappLocalized("photo.hint"), kind: kind)]))
        }
        StackedToasts(
            toasts: .constant([Toast(message: uappLocalized("photo.camera_denied"), kind: .error)]),
            title: uappLocalized("photo.camera_access"),
            actionTitle: uappLocalized("photo.settings"),
            action: {}
        )
    }
    .padding()
}

#Preview("Erro com recuperação") {
    Color.clear.uappToast(
        message: .constant(uappLocalized("photo.camera_denied")),
        title: uappLocalized("photo.camera_access"),
        actionTitle: uappLocalized("photo.settings"),
        action: {}
    )
}

#Preview("Informação e texto ampliado") {
    Color.clear.uappToast(message: .constant(uappLocalized("photo.hint")), kind: .information)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Pilha de avisos") {
    StackedToasts(toasts: .constant([
        Toast(message: uappLocalized("photo.error"), kind: .error),
        Toast(message: uappLocalized("photo.camera_denied"), kind: .information)
    ]))
    .padding()
}
