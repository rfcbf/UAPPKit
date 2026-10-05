import SwiftUI
import UAPPKit
import UIKit

struct DemoFormLayout: ViewModifier {
    let isSecondary: Bool

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .scrollContentBackground(.hidden)
                .contentMargins(.trailing, 10, for: .scrollContent)
                .padding(.leading, isSecondary ? 8 : 0)
                .padding(.trailing, 8)
                .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        } else {
            content
                .padding(.leading, isSecondary ? 8 : 0)
                .padding(.trailing, 8)
                .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        }
    }
}

struct PersistentNavigationBar: ViewModifier {
    func body(content: Content) -> some View {
        // `toolbarMinimizationBehavior` só existe no SDK do iOS 27 (Swift 6.4+).
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            content.toolbarMinimizationBehavior(.never, for: .navigationBar)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

struct DemoAppearanceControl: View {
    let title: String
    let systemTitle: String
    let lightTitle: String
    let darkTitle: String
    @Binding var selection: String

    var body: some View {
        GeometryReader { proxy in
            Picker(title, selection: $selection) {
                Text(verbatim: systemTitle).tag(DemoAppearance.system.rawValue)
                Text(verbatim: lightTitle).tag(DemoAppearance.light.rawValue)
                Text(verbatim: darkTitle).tag(DemoAppearance.dark.rawValue)
            }
            .pickerStyle(.segmented)
            .frame(width: min(312, max(0, proxy.size.width - 32)))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 32)
    }
}

struct DemoLanguageMenu: View {
    let title: String
    @Binding var selection: String
    @Environment(\.locale) private var locale

    private var selectedLanguage: UAPPLanguage {
        UAPPLanguage.supported.first { $0.identifier == selection }
            ?? UAPPLanguage.supported[0]
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(verbatim: title)

            Spacer(minLength: 8)

            Menu {
                ForEach(UAPPLanguage.supported) { language in
                    let isSelected = language.identifier == selection
                    Button {
                        selection = language.identifier
                    } label: {
                        HStack(spacing: 12) {
                            Text(verbatim: language.displayName(in: locale))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(minWidth: 204, alignment: .leading)
                    }
                    .accessibilityLabel(Text(verbatim: language.displayName(in: locale)))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            } label: {
                HStack(spacing: 4) {
                    Text(verbatim: selectedLanguage.displayName(in: locale))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel(Text(verbatim: title))
            .accessibilityValue(Text(verbatim: selectedLanguage.displayName(in: locale)))
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}

struct ThemePaletteCard: View {
    let title: String
    let subtitle: String
    let languageIdentifier: String
    @Binding var background: String
    @Binding var cardBackground: String
    @Binding var primaryText: String
    @Binding var secondaryText: String
    @Binding var accent: String
    @Binding var buttonText: String
    @Binding var separator: String
    let onChange: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 1)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                colorRow("demo.color.background", hex: $background, fallback: Color(uiColor: .systemGroupedBackground))
                colorRow("demo.color.card_background", hex: $cardBackground, fallback: Color(uiColor: .secondarySystemGroupedBackground))
                colorRow("demo.color.primary_text", hex: $primaryText, fallback: .primary)
                colorRow("demo.color.secondary_text", hex: $secondaryText, fallback: .secondary)
                colorRow("demo.color.accent", hex: $accent, fallback: Color.accentColor)
                colorRow("demo.color.button_text", hex: $buttonText, fallback: .white)
                colorRow("demo.color.separator", hex: $separator, fallback: Color(uiColor: .separator))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private func colorRow(_ titleKey: String, hex: Binding<String>, fallback: Color) -> some View {
        ThemeColorRow(
            title: Text(verbatim: DemoLocalized.string(titleKey, languageIdentifier: languageIdentifier)),
            selectLabel: DemoLocalized.string("demo.color.select", languageIdentifier: languageIdentifier),
            defaultLabel: DemoLocalized.string("demo.color.default", languageIdentifier: languageIdentifier),
            invalidLabel: DemoLocalized.string("demo.color.invalid", languageIdentifier: languageIdentifier),
            hex: hex,
            fallback: fallback,
            onChange: onChange
        )
    }
}

struct ThemeColorRow: View {
    let title: Text
    let selectLabel: String
    let defaultLabel: String
    let invalidLabel: String
    @Binding var hex: String
    let fallback: Color
    let onChange: () -> Void

    private var selectedColor: Color {
        DemoHexColor.color(from: hex) ?? fallback
    }

    var body: some View {
        HStack(spacing: 10) {
            ColorPicker(selection: Binding(
                get: { selectedColor },
                set: { newColor in
                    hex = DemoHexColor.hex(from: newColor)
                    onChange()
                }
            ), supportsOpacity: false) {
                title
            }
            .labelsHidden()
            .accessibilityLabel(Text(verbatim: selectLabel))

            title
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField(defaultLabel, text: $hex, prompt: Text(verbatim: "#RRGGBB"))
                .font(.system(.caption, design: .monospaced))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .frame(width: 92)
                .padding(.vertical, 8)
                .padding(.horizontal, 9)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 9))
                .uappOnChange(of: hex) { newValue in
                    if newValue.isEmpty || DemoHexColor.color(from: newValue) != nil {
                        onChange()
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if !hex.isEmpty, DemoHexColor.color(from: hex) == nil {
                        Text(verbatim: invalidLabel)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .offset(y: 15)
                    }
                }
                .padding(.trailing, 8)
                .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
