import SwiftUI
import UAPPKit
import UIKit

extension ContentView {
    @MainActor
    func applyAppearance() {
        let style: UIUserInterfaceStyle = switch DemoAppearance(rawValue: appearance) ?? .light {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for window in scenes.flatMap(\.windows) {
            window.overrideUserInterfaceStyle = style
        }
    }

    var configuredTheme: UAPPTheme {
        UAPPTheme(
            light: UAPPTheme.Palette(
                background: DemoHexColor.color(from: lightBackground),
                cardBackground: DemoHexColor.color(from: lightCardBackground),
                primaryText: DemoHexColor.color(from: lightPrimaryText),
                secondaryText: DemoHexColor.color(from: lightSecondaryText),
                accent: DemoHexColor.color(from: lightAccent),
                separator: DemoHexColor.color(from: lightSeparator),
                buttonText: DemoHexColor.color(from: lightButtonText)
            ),
            dark: UAPPTheme.Palette(
                background: DemoHexColor.color(from: darkBackground),
                cardBackground: DemoHexColor.color(from: darkCardBackground),
                primaryText: DemoHexColor.color(from: darkPrimaryText),
                secondaryText: DemoHexColor.color(from: darkSecondaryText),
                accent: DemoHexColor.color(from: darkAccent),
                separator: DemoHexColor.color(from: darkSeparator),
                buttonText: DemoHexColor.color(from: darkButtonText)
            )
        )
    }

    @MainActor
    func applyConfiguredTheme() {
        let slug = projectSlug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !slug.isEmpty,
            let server = URL(string: normalizedServer),
            server.scheme != nil,
            server.host != nil
        else { return }

        UAPPKit.setup(projectId: slug, host: server, theme: configuredTheme)
    }
}
