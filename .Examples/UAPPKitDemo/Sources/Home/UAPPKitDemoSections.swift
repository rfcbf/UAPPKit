import SwiftUI
import UAPPKit

extension ContentView {
    /// No modo Sistema, edita a paleta que o aparelho está exibindo.
    var isEditingDarkPalette: Bool {
        switch DemoAppearance(rawValue: appearance) ?? .light {
        case .system: systemColorScheme == .dark
        case .light: false
        case .dark: true
        }
    }

    var homeForm: some View {
        Form {
            homeSections
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
    var homeSections: some View {
        Section {
            if let session = account.session {
                Button {
                    accountDestination = .user
                } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.identity.displayName.map { UAPPDisplayName.abbreviated($0) } ?? session.identity.email
                             ?? account.text("Sua conta", "Your account", languageIdentifier))
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                            .accessibilityLabel(Text(session.identity.displayName ?? session.identity.email
                                ?? account.text("Sua conta", "Your account", languageIdentifier)))
                        if let email = session.identity.email, email != session.identity.displayName {
                            Text(email).font(.subheadline).foregroundStyle(Color.primary)
                        }
                    }
                } icon: {
                    if let avatarURL = session.identity.avatarURL {
                        UAPPCachedImage(url: avatarURL) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else if phase.error != nil {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .resizable().scaledToFit()
                            } else {
                                UAPPImageLoadingPlaceholder()
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                    } else {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                    }
                }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.primary)
                .disabled(account.isSigningOut)
            } else {
                if account.hasProfile, let identity = account.identity {
                    Button {
                        account.error = nil
                        accountDestination = .profile
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(identity.displayName.map { UAPPDisplayName.abbreviated($0) }
                                     ?? account.text("Seu perfil", "Your profile", languageIdentifier))
                                    .font(.headline)
                                    .accessibilityLabel(Text(identity.displayName
                                        ?? account.text("Seu perfil", "Your profile", languageIdentifier)))
                                if let email = identity.email, !email.isEmpty {
                                    Text(email).font(.subheadline)
                                }
                                Text(account.text("Perfil local · sem login", "Local profile · without sign-in", languageIdentifier))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "person.crop.circle")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.primary)
                }
                Button {
                    guard saveConfiguration(showSuccessMessage: false) else { return }
                    account.error = nil
                    accountDestination = .connect
                } label: {
                    Label(account.text("Conectar", "Connect", languageIdentifier), systemImage: "person.badge.key")
                }
            }
            if let error = account.error {
                Text(error).font(.footnote).foregroundStyle(.secondary)
            }
            if account.session == nil, !account.hasProfile {
                Button {
                    account.error = nil
                    accountDestination = .profile
                } label: {
                    Label(account.text("Preencher perfil", "Fill in profile", languageIdentifier), systemImage: "person.crop.circle")
                }
            }
        } header: {
            Text(account.text("Seu perfil", "Your profile", languageIdentifier))
        } footer: {
            if account.session != nil {
                Text(account.text(
                    "Para testar com um perfil preenchido manualmente, toque na sua conta e desconecte primeiro.",
                    "To test with a manually filled profile, tap your account and sign out first.",
                    languageIdentifier
                ))
            } else if account.hasProfile {
                Text(account.text(
                    "Você está usando um perfil local salvo neste aparelho. Toque no perfil para editar ou conecte uma conta para autenticar sua participação.",
                    "You are using a local profile saved on this device. Tap your profile to edit it or connect an account to authenticate your participation.",
                    languageIdentifier
                ))
            } else {
                Text(account.text(
                    "Conecte uma conta ou preencha um perfil sem login.",
                    "Connect an account or fill in a profile without signing in.",
                    languageIdentifier
                ))
            }
        }
        Section {
            NavigationLink {
                configurationScreen
            } label: {
                Label(localized("demo.configuration"), systemImage: "gearshape")
            }
        } header: {
            Text(verbatim: localized("demo.configuration"))
        }
    }

    var configurationScreen: some View {
        Form {
            settingsSections
        }
        .modifier(DemoFormLayout(isSecondary: false))
        .navigationTitle(localized("demo.configuration"))
        .navigationBarTitleDisplayMode(.inline)
        .modifier(PersistentNavigationBar())
    }

    @ViewBuilder
    var settingsSections: some View {
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
            DemoAppearanceControl(
                title: localized("demo.appearance.mode"),
                systemTitle: localized("demo.appearance.system"),
                lightTitle: localized("demo.appearance.light"),
                darkTitle: localized("demo.appearance.dark"),
                selection: $appearance
            )
        } header: {
            Text(verbatim: localized("demo.appearance"))
        }

        Section {
            if isEditingDarkPalette {
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
        .animation(.easeInOut(duration: 0.2), value: isEditingDarkPalette)

        Section {
            HStack(spacing: 12) {
                Button {
                    _ = saveConfiguration()
                } label: {
                    Text(verbatim: localized("demo.save_configuration"))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(!canSave || isTestingConnection)

                Button {
                    testConnection()
                } label: {
                    HStack(spacing: 8) {
                        if isTestingConnection { ProgressView() }
                        Text(verbatim: localized("demo.test_connection"))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(!canSave || isTestingConnection)
            }
            .multilineTextAlignment(.center)
            .buttonStyle(.borderedProminent)
        }

    }

    var configurationStatusSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    UAPPMascotIllustration(
                        state: statusIsSuccess ? .success : .connectionError
                    )
                    if let statusMessage {
                        Label(
                            statusMessage,
                            systemImage: statusIsSuccess
                                ? "checkmark.circle.fill"
                                : "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(statusIsSuccess ? .green : .orange)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.updatesFrequently)
                    }
                }
                .padding(24)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { isShowingStatus = false } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text(account.text("Fechar", "Close", languageIdentifier)))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    func screensSection() -> some View {
        Section {
            Button {
                openFeedback()
            } label: {
                Label {
                    Text(verbatim: localized("demo.open_feedback"))
                } icon: {
                    Image(systemName: "text.bubble")
                }
            }
            Button {
                openRoadmap()
            } label: {
                Label {
                    Text(verbatim: localized("demo.open_roadmap"))
                } icon: {
                    Image(systemName: "map")
                }
            }
            Button {
                present {
                    try UAPPKit.showChangelog(configuration: .init(
                        automaticallyScrolls: true,
                        interval: 15,
                        pageSize: 10
                    ))
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
                    try UAPPKit.showAbout(configuration: DemoMockData.aboutConfiguration ?? UAPPAboutConfiguration(
                        shortDescription: "Feedback, Roadmap, Sobres e mais para seus aplicativos pessoais",
                        descriptionLanguageIdentifier: "pt-BR",
                        websiteURL: URL(string: "https://uapp-dev.renatoferraz.net"),
                        supportURL: URL(string: "mailto:rfcbf@me.com"),
                        privacyPolicyURL: URL(string: "https://uapp-dev.renatoferraz.net/#/politica-de-privacidade"),
                        termsOfUseURL: URL(string: "https://uapp-dev.renatoferraz.net/#/termos-de-uso"),
                        license: "MIT",
                        showsChangelog: true,
                        showsAppStoreReview: true,
                        changelogConfiguration: .init(
                            automaticallyScrolls: true,
                            interval: 15,
                            pageSize: 10
                        ),
                        showsReviews: true,
                        reviewsPageSize: 20
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
