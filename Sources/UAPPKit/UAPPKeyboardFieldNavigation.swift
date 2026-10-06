#if canImport(SwiftUI)
import SwiftUI

private struct UAPPKeyboardFieldNavigation<Field: Hashable>: ViewModifier {
    let focusedField: FocusState<Field?>.Binding
    let fields: [Field]
    let accentColor: Color

    private var focusedIndex: Int? {
        guard let field = focusedField.wrappedValue else { return nil }
        return fields.firstIndex(of: field)
    }

    func body(content: Content) -> some View {
        #if canImport(UIKit)
        content
            .tint(accentColor)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if focusedField.wrappedValue != nil {
                    keyboardAccessory
                }
            }
        #else
        content
            .tint(accentColor)
        #endif
    }

    #if canImport(UIKit)
    private var keyboardAccessory: some View {
        HStack {
            if fields.count > 1 {
                HStack(spacing: 0) {
                    Button {
                        moveFocus(by: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(focusedIndex == nil || focusedIndex == 0)
                    .accessibilityLabel(Text(verbatim: uappLocalized("navigation.previous_field")))

                    Button {
                        moveFocus(by: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(focusedIndex == nil || focusedIndex == fields.count - 1)
                    .accessibilityLabel(Text(verbatim: uappLocalized("navigation.next_field")))
                }
                .buttonStyle(.plain)
                .padding(2)
                .background(.regularMaterial, in: Capsule())
            }

            Spacer(minLength: 12)

            Button {
                focusedField.wrappedValue = nil
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: uappLocalized("navigation.close")))
            .padding(2)
            .background(.regularMaterial, in: Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }
    #endif

    private func moveFocus(by offset: Int) {
        guard let focusedIndex else { return }
        let destination = focusedIndex + offset
        guard fields.indices.contains(destination) else { return }
        focusedField.wrappedValue = fields[destination]
    }
}

public extension View {
    /// Adds reusable previous, next, and keyboard-dismiss controls for focused fields.
    ///
    /// The field array defines the focus order and may change with the current form step.
    /// On iOS and iPadOS, controls appear above the software keyboard.
    func uappKeyboardFieldNavigation<Field: Hashable>(
        focusedField: FocusState<Field?>.Binding,
        fields: [Field],
        accentColor: Color = .accentColor
    ) -> some View {
        modifier(
            UAPPKeyboardFieldNavigation(
                focusedField: focusedField,
                fields: fields,
                accentColor: accentColor
            )
        )
    }
}
#endif
