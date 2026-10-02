import Foundation
import Testing
@testable import UAPPKit

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
        "account.operation_error", "account.unsupported", "user.account", "photo.hint", "photo.error"
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
