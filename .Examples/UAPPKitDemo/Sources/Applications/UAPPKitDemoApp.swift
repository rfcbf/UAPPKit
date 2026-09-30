import Foundation
import SwiftUI
import UAPPKit

enum DemoSettings {
    static let defaultLanguage = "pt-BR"
    static let projectSlug = "calcjuros-dev"
    static let supabaseServer = "UAPPKitDemo.supabaseServer"
    static let legacySupabaseServer = "https://zmmdvtykqbpwkwddjeyb.supabase.co"
    static let defaultProjectSlug = "calcjuros-dev"
    static let defaultSupabaseServer = "https://zmmdvtykqbpwkwddjeyb.supabase.co"
    static let appearance = "UAPPKitDemo.appearance"
    static let lightBackgroundDefault = "#F8F9F8"
    static let lightCardBackgroundDefault = "#FFFFFF"
    static let lightPrimaryTextDefault = "#0F1A0E"
    static let lightSecondaryTextDefault = "#6F776F"
    static let lightAccentDefault = "#356C30"
    static let lightButtonTextDefault = "#FFFFFF"
    static let lightBackground = "UAPPKitDemo.theme.light.background"
    static let lightCardBackground = "UAPPKitDemo.theme.light.cardBackground"
    static let lightPrimaryText = "UAPPKitDemo.theme.light.primaryText"
    static let lightSecondaryText = "UAPPKitDemo.theme.light.secondaryText"
    static let lightAccent = "UAPPKitDemo.theme.light.accent"
    static let lightButtonText = "UAPPKitDemo.theme.light.buttonText"
    static let lightSeparator = "UAPPKitDemo.theme.light.separator"
    static let darkBackgroundDefault = "#08130A"
    static let darkCardBackgroundDefault = "#1A1F1B"
    static let darkPrimaryTextDefault = "#FFFFFF"
    static let darkSecondaryTextDefault = "#B8B8B8"
    static let darkAccentDefault = "#8BD08C"
    static let darkButtonTextDefault = "#08130A"
    static let darkBackground = "UAPPKitDemo.theme.dark.background"
    static let darkCardBackground = "UAPPKitDemo.theme.dark.cardBackground"
    static let darkPrimaryText = "UAPPKitDemo.theme.dark.primaryText"
    static let darkSecondaryText = "UAPPKitDemo.theme.dark.secondaryText"
    static let darkAccent = "UAPPKitDemo.theme.dark.accent"
    static let darkButtonText = "UAPPKitDemo.theme.dark.buttonText"
    static let darkSeparator = "UAPPKitDemo.theme.dark.separator"
}

enum DemoAppearance: String {
    case light
    case dark

    var colorScheme: ColorScheme {
        self == .dark ? .dark : .light
    }
}

@main
struct UAPPKitDemoApp: App {
    init() {
        let defaults = UserDefaults.standard
        let languageIdentifier = defaults.string(forKey: UAPPKit.localePreferenceKey)
            ?? DemoSettings.defaultLanguage
        let slug = defaults.string(forKey: DemoSettings.projectSlug)
            ?? DemoSettings.defaultProjectSlug
        let savedServer = defaults.string(forKey: DemoSettings.supabaseServer)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let legacyServer = defaults.string(forKey: DemoSettings.legacySupabaseServer)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let serverString = savedServer.flatMap { $0.isEmpty ? nil : $0 }
            ?? legacyServer.flatMap { $0.isEmpty ? nil : $0 }
            ?? DemoSettings.defaultSupabaseServer
        if savedServer == nil || savedServer?.isEmpty == true {
            defaults.set(serverString, forKey: DemoSettings.supabaseServer)
        }
        let server = URL(string: serverString)
            ?? URL(string: DemoSettings.defaultSupabaseServer)
            ?? UAPPConfiguration.defaultHost

        UAPPKit.setup(
            projectId: slug,
            host: server,
            locale: Locale(identifier: languageIdentifier)
        )
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if CommandLine.arguments.contains("--changelog-preview") {
                NavigationStack {
                    UAPPFeedbackScreen(
                        client: DemoCanvasPreview.client,
                        mode: .changelog,
                        changelogConfiguration: .init(automaticallyScrolls: true, interval: 5, pageSize: 10)
                    )
                }
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
    }
}
