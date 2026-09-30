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
