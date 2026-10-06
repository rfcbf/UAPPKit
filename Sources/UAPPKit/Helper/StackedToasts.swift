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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(Array(toasts.suffix(3).enumerated()), id: \.element.id) { index, toast in
                let depth = min(toasts.count, 3) - index - 1
                ToastView(toast: toast, title: title, actionTitle: actionTitle, action: action) {
                    toasts.removeAll { $0.id == toast.id }
                    onDismiss()
                }
                .scaleEffect(dynamicTypeSize.isAccessibilitySize ? 1 : 1 - CGFloat(depth) * 0.04, anchor: .bottom)
                .offset(y: CGFloat(depth) * -10)
                .zIndex(Double(index))
                .allowsHitTesting(depth == 0)
                .accessibilityHidden(depth != 0)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.top, toasts.count > 1 ? 20 : 0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: toasts)
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: toast.kind.symbol)
                .font(.title2)
                .foregroundStyle(toast.kind.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                if let title {
                    Text(verbatim: title).font(.callout.weight(.semibold))
                }
                Text(verbatim: toast.message)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.callout.weight(.semibold))
                        .frame(minHeight: 44)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Text(verbatim: uappLocalized("navigation.close", languageIdentifier: locale.identifier)))
        }
        .padding(16)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 480)
        .foregroundStyle(.primary)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(toast.kind.color.opacity(0.08))
                }
        }
        .modifier(ToastGlassSurface())
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text(verbatim: uappLocalized("navigation.close", languageIdentifier: locale.identifier)), onDismiss)
        .task(id: toast.id) {
            // Keep errors, recovery actions and accessibility notifications available.
            guard action == nil, !voiceOverEnabled, !dynamicTypeSize.isAccessibilitySize,
                  let interval = toast.kind.autoDismissInterval else { return }
            do {
                try await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                onDismiss()
            } catch { /* A removed notification cancels its timer. */ }
        }
    }
}

private struct ToastGlassSurface: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !toasts.isEmpty {
                    StackedToasts(toasts: $toasts, title: title, actionTitle: actionTitle, action: action) {
                        message = nil
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }
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
