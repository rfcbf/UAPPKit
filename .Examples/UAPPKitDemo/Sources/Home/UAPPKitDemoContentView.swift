import SwiftUI
import UAPPKit
import UIKit

struct ContentView: View {
    @AppStorage(UAPPKit.localePreferenceKey)
    var languageIdentifier = DemoSettings.defaultLanguage
    @AppStorage(DemoSettings.projectSlug)
    var projectSlug = DemoSettings.defaultProjectSlug
    @AppStorage(DemoSettings.supabaseServer)
    var supabaseServer = DemoSettings.defaultSupabaseServer
    @AppStorage(DemoSettings.appearance)
    var appearance = DemoAppearance.light.rawValue
    @AppStorage(DemoSettings.lightBackground)
    var lightBackground = DemoSettings.lightBackgroundDefault
    @AppStorage(DemoSettings.lightCardBackground)
    var lightCardBackground = DemoSettings.lightCardBackgroundDefault
    @AppStorage(DemoSettings.lightPrimaryText)
    var lightPrimaryText = DemoSettings.lightPrimaryTextDefault
    @AppStorage(DemoSettings.lightSecondaryText)
    var lightSecondaryText = DemoSettings.lightSecondaryTextDefault
    @AppStorage(DemoSettings.lightAccent)
    var lightAccent = DemoSettings.lightAccentDefault
    @AppStorage(DemoSettings.lightButtonText)
    var lightButtonText = DemoSettings.lightButtonTextDefault
    @AppStorage(DemoSettings.lightSeparator) var lightSeparator = ""
    @AppStorage(DemoSettings.darkBackground)
    var darkBackground = DemoSettings.darkBackgroundDefault
    @AppStorage(DemoSettings.darkCardBackground)
    var darkCardBackground = DemoSettings.darkCardBackgroundDefault
    @AppStorage(DemoSettings.darkPrimaryText)
    var darkPrimaryText = DemoSettings.darkPrimaryTextDefault
    @AppStorage(DemoSettings.darkSecondaryText)
    var darkSecondaryText = DemoSettings.darkSecondaryTextDefault
    @AppStorage(DemoSettings.darkAccent)
    var darkAccent = DemoSettings.darkAccentDefault
    @AppStorage(DemoSettings.darkButtonText)
    var darkButtonText = DemoSettings.darkButtonTextDefault
    @AppStorage(DemoSettings.darkSeparator) var darkSeparator = ""

    @State var statusMessage: String?
    @State var statusIsSuccess = false
    @State var isTestingConnection = false
    @State var isOpeningAppStoreReview = false
    @State var appStoreReviewError: String?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                if shouldShowTwoPanels(in: proxy) {
                    twoPanelContent
                } else {
                    singleColumnContent
                }
            }
            .navigationTitle(localized("demo.title"))
            .navigationBarTitleDisplayMode(.inline)
            .modifier(PersistentNavigationBar())
        }
        .environment(\.locale, Locale(identifier: languageIdentifier))
        .preferredColorScheme(
            DemoAppearance(rawValue: appearance)?.colorScheme ?? .light
        )
        .onAppear {
            applyAppearance()
            applyConfiguredTheme()
        }
        .uappOnChange(of: appearance) { _ in applyAppearance() }
        .uappOnChange(of: languageIdentifier) { newValue in
            UAPPKit.setLocale(Locale(identifier: newValue))
        }
        .alert(
            Text(verbatim: localized("demo.open_app_store_review")),
            isPresented: Binding(
                get: { appStoreReviewError != nil },
                set: { isPresented in
                    if !isPresented {
                        appStoreReviewError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) { appStoreReviewError = nil }
        } message: {
            Text(verbatim: appStoreReviewError ?? "")
        }
    }

    private var singleColumnContent: some View {
        Form {
            configurationSections
            screensSection()
        }
        .modifier(DemoFormLayout(isSecondary: false))
    }

    private func shouldShowTwoPanels(in proxy: GeometryProxy) -> Bool {
        guard horizontalSizeClass == .regular,
              proxy.size.width > proxy.size.height
        else { return false }

        if #available(iOS 27.1, *) {
            let division = proxy
                .reservedRegions(kind: .division, options: .includeInactive)
                .first { region in
                    region.frame.minX > 0
                        && region.frame.maxX < proxy.size.width
                        && region.frame.width < proxy.size.width * 0.4
                }
            let leftWidth = division?.frame.minX ?? proxy.size.width / 2
            let rightWidth = division.map { proxy.size.width - $0.frame.maxX }
                ?? proxy.size.width / 2
            return min(leftWidth, rightWidth) >= 280
        }

        return proxy.size.width >= 640
    }

    @ViewBuilder
    private var twoPanelContent: some View {
        if #available(iOS 27.1, *) {
            ArrangementView {
                configurationForm
            } secondary: {
                screensForm
            }
            .arrangementViewStyle(.split.axes(.horizontal))
        } else {
            HStack(spacing: 0) {
                configurationForm
                    .frame(maxWidth: .infinity)
                Divider()
                screensForm
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview("ContentView · Configuração") {
    ContentView()
        .preferredColorScheme(.light)
}
