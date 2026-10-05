import Foundation

/// Idiomas disponíveis na interface nativa do UAPPKit.
public struct UAPPLanguage: Identifiable, Sendable, Equatable, Hashable {
    public let identifier: String
    public let nativeName: String

    public var id: String {
        identifier
    }

    /// Nome do idioma traduzido para o idioma atualmente selecionado.
    public func localizedName(in locale: Locale) -> String {
        if identifier == "pt-BR",
           let name = locale.localizedString(forLanguageCode: "pt")
        {
            return name.capitalized(with: locale)
        }

        let name = locale.localizedString(forIdentifier: identifier) ?? nativeName
        return name.capitalized(with: locale)
    }

    /// Nome localizado pronto para uso em menus e seletores.
    public func displayName(in locale: Locale) -> String {
        "\(flagEmoji) \(localizedName(in: locale))"
    }

    /// Bandeira associada à região principal do idioma.
    public var flagEmoji: String {
        switch identifier {
        case "pt-BR": "🇧🇷"
        case "en": "🇺🇸"
        case "de": "🇩🇪"
        case "fr": "🇫🇷"
        case "es": "🇪🇸"
        case "ja": "🇯🇵"
        case "zh-Hans": "🇨🇳"
        case "zh-Hant": "🇹🇼"
        case "pl": "🇵🇱"
        case "hi": "🇮🇳"
        case "vi": "🇻🇳"
        case "it": "🇮🇹"
        case "ko": "🇰🇷"
        default: "🌐"
        }
    }

    public init(identifier: String, nativeName: String) {
        self.identifier = identifier
        self.nativeName = nativeName
    }

    /// Conjunto inicial de idiomas suportados pelo pacote.
    public static let supported: [UAPPLanguage] = [
        .init(identifier: "pt-BR", nativeName: "Português (Brasil)"),
        .init(identifier: "en", nativeName: "English"),
        .init(identifier: "de", nativeName: "Deutsch"),
        .init(identifier: "fr", nativeName: "Français"),
        .init(identifier: "es", nativeName: "Español"),
        .init(identifier: "ja", nativeName: "日本語"),
        .init(identifier: "zh-Hans", nativeName: "简体中文"),
        .init(identifier: "zh-Hant", nativeName: "繁體中文"),
        .init(identifier: "pl", nativeName: "Polski"),
        .init(identifier: "hi", nativeName: "हिन्दी"),
        .init(identifier: "vi", nativeName: "Tiếng Việt"),
        .init(identifier: "it", nativeName: "Italiano"),
        .init(identifier: "ko", nativeName: "한국어")
    ]
}

enum UAPPLocalizationPreferences {
    static let storageKey = "UAPPKit.selectedLanguage"
    static let presentationStorageKey = "UAPPKit.presentationLanguage"
    static let fallbackIdentifier = "pt-BR"

    static var defaultIdentifier: String {
        matchingIdentifier(for: Locale.current.identifier)
            ?? matchingIdentifier(for: Locale.preferredLanguages.first)
            ?? fallbackIdentifier
    }

    static func matchingIdentifier(for identifier: String?) -> String? {
        guard let identifier, !identifier.isEmpty else { return nil }
        if let exact = UAPPLanguage.supported.first(where: { $0.identifier.caseInsensitiveCompare(identifier) == .orderedSame }) {
            return exact.identifier
        }

        let normalized = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        if let regional = UAPPLanguage.supported.first(where: {
            normalized.hasPrefix($0.identifier.lowercased() + "-")
        }) {
            return regional.identifier
        }

        let languageCode = Locale(identifier: identifier).language.languageCode?.identifier
        return UAPPLanguage.supported.first {
            Locale(identifier: $0.identifier).language.languageCode?.identifier == languageCode
        }?.identifier
    }

    @MainActor
    static func ensureStored(initialIdentifier: String? = nil) -> String {
        let defaults = UserDefaults.standard
        if let initialIdentifier,
           let resolved = matchingIdentifier(for: initialIdentifier)
        {
            defaults.set(resolved, forKey: storageKey)
            return resolved
        }

        if let stored = defaults.string(forKey: storageKey),
           let supported = matchingIdentifier(for: stored)
        {
            if stored != supported {
                defaults.set(supported, forKey: storageKey)
            }
            return supported
        }

        let resolved = matchingIdentifier(for: initialIdentifier) ?? defaultIdentifier
        defaults.set(resolved, forKey: storageKey)
        return resolved
    }

    @MainActor
    static func select(identifier: String) -> String {
        let resolved = matchingIdentifier(for: identifier) ?? fallbackIdentifier
        UserDefaults.standard.set(resolved, forKey: storageKey)
        return resolved
    }

    @MainActor
    static func preparePresentation(initialIdentifier: String?) -> String {
        let resolved = matchingIdentifier(for: initialIdentifier) ?? hostIdentifier
        UserDefaults.standard.set(resolved, forKey: presentationStorageKey)
        return resolved
    }

    @MainActor
    static func selectPresentation(identifier: String) -> String {
        let resolved = matchingIdentifier(for: identifier) ?? fallbackIdentifier
        UserDefaults.standard.set(resolved, forKey: presentationStorageKey)
        return resolved
    }

    static var hostIdentifier: String {
        if let stored = UserDefaults.standard.string(forKey: storageKey),
           let supported = matchingIdentifier(for: stored)
        {
            return supported
        }
        return defaultIdentifier
    }
}

func uappLocalized(_ key: String) -> String {
    let identifier = UserDefaults.standard.string(forKey: UAPPLocalizationPreferences.presentationStorageKey)
        ?? UAPPLocalizationPreferences.hostIdentifier
    return uappLocalized(key, languageIdentifier: identifier)
}

func uappLocalized(_ key: String, languageIdentifier: String) -> String {
    let bundle = Bundle.module
    let identifier = UAPPLocalizationPreferences.matchingIdentifier(for: languageIdentifier)
        ?? UAPPLocalizationPreferences.fallbackIdentifier
    let path = bundle.path(forResource: identifier, ofType: "lproj")
        ?? bundle.path(forResource: UAPPLocalizationPreferences.fallbackIdentifier, ofType: "lproj")
    return (path.flatMap(Bundle.init(path:)) ?? bundle)
        .localizedString(forKey: key, value: key, table: nil)
}

func uappLocalizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: uappLocalized(key), arguments: arguments)
}

#if canImport(SwiftUI)
import Combine
import SwiftUI

struct UAPPOnChangeModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let action: (Value) -> Void

    @State private var previousValue: Value?

    func body(content: Content) -> some View {
        content.onReceive(Just(value)) { newValue in
            guard let previousValue else {
                previousValue = newValue
                return
            }
            guard previousValue != newValue else {
                return
            }
            self.previousValue = newValue
            action(newValue)
        }
    }
}

extension View {
    /// Observes `value` without the deprecated `onChange(of:perform:)`, keeping macOS 13 support.
    @ViewBuilder
    func uappOnChange<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        if #available(iOS 17, macOS 14, *) {
            onChange(of: value) { _, newValue in action(newValue) }
        } else {
            modifier(UAPPOnChangeModifier(value: value, action: action))
        }
    }
}

struct UAPPLanguageMenu: View {
    var accentOverride: Color?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "globe")
                .foregroundStyle(accentColor)
        }
        .accessibilityLabel(Text(verbatim: uappLocalized("language.menu")))
        .popover(isPresented: $isPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            UAPPLanguageOptions(accentColor: accentColor, isPresented: $isPresented)
                .uappCompactPopover()
        }
    }

    private var accentColor: Color {
        theme.resolved(for: colorScheme).accent ?? accentOverride ?? .accentColor
    }
}

extension View {
    @ViewBuilder
    func uappCompactPopover() -> some View {
        if #available(iOS 16.4, macOS 13.3, *) {
            presentationCompactAdaptation(.popover)
        } else {
            self
        }
    }
}

/// Lista de idiomas do popover; a seleção vale para as telas apresentadas pelo pacote.
struct UAPPLanguageOptions: View {
    let accentColor: Color
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedIdentifier = UAPPLocalizationPreferences.defaultIdentifier

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(UAPPLanguage.supported) { language in
                    Button {
                        select(language)
                    } label: {
                        HStack(spacing: 10) {
                            Text(verbatim: language.displayName(in: Locale(identifier: selectedIdentifier)))
                                .lineLimit(1)
                            Spacer(minLength: 12)
                            if language.identifier == selectedIdentifier {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.resolved(for: colorScheme).primaryText)
                }
            }
            .padding(8)
        }
        .frame(width: 250)
    }

    func select(_ language: UAPPLanguage) {
        selectedIdentifier = UAPPLocalizationPreferences.selectPresentation(identifier: language.identifier)
        isPresented = false
    }
}
#endif
