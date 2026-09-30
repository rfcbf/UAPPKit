import SwiftUI
import UAPPKit

extension ContentView {
    var configurationForm: some View {
        Form {
            configurationSections
        }
        .modifier(DemoFormLayout(isSecondary: false))
    }

    var screensForm: some View {
        Form {
            screensSection()
        }
        .modifier(DemoFormLayout(isSecondary: true))
    }

    @ViewBuilder
    var configurationSections: some View {
        Section {
            DemoLanguageMenu(
                title: localized("demo.language"),
                selection: $languageIdentifier
            )
        } header: {
            Text(verbatim: localized("demo.language.section"))
        } footer: {
            Text(verbatim: localized("demo.language.footer"))
        }

        Section {
            TextField(localized("demo.project_slug"), text: $projectSlug)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.URL)

            TextField(localized("demo.server"), text: $supabaseServer)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
        } header: {
            Text(verbatim: localized("demo.configuration"))
        } footer: {
            Text(verbatim: localized("demo.configuration.footer"))
        }

        Section {
            Button(localized("demo.save_configuration")) {
                _ = saveConfiguration()
            }
            .disabled(!canSave)

            Button {
                testConnection()
            } label: {
                HStack {
                    Text(verbatim: localized("demo.test_connection"))
                    Spacer()
                    if isTestingConnection {
                        ProgressView()
                    }
                }
            }
            .disabled(!canSave || isTestingConnection)
        }

        if let statusMessage {
            Section {
                VStack(spacing: 8) {
                    UAPPMascotIllustration(
                        state: statusIsSuccess ? .success : .connectionError
                    )

                    Label(
                        statusMessage,
                        systemImage: statusIsSuccess
                            ? "checkmark.circle.fill"
                            : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(statusIsSuccess ? .green : .orange)
                }
                .frame(maxWidth: .infinity)
            }
        }

        Section {
            DemoAppearanceControl(
                title: localized("demo.appearance.mode"),
                lightTitle: localized("demo.appearance.light"),
                darkTitle: localized("demo.appearance.dark"),
                selection: $appearance
            )
        } header: {
            Text(verbatim: localized("demo.appearance"))
        }

        Section {
            if appearance == DemoAppearance.dark.rawValue {
                ThemePaletteCard(
                    title: localized("demo.theme.dark.title"),
                    subtitle: localized("demo.theme.dark.subtitle"),
                    languageIdentifier: languageIdentifier,
                    background: $darkBackground,
                    cardBackground: $darkCardBackground,
                    primaryText: $darkPrimaryText,
                    secondaryText: $darkSecondaryText,
                    accent: $darkAccent,
                    buttonText: $darkButtonText,
                    separator: $darkSeparator,
                    onChange: applyConfiguredTheme
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                ThemePaletteCard(
                    title: localized("demo.theme.light.title"),
                    subtitle: localized("demo.theme.light.subtitle"),
                    languageIdentifier: languageIdentifier,
                    background: $lightBackground,
                    cardBackground: $lightCardBackground,
                    primaryText: $lightPrimaryText,
                    secondaryText: $lightSecondaryText,
                    accent: $lightAccent,
                    buttonText: $lightButtonText,
                    separator: $lightSeparator,
                    onChange: applyConfiguredTheme
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        } footer: {
            Text(verbatim: localized("demo.theme.footer"))
        }
        .animation(.easeInOut(duration: 0.2), value: appearance)
    }

    func screensSection() -> some View {
        Section {
            Button {
                present { try UAPPKit.showFeedback() }
            } label: {
                Label {
                    Text(verbatim: localized("demo.open_feedback"))
                } icon: {
                    Image(systemName: "text.bubble")
                }
            }
            Button {
                present { try UAPPKit.showRoadmap() }
            } label: {
                Label {
                    Text(verbatim: localized("demo.open_roadmap"))
                } icon: {
                    Image(systemName: "map")
                }
            }
            Button {
                present {
                    try UAPPKit.showChangelog(configuration: .init(automaticallyScrolls: true,
                                                                   interval: 15,
                                                                   pageSize: 10))
                }
            } label: {
                Label {
                    Text(verbatim: localized("demo.open_changelog"))
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                }
            }
            Button {
                present { try UAPPKit.showReviews(pageSize: 10) }
            } label: {
                Label {
                    Text(verbatim: localized("demo.open_reviews"))
                } icon: {
                    Image(systemName: "star.bubble")
                }
            }
            appStoreReviewButton
            Button {
                present {
                    try UAPPKit.showAbout(configuration: UAPPAboutConfiguration(
                        shortDescription: "Feedback, Roadmap, Sobres e mais para seus aplicativos pessoais",
                        descriptionLanguageIdentifier: "pt-BR",
                        websiteURL: URL(string: "https://uapp-dev.renatoferraz.net"),
                        supportURL: URL(string: "mailto:rfcbf@me.com"),
                        privacyPolicyURL: URL(string: "https://uapp-dev.renatoferraz.net/#/politica-de-privacidade"),
                        termsOfUseURL: URL(string: "https://uapp-dev.renatoferraz.net/#/termos-de-uso"),
                        license: "MIT",
                        showsChangelog: true,
                        showsAppStoreReview: true,
                        changelogConfiguration: .init(automaticallyScrolls: true,
                                                      interval: 15,
                                                      pageSize: 10)
                    ))
                }
            } label: {
                Label {
                    Text(localized("demo.open_about_app"))
                } icon: {
                    Image(systemName: "info.circle")
                }
            }
            Button {
                present { try UAPPKit.showDeveloperAbout() }
            } label: {
                Label {
                    Text(localized("demo.open_about_dev"))
                } icon: {
                    Image(systemName: "person.circle")
                }
            }
        } header: {
            Text(verbatim: localized("demo.screens"))
        }
        .headerProminence(.increased)
    }

    private var appStoreReviewButton: some View {
        Button {
            guard !isOpeningAppStoreReview else { return }
            isOpeningAppStoreReview = true
            Task {
                defer { isOpeningAppStoreReview = false }
                do {
                    try await UAPPKit.openAppStoreReview()
                } catch {
                    appStoreReviewError = "\(error.localizedDescription)\n\nProjeto: \(projectSlug)\nServidor: \(normalizedServer)"
                }
            }
        } label: {
            Label {
                Text(verbatim: localized("demo.open_app_store_review"))
            } icon: {
                if isOpeningAppStoreReview {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "star")
                }
            }
        }
        .disabled(isOpeningAppStoreReview)
    }

    var canSave: Bool {
        !projectSlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && URL(string: normalizedServer) != nil
    }

    var normalizedServer: String {
        supabaseServer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
