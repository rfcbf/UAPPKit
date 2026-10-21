import SwiftUI

struct UAPPAuthenticationScreen: View {
    @ObservedObject var model: UAPPParticipationModel
    let accentColor: Color
    @Environment(\.uappTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    var body: some View {
        Form {
            if let session = model.session {
                Section {
                    HStack {
                        UAPPCachedImage(url: session.identity.avatarURL) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else if session.identity.avatarURL == nil || phase.error != nil {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable().scaledToFit()
                            } else {
                                UAPPImageLoadingPlaceholder()
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                        Text(session.identity.displayName ?? uappLocalized("auth.signed_in"))
                            .font(.headline)
                    }
                    if let email = session.identity.email {
                        Text(email).foregroundStyle(palette.secondaryText)
                    }
                    Button(uappLocalized("auth.signout"), role: .destructive) { Task { await model.signOut() } }
                }
            } else {
                Section {
                    Text(verbatim: uappLocalized("auth.message"))
                        .foregroundStyle(palette.secondaryText)
                    ForEach(model.methods.filter { $0 != .email }) { method in
                        Button {
                            Task { await model.signIn(method) }
                        } label: {
                            HStack(spacing: 12) {
                                UAPPLoginServiceIcon(method: method)
                                    .frame(width: 28, height: 28)
                                    .accessibilityHidden(true)
                                Text(verbatim: uappLocalized("auth.\(method.rawValue)"))
                                    .foregroundStyle(palette.primaryText)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }
                if model.methods.contains(.email) {
                    emailSection
                }
            }
            if model.isBusy {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .disabled(model.isBusy)
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .foregroundStyle(palette.primaryText)
        .uappNavigationBar(titleKey: "auth.title", accentColor: accentColor)
        .interactiveDismissDisabled(model.isBusy)
        .uappToast(message: Binding(
            get: { model.errorKey.map { uappLocalized($0) } },
            set: {
                if $0 == nil {
                    model.dismissError()
                }
            }
        ))
    }

    private var emailSection: some View {
        Section {
            if model.emailCodeSent {
                Text(verbatim: uappLocalized("auth.code_sent"))
                Text(verbatim: model.email)
                    .font(.callout)
                    .foregroundStyle(palette.secondaryText)
                TextField(uappLocalized("auth.code"), text: $model.code)
                    .textContentType(.oneTimeCode)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                Button(uappLocalized("auth.verify")) { Task { await model.verifyEmailCode() } }
                    .disabled(model.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(uappLocalized("auth.change_email")) { model.changeEmail() }
            } else {
                TextField(uappLocalized("auth.email"), text: $model.email)
                    #if os(iOS)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
                Button(uappLocalized("auth.send_code")) { Task { await model.requestEmailCode() } }
                    .disabled(!model.canRequestCode)
            }
        } header: {
            Text(verbatim: uappLocalized("auth.email"))
        }
    }
}

struct UAPPParticipationModifier: ViewModifier {
    @ObservedObject var model: UAPPParticipationModel
    let accentColor: Color
    var enabled = true
    var searchAction: (() -> Void)?
    var searchPromptKey = "common.search"
    @Environment(\.uappTheme) private var theme
    /// No detalhe ao lado da lista (Mac), idioma e conta já estão na barra da lista.
    @Environment(\.uappIsSplitDetail) private var isSplitDetail
    @Environment(\.uappToolbarItemsHidden) private var itemsHidden

    func body(content: Content) -> some View {
        content
            .toolbar {
                if !isSplitDetail, !itemsHidden {
                    ToolbarItemGroup(placement: .primaryAction) {
                        // No Mac a busca já fica visível na barra de ferramentas.
                        #if !os(macOS)
                        if let searchAction {
                            Button(action: searchAction) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(accentColor)
                            }
                            .accessibilityLabel(Text(verbatim: uappLocalized(searchPromptKey)))
                        }
                        #endif
                        UAPPLanguageMenu(accentOverride: accentColor)
                        if enabled, model.isEnabled || model.identity != nil {
                            Button {
                                model.showsAccount = true
                            } label: {
                                accountImage
                            }
                            .accessibilityLabel(Text(verbatim: uappLocalized(model.identity == nil ? "auth.title" : "user.account")))
                            #if os(macOS)
                            .help(Text(verbatim: uappLocalized(model.identity == nil ? "auth.title" : "user.account")))
                            #endif
                        }
                    }
                }
            }
            .sheet(isPresented: $model.showsAccount, onDismiss: {
                Task {
                    await model.refresh()
                    await model.finishPresentation()
                }
            }) {
                if let session = model.session, let authentication = model.client.authentication {
                    UAPPUserScreen(
                        session: session,
                        authentication: authentication,
                        client: model.client,
                        theme: theme
                    )
                } else if let identity = model.identity, !model.isEnabled {
                    UAPPUserScreen(profile: identity, client: model.client, theme: theme)
                } else if let authentication = model.client.authentication {
                    UAPPAccountScreen(
                        authentication: authentication,
                        client: model.client,
                        theme: theme
                    )
                }
            }
            .task {
                if enabled {
                    await model.refresh()
                }
            }
    }

    @ViewBuilder
    private var accountImage: some View {
        if let identity = model.session?.identity ?? model.identity {
            UAPPCachedImage(url: identity.avatarURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable().scaledToFit()
                        .foregroundStyle(Color.uappToolbarIcon(accentColor))
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
            .accessibilityHidden(true)
        } else {
            Image(systemName: "person.badge.plus")
                .foregroundStyle(Color.uappToolbarIcon(accentColor))
                .accessibilityHidden(true)
        }
    }
}
