#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Paleta global das telas nativas do UAPPKit.
///
/// Cada variante pode sobrescrever somente as cores desejadas. Os valores
/// omitidos mantêm as cores semânticas do sistema e se adaptam ao modo atual.
public struct UAPPTheme: Sendable {
    /// Cores para um modo de aparência.
    public struct Palette: Sendable {
        public var background: Color?
        public var cardBackground: Color?
        public var primaryText: Color?
        public var secondaryText: Color?
        public var accent: Color?
        public var buttonText: Color?
        public var separator: Color?

        public init(
            background: Color? = nil,
            cardBackground: Color? = nil,
            primaryText: Color? = nil,
            secondaryText: Color? = nil,
            accent: Color? = nil,
            separator: Color? = nil,
            buttonText: Color? = nil
        ) {
            self.background = background
            self.cardBackground = cardBackground
            self.primaryText = primaryText
            self.secondaryText = secondaryText
            self.accent = accent
            self.buttonText = buttonText
            self.separator = separator
        }
    }

    public let light: Palette
    public let dark: Palette

    /// Tema sem personalização, baseado nas cores dinâmicas do sistema Apple.
    public static let system = UAPPTheme()

    public init(light: Palette = .init(), dark: Palette = .init()) {
        self.light = light
        self.dark = dark
    }

    func resolved(for colorScheme: ColorScheme) -> UAPPResolvedPalette {
        let palette = colorScheme == .dark ? dark : light
        return UAPPResolvedPalette(
            background: palette.background ?? Self.systemBackground,
            cardBackground: palette.cardBackground ?? Self.systemCardBackground,
            primaryText: palette.primaryText ?? .primary,
            secondaryText: palette.secondaryText ?? .secondary,
            accent: palette.accent,
            buttonText: palette.buttonText ?? .white,
            separator: palette.separator ?? Self.systemSeparator
        )
    }

    private static var systemBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.clear
        #endif
    }

    private static var systemCardBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color.clear
        #endif
    }

    private static var systemSeparator: Color {
        #if canImport(UIKit)
        Color(uiColor: .separator)
        #elseif canImport(AppKit)
        Color(nsColor: .separatorColor)
        #else
        Color.primary.opacity(0.12)
        #endif
    }
}

struct UAPPResolvedPalette {
    let background: Color
    let cardBackground: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color?
    let buttonText: Color
    let separator: Color
}

struct UAPPNavigationBarModifier: ViewModifier {
    let title: Text
    let accentColor: Color
    var showsCloseButton = true
    var showsLanguageMenu = true
    var onClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .environment(\.locale, Locale(identifier: selectedLanguage))
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            #endif
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: { if let onClose { onClose() } else { dismiss() } }) {
                            Image(systemName: "xmark")
                                .foregroundStyle(accentColor)
                        }
                        .accessibilityLabel(Text(verbatim: uappLocalized("navigation.close")))
                    }
                }
                if showsLanguageMenu {
                    ToolbarItem(placement: .primaryAction) {
                        UAPPLanguageMenu(accentOverride: accentColor)
                    }
                }
            }
            .tint(accentColor)
    }

    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier
}

extension View {
    func uappNavigationBar(
        titleKey: String,
        accentColor: Color,
        showsCloseButton: Bool = true,
        showsLanguageMenu: Bool = true,
        onClose: (() -> Void)? = nil
    ) -> some View {
        modifier(
            UAPPNavigationBarModifier(
                title: Text(verbatim: uappLocalized(titleKey)),
                accentColor: accentColor,
                showsCloseButton: showsCloseButton,
                showsLanguageMenu: showsLanguageMenu,
                onClose: onClose
            )
        )
    }

    func uappNavigationBar(
        verbatimTitle: String,
        accentColor: Color,
        showsCloseButton: Bool = true,
        showsLanguageMenu: Bool = true,
        onClose: (() -> Void)? = nil
    ) -> some View {
        modifier(
            UAPPNavigationBarModifier(
                title: Text(verbatim: verbatimTitle),
                accentColor: accentColor,
                showsCloseButton: showsCloseButton,
                showsLanguageMenu: showsLanguageMenu,
                onClose: onClose
            )
        )
    }
}

private struct UAPPThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = UAPPTheme.system
}

extension EnvironmentValues {
    var uappTheme: UAPPTheme {
        get { self[UAPPThemeEnvironmentKey.self] }
        set { self[UAPPThemeEnvironmentKey.self] = newValue }
    }
}
#endif
