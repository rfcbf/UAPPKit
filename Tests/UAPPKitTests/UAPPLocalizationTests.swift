import Foundation
import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@Test("nomes de idioma acompanham o locale selecionado")
func languageNamesFollowSelectedLocale() {
    let portuguese = UAPPLanguage.supported[0]
    let english = UAPPLanguage.supported[1]

    #expect(portuguese.localizedName(in: Locale(identifier: "pt-BR")) == "Português")
    #expect(portuguese.localizedName(in: Locale(identifier: "en")) == "Portuguese")
    #expect(english.localizedName(in: Locale(identifier: "de")) == "Englisch")
}

@Test("idiomas exibem bandeiras associadas")
func supportedLanguagesHaveFlags() {
    #expect(UAPPLanguage.supported.map(\.flagEmoji) == [
        "🇧🇷", "🇺🇸", "🇩🇪", "🇫🇷", "🇪🇸", "🇯🇵", "🇨🇳", "🇹🇼",
        "🇵🇱", "🇮🇳", "🇻🇳", "🇮🇹", "🇰🇷"
    ])
}

@Test("textos do pacote seguem o idioma escolhido, independentemente do sistema")
func packageStringsFollowSelectedLanguage() {
    #expect(uappLocalized("language.menu", languageIdentifier: "pt-BR") == "Idioma")
    #expect(uappLocalized("language.menu", languageIdentifier: "en") == "Language")
    #expect(uappLocalized("language.menu", languageIdentifier: "ja") == "言語")
}

@Test("locales regionais usam as traduções de conta do idioma correspondente")
@MainActor
func regionalAccountStrings() {
    #expect(uappLocalized("account.name", languageIdentifier: "en_US") == "Name")
    #expect(uappLocalized("account.password", languageIdentifier: "es_MX") == "Contraseña")
    #expect(uappLocalized("user.account", languageIdentifier: "zh_Hant_TW") == "你的帳戶")
}

@Test("idiomas de conta incluem textos de autenticação, perfil e foto", arguments: UAPPLanguage.supported)
func accountTranslations(_ language: UAPPLanguage) {
    let keys = [
        "account.start_title", "account.start_message", "account.welcome", "account.welcome_message",
        "account.create", "account.create_message", "account.confirm_title", "account.confirm_message",
        "account.recover_title", "account.recover_message", "account.recovery_code_title",
        "account.recovery_code_message", "account.new_password_title", "account.new_password_message",
        "account.name", "account.password", "account.password_confirmation", "account.forgot",
        "account.connect", "account.send_recovery", "account.save_password", "account.or",
        "account.back", "account.back_login", "account.resend", "account.login_error",
        "account.operation_error", "account.unsupported", "user.account", "photo.hint", "photo.error",
        "photo.update_error", "photo.uploading"
    ]
    for key in keys {
        #expect(uappLocalized(key, languageIdentifier: language.identifier) != key)
    }
    if language.identifier != "pt-BR" {
        #expect(uappLocalized("account.start_title", languageIdentifier: language.identifier) != "Bem-vindo")
    }
    let hint = uappLocalized("account.password_hint", languageIdentifier: language.identifier)
    #expect(hint.contains("%d"))
    #expect(String(format: hint, 8).contains("8"))
}

@Test("idioma do hospedeiro e idioma da tela apresentada são independentes")
@MainActor
func hostAndPresentationLanguagesAreIndependent() {
    let defaults = UserDefaults.standard
    let hostKey = UAPPLocalizationPreferences.storageKey
    let presentationKey = UAPPLocalizationPreferences.presentationStorageKey
    let previousHost = defaults.object(forKey: hostKey)
    let previousPresentation = defaults.object(forKey: presentationKey)
    defer {
        if let previousHost {
            defaults.set(previousHost, forKey: hostKey)
        } else {
            defaults.removeObject(forKey: hostKey)
        }
        if let previousPresentation {
            defaults.set(previousPresentation, forKey: presentationKey)
        } else {
            defaults.removeObject(forKey: presentationKey)
        }
    }

    defaults.set("en", forKey: hostKey)
    _ = UAPPLocalizationPreferences.preparePresentation(initialIdentifier: "en")
    _ = UAPPLocalizationPreferences.selectPresentation(identifier: "pt-BR")

    #expect(defaults.string(forKey: hostKey) == "en")
    #expect(defaults.string(forKey: presentationKey) == "pt-BR")
}

@Test("nome de exibição combina bandeira e nome localizado; idioma desconhecido usa globo")
func languageDisplayName() {
    let portuguese = UAPPLanguage.supported[0]
    #expect(portuguese.displayName(in: Locale(identifier: "en")) == "🇧🇷 Portuguese")
    let unknown = UAPPLanguage(identifier: "xx", nativeName: "Desconhecido")
    #expect(unknown.flagEmoji == "🌐")
    #expect(unknown.displayName(in: Locale(identifier: "en")).hasPrefix("🌐 "))
}

/// Preserva e restaura as preferências de idioma tocadas pelo teste.
@MainActor
private func withLanguagePreferences(_ body: (UserDefaults) -> Void) {
    let defaults = UserDefaults.standard
    let keys = [UAPPLocalizationPreferences.storageKey, UAPPLocalizationPreferences.presentationStorageKey]
    let previous = keys.map { defaults.object(forKey: $0) }
    defer {
        for (key, value) in zip(keys, previous) {
            if let value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
    body(defaults)
}

@Test("preferência do hospedeiro normaliza valor salvo, aceita inicial e usa padrão")
@MainActor
func hostPreferenceIsNormalized() {
    withLanguagePreferences { defaults in
        let key = UAPPLocalizationPreferences.storageKey
        #expect(UAPPLocalizationPreferences.ensureStored(initialIdentifier: "es_MX") == "es")
        #expect(defaults.string(forKey: key) == "es")
        defaults.set("en_US", forKey: key)
        #expect(UAPPLocalizationPreferences.ensureStored() == "en")
        #expect(defaults.string(forKey: key) == "en")
        #expect(UAPPLocalizationPreferences.ensureStored() == "en")
        defaults.set("xx", forKey: key)
        #expect(UAPPLocalizationPreferences.ensureStored(initialIdentifier: "xx") == UAPPLocalizationPreferences.defaultIdentifier)
        defaults.removeObject(forKey: key)
        #expect(UAPPLocalizationPreferences.hostIdentifier == UAPPLocalizationPreferences.defaultIdentifier)
        #expect(UAPPLocalizationPreferences.select(identifier: "xx") == UAPPLocalizationPreferences.fallbackIdentifier)
        #expect(UAPPLocalizationPreferences.matchingIdentifier(for: "") == nil)
        #expect(UAPPLocalizationPreferences.matchingIdentifier(for: "fr_CA") == "fr")
    }
}

@Test("lista e menu de idiomas constroem as opções")
@MainActor
func languageOptionsRender() async {
    await render(UAPPLanguageOptions(accentColor: .purple, isPresented: .constant(true)))
    await render(NavigationStack {
        Text("Tela").toolbar { ToolbarItem { UAPPLanguageMenu(accentOverride: .orange) } }
    })
}

private struct OnChangeProbe: View {
    let legacy: Bool
    let action: (Int) -> Void
    @State private var value = 1

    var body: some View {
        Group {
            if legacy {
                Text("Valor").modifier(UAPPOnChangeModifier(value: value, action: action))
            } else {
                Text("Valor").uappOnChange(of: value, perform: action)
            }
        }
        .task {
            await Task.yield()
            value = 2
        }
    }
}

@Test("observador de mudanças ignora o valor inicial e notifica alterações")
@MainActor
func onChangeModifierNotifiesChanges() async {
    for legacy in [true, false] {
        var received: [Int] = []
        await render(OnChangeProbe(legacy: legacy) { received.append($0) }, settling: true)
        #expect(received == [2])
    }
}

@Test("idiomas incluem os textos das janelas, do menu e do recorte de foto do Mac", arguments: UAPPLanguage.supported)
func macTranslations(_ language: UAPPLanguage) {
    let keys = [
        "common.cancel", "common.refresh", "account.no_account", "account.has_account", "feedback.select_prompt", "menu.feedback", "menu.about_app",
        "photo.choose_file", "photo.crop_title", "photo.crop_hint", "photo.zoom", "photo.use"
    ]
    for key in keys {
        #expect(uappLocalized(key, languageIdentifier: language.identifier) != key)
    }
    #expect(uappLocalized("menu.about_app", languageIdentifier: language.identifier).contains("%@"))
}
