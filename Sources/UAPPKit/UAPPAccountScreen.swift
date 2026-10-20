import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Autenticação reutilizável: login, cadastro, confirmação de e-mail e recuperação de senha.
/// Pode ser apresentada em uma sheet ou diretamente na navegação do aplicativo.
@MainActor
public struct UAPPAccountScreen: View {
    @StateObject private var model: UAPPAccountModel
    /// Fecha a sheet ou, quando é a raiz de uma janela do Mac aberta pelo pacote, a janela.
    private var dismiss = UAPPScreenCloser()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.hostIdentifier
    @FocusState private var focusedField: Field?
    @State private var visiblePasswordFields: Set<Field> = []
    @State private var remoteIconURL: URL?
    @State private var loadedIcon: Image?
    @State private var isReady = false
    @State private var path: [UAPPAccountModel.Step] = []
    #if os(macOS)
    /// No Mac a conta abre direto no login, sem a tela de boas-vindas; login e cadastro se
    /// alternam na raiz pelo link do rodapé, sem botão de voltar.
    @State private var rootStep: UAPPAccountModel.Step = .login
    #endif
    @State private var discoveredAppName: String?
    private let client: UAPPClient?
    private let appName: String
    private let appIconURL: URL?
    private let theme: UAPPTheme
    private let showsCloseButton: Bool
    private let termsURL: URL?
    private let privacyURL: URL?
    private let onReady: @MainActor () -> Void

    private enum Field: Hashable { case name, email, password, confirmation, code }

    private func keyboardFields(for step: UAPPAccountModel.Step) -> [Field] {
        guard !model.isCompletingSignup else { return [] }
        switch step {
        case .login: return [.email, .password]
        case .signup: return [.name, .email, .password, .confirmation]
        case .recover: return [.email]
        case .confirmSignup, .verifyRecovery: return [.code]
        case .newPassword: return [.password, .confirmation]
        }
    }

    /// - Parameters:
    ///   - showsCloseButton: Whether the account flow offers an action to dismiss the screen.
    ///   - onReady: Called once, when the sign-in form is on screen. It is not called when a session
    ///     already exists, because the screen dismisses itself instead of showing the form.
    public init(
        authentication: any UAPPAuthenticationProvider,
        client: UAPPClient? = nil,
        appName: String = UAPPAppMetadata().name,
        appIconURL: URL? = nil,
        theme: UAPPTheme = .system,
        showsCloseButton: Bool = true,
        minimumPasswordLength: Int = 8,
        termsURL: URL? = nil,
        privacyURL: URL? = nil,
        onSessionChange: @escaping @MainActor (UAPPAuthenticationSession?) -> Void = { _ in },
        onReady: @escaping @MainActor () -> Void = {}
    ) {
        _model = StateObject(wrappedValue: UAPPAccountModel(
            provider: authentication, minimumPasswordLength: minimumPasswordLength,
            onSessionChange: onSessionChange
        ))
        self.client = client
        self.appName = appName
        self.appIconURL = appIconURL
        self.theme = theme
        self.showsCloseButton = showsCloseButton
        self.termsURL = termsURL
        self.privacyURL = privacyURL
        self.onReady = onReady
    }

    /// Estado inicial injetável para renderizar cada etapa nos testes.
    init(
        model: UAPPAccountModel,
        appName: String,
        theme: UAPPTheme = .system,
        termsURL: URL? = nil,
        privacyURL: URL? = nil,
        testingPath: [UAPPAccountModel.Step]
    ) {
        _model = StateObject(wrappedValue: model)
        _path = State(initialValue: testingPath)
        _isReady = State(initialValue: true)
        client = nil
        self.appName = appName
        appIconURL = nil
        self.theme = theme
        showsCloseButton = true
        self.termsURL = termsURL
        self.privacyURL = privacyURL
        onReady = {}
    }

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    private var accentColor: Color {
        palette.accent ?? .accentColor
    }

    private func titleKey(for step: UAPPAccountModel.Step) -> String {
        if model.isCompletingSignup {
            return "photo.avatar"
        }
        switch step {
        case .login: return "account.welcome"
        case .signup: return "account.create"
        case .confirmSignup: return "account.confirm_title"
        case .recover: return "account.recover_title"
        case .verifyRecovery: return "account.recovery_code_title"
        case .newPassword: return "account.new_password_title"
        }
    }

    private func subtitleKey(for step: UAPPAccountModel.Step) -> String {
        if model.isCompletingSignup {
            return "photo.upload_hint"
        }
        switch step {
        case .login: return "account.welcome_message"
        case .signup: return "account.create_message"
        case .confirmSignup: return "account.confirm_message"
        case .recover: return "account.recover_message"
        case .verifyRecovery: return "account.recovery_code_message"
        case .newPassword: return "account.new_password_message"
        }
    }

    public var body: some View {
        screenBody.uappTextSizeLimit()
    }

    private var screenBody: some View {
        NavigationStack(path: $path) {
            Group {
                if isReady {
                    #if os(macOS)
                    page(isWelcome: false, step: rootStep, isRoot: true)
                    #else
                    page(isWelcome: true)
                    #endif
                } else {
                    ProgressView()
                        .tint(accentColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(palette.background.ignoresSafeArea())
                        .uappNavigationBar(verbatimTitle: "", accentColor: accentColor, onClose: {
                            guard !model.isBusy else { return }
                            dismiss()
                        })
                }
            }
            .navigationDestination(for: UAPPAccountModel.Step.self) { step in
                page(isWelcome: false, step: step)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        if Self.showsBackButton, !model.isBusy, step != .newPassword, !model.isCompletingSignup {
                            ToolbarItem(placement: .navigation) {
                                Button {
                                    guard !path.isEmpty else { return }
                                    path.removeLast()
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .foregroundStyle(accentColor)
                                }
                                .accessibilityLabel(Text(verbatim: localized("account.back")))
                            }
                        }
                    }
            }
        }
        .tint(accentColor)
        .interactiveDismissDisabled(model.isBusy)
        .environment(\.uappTheme, theme)
        .uappToast(
            message: Binding(
                get: { (model.errorKey ?? model.noticeKey).map { localized($0) } },
                set: {
                    if $0 == nil {
                        model.dismissStatusMessages()
                    }
                }
            ),
            kind: model.errorKey != nil ? .error : (model.noticeKey == "account.password_updated" ? .success : .information)
        )
        .task {
            guard !isReady else { return }
            selectedLanguage = UAPPLocalizationPreferences.preparePresentation(initialIdentifier: locale.identifier)
            await model.refresh()
            if model.session != nil {
                dismiss(); return
            }
            await loadAppIdentity()
            await loadAppIcon()
            guard !Task.isCancelled else { return }
            isReady = true
            onReady()
        }
        .uappOnChange(of: model.session != nil) { connected in
            if connected {
                dismiss()
            }
        }
        .uappOnChange(of: model.step) { step in
            visiblePasswordFields.removeAll()
            #if os(macOS)
            // Na raiz, login e cadastro só trocam de lugar; as demais etapas são empilhadas.
            guard path.last != step, !(path.isEmpty && (step == .login || step == .signup)) else { return }
            #else
            guard !path.isEmpty, path.last != step else { return }
            #endif
            path.append(step)
        }
        .uappOnChange(of: path) { routes in
            #if os(macOS)
            let step = routes.last ?? rootStep
            #else
            let step = routes.last ?? .login
            #endif
            if model.step != step {
                model.navigate(to: step)
            }
            focusedField = nil
        }
        .onDisappear { Task { await model.cancelRecovery() } }
        .uappMacSheetFrame(width: 480, height: 940, minHeight: 600)
        .background { dismiss.windowReader }
    }
}

extension UAPPAccountScreen {
    /// Tela mais larga que alta, medida com as margens do sistema. O teclado entra como margem
    /// inferior: somando as margens, abrir o teclado não muda a resposta. Sem isso, em retrato a
    /// área visível encolhia, a tela passava a "paisagem", dividia-se em duas e o campo perdia o foco.
    nonisolated static func isLandscape(size: CGSize, safeArea: EdgeInsets) -> Bool {
        let width = size.width + safeArea.leading + safeArea.trailing
        let height = size.height + safeArea.top + safeArea.bottom
        return width > height
    }
}

private extension UAPPAccountScreen {
    func page(isWelcome: Bool, step: UAPPAccountModel.Step = .login, isRoot: Bool = false) -> some View {
        GeometryReader { geometry in
            Group {
                if usesTwoColumnLayout(
                    isLandscape: Self.isLandscape(size: geometry.size, safeArea: geometry.safeAreaInsets),
                    isWelcome: isWelcome,
                    step: step
                ) {
                    #if os(iOS) && compiler(>=6.4)
                    if #available(iOS 27.1, *) {
                        ArrangementView {
                            identityPanel(for: step)
                        } secondary: {
                            authenticationPanel(for: step)
                        }
                        .arrangementViewStyle(.split.axes(.horizontal))
                    } else {
                        splitFallback(for: step)
                    }
                    #else
                    splitFallback(for: step)
                    #endif
                } else {
                    singleColumnContent(height: geometry.size.height, isWelcome: isWelcome, step: step, isRoot: isRoot)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isWelcome {
                welcomeContent
                    .frame(maxWidth: 440)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
                    .background(palette.background)
            }
        }
        .background(palette.background.ignoresSafeArea())
        .foregroundStyle(palette.primaryText)
        .uappKeyboardFieldNavigation(
            focusedField: $focusedField,
            fields: isWelcome ? [] : keyboardFields(for: step),
            accentColor: accentColor
        )
        .uappNavigationBar(
            verbatimTitle: "",
            accentColor: accentColor,
            showsCloseButton: showsCloseButton &&
                (isWelcome || isRoot || (step != .login && step != .signup && step != .recover)),
            onClose: {
                guard !model.isBusy else { return }
                dismiss()
            }
        )
    }

    private func usesTwoColumnLayout(
        isLandscape: Bool,
        isWelcome: Bool,
        step: UAPPAccountModel.Step
    ) -> Bool {
        #if os(iOS)
        horizontalSizeClass == .regular && isLandscape &&
            !isWelcome && (step == .login || step == .signup)
        #else
        false
        #endif
    }

    /// No Mac a janela é mais alta que o login: o formulário fica centralizado, sem vão embaixo.
    private func centersVertically(isWelcome: Bool) -> Bool {
        #if os(macOS)
        true
        #else
        isWelcome || horizontalSizeClass == .regular
        #endif
    }

    private func singleColumnContent(
        height: CGFloat,
        isWelcome: Bool,
        step: UAPPAccountModel.Step,
        isRoot: Bool = false
    ) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                identityHeader(isWelcome: isWelcome, step: step)
                if !isWelcome {
                    authenticationContent(for: step)
                }
                #if os(macOS)
                if isRoot, !model.isCompletingSignup, model.methods.contains(.email) {
                    accountSwitchFooter(for: step)
                }
                #endif
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
            // Em tela larga (iPad e iPhone Duo aberto em retrato) o formulário fica centralizado;
            // no iPhone ele começa no topo, perto do título.
            .frame(minHeight: centersVertically(isWelcome: isWelcome) ? height : 0, alignment: .center)
        }
    }

    private func identityPanel(for step: UAPPAccountModel.Step) -> some View {
        identityHeader(isWelcome: false, step: step)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background)
    }

    private func authenticationPanel(for step: UAPPAccountModel.Step) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    authenticationContent(for: step)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height, alignment: .center)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }

    private func splitFallback(for step: UAPPAccountModel.Step) -> some View {
        HStack(spacing: 0) {
            identityPanel(for: step)
            authenticationPanel(for: step)
        }
        .background(palette.background)
    }

    var welcomeContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { welcomeButtons }
            VStack(spacing: 12) { welcomeButtons }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var welcomeButtons: some View {
        Button {
            open(.login)
        } label: {
            UAPPPrimaryButtonLabel(
                title: localized("account.connect"),
                systemImage: "person.crop.circle",
                accent: accentColor,
                palette: palette
            )
        }
        Button {
            open(.signup)
        } label: {
            UAPPSecondaryButtonLabel(
                title: localized("account.create"),
                systemImage: "person.badge.plus",
                accent: accentColor
            )
        }
    }

    /// No Mac as etapas não têm seta de voltar: o link do rodapé leva ao login.
    static var showsBackButton: Bool {
        #if os(macOS)
        false
        #else
        true
        #endif
    }

    #if os(macOS)
    /// Rodapé do login e do cadastro no Mac: leva de um para o outro na mesma tela.
    func accountSwitchFooter(for step: UAPPAccountModel.Step) -> some View {
        let isLogin = step != .signup
        return HStack(spacing: 4) {
            Text(verbatim: localized(isLogin ? "account.no_account" : "account.has_account"))
                .foregroundStyle(palette.secondaryText)
            Button(localized(isLogin ? "account.create" : "account.connect")) {
                switchRoot(to: isLogin ? .signup : .login)
            }
            .buttonStyle(.link)
            .disabled(model.isBusy)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
    }

    func switchRoot(to step: UAPPAccountModel.Step) {
        guard !model.isBusy else { return }
        focusedField = nil
        rootStep = step
        model.navigate(to: step)
    }
    #endif

    func open(_ step: UAPPAccountModel.Step) {
        guard !model.isBusy else { return }
        focusedField = nil
        model.navigate(to: step)
        path.append(step)
    }

    func identityHeader(isWelcome: Bool, step: UAPPAccountModel.Step) -> some View {
        VStack(spacing: 12) {
            if !isWelcome, !model.isCompletingSignup, let symbol = stepSymbol(for: step) {
                UAPPAccentIconBadge(
                    systemImage: symbol,
                    accent: accentColor,
                    size: 72,
                    cornerRadius: 20,
                    font: .title.weight(.semibold)
                )
                .id(step)
                .uappMotionTransition(.scale(scale: 0.85).combined(with: .opacity))
            } else {
                Group {
                    if let loadedIcon {
                        loadedIcon.resizable().scaledToFill()
                    } else {
                        UAPPApplicationIcon(palette: palette, remoteURL: nil)
                    }
                }
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                .accessibilityLabel(Text(verbatim: discoveredAppName ?? appName))
            }
            Text(verbatim: discoveredAppName ?? appName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
            Text(verbatim: localized(isWelcome ? "account.start_title" : titleKey(for: step)))
                .font(.title.bold())
            if model.session == nil {
                Text(verbatim: localized(isWelcome ? "account.start_message" : subtitleKey(for: step)))
                    .foregroundStyle(palette.secondaryText)
                    .font(.body)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Símbolo das etapas que não são login/cadastro; nelas o ícone do app é mantido.
    func stepSymbol(for step: UAPPAccountModel.Step) -> String? {
        switch step {
        case .login, .signup: nil
        case .confirmSignup: "envelope.badge"
        case .recover: nil
        case .verifyRecovery: "number"
        case .newPassword: "lock.rotation"
        }
    }

    @ViewBuilder
    private func authenticationContent(for step: UAPPAccountModel.Step) -> some View {
        if model.methods.contains(.email) {
            VStack(alignment: .leading, spacing: 18) {
                if model.isCompletingSignup {
                    UAPPProfilePhotoPicker(photo: $model.photo, theme: theme, languageIdentifier: selectedLanguage)
                } else {
                    switch step {
                    case .login, .signup:
                        if step == .signup {
                            if model.supportsProfilePhoto {
                                UAPPProfilePhotoPicker(photo: $model.photo, theme: theme, languageIdentifier: selectedLanguage)
                            }
                            nameField
                        }
                        emailField
                        passwordField(isConfirmation: false)
                        if step == .signup {
                            passwordField(isConfirmation: true)
                            passwordHint
                        } else {
                            Button(localized("account.forgot")) { open(.recover) }
                                .font(.subheadline.weight(.semibold))
                                #if os(macOS)
                                // No Mac o botão padrão ganharia moldura; aqui ele é um link.
                                .buttonStyle(.link)
                                #endif
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                        }
                    case .recover:
                        emailField
                    case .confirmSignup, .verifyRecovery:
                        Label {
                            Text(verbatim: model.pendingEmail)
                                .textSelection(.enabled)
                        } icon: {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(accentColor)
                                .accessibilityHidden(true)
                        }
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            accentColor.opacity(UAPPSurface.selectionFillOpacity(colorScheme)),
                            in: RoundedRectangle(cornerRadius: UAPPSurface.cornerRadius, style: .continuous)
                        )
                        codeField
                        Button {
                            Task { await model.resendCode() }
                        } label: {
                            Label(localized("account.resend"), systemImage: "arrow.clockwise")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                    case .newPassword:
                        passwordField(isConfirmation: false)
                        passwordField(isConfirmation: true)
                        passwordHint
                    }
                }
                primaryButton(for: step)
            }
            .disabled(model.isBusy)
            if !model.isCompletingSignup, step == .login || step == .signup {
                socialButtons
                legalLinks
            } else if !model.isCompletingSignup, step != .newPassword, Self.showsBackButton ? step != .recover : true {
                backToLoginButton
            }
        } else {
            socialButtons
        }
    }

    private var backToLoginButton: some View {
        Button(localized("account.back_login")) {
            focusedField = nil
            #if os(macOS)
            // No Mac o login é a raiz da tela: volta para ela sem empilhar outra etapa.
            path.removeAll()
            switchRoot(to: .login)
            #else
            path = [.login]
            model.navigate(to: .login)
            #endif
        }
        .font(.subheadline.weight(.semibold))
        #if os(macOS)
        .buttonStyle(.link)
        #endif
        .frame(minHeight: 44)
        .disabled(model.isBusy)
    }

    private var nameField: some View {
        fieldShell("account.name", field: .name, symbol: "person") {
            TextField(localized("account.name"), text: $model.name)
                .focused($focusedField, equals: .name)
                #if os(iOS)
                .textContentType(.name)
                #endif
                .submitLabel(.next)
                .onSubmit { focusedField = .email }
        }
    }

    private var emailField: some View {
        fieldShell("auth.email", field: .email, symbol: "envelope") {
            TextField(localized("auth.email"), text: $model.email)
                .focused($focusedField, equals: .email)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                #endif
                .submitLabel(model.step == .recover ? .go : .next)
                .onSubmit {
                    if model.step == .recover {
                        submit()
                    } else {
                        focusedField = .password
                    }
                }
        }
    }

    private func passwordField(isConfirmation: Bool) -> some View {
        let key = isConfirmation ? "account.password_confirmation" : "account.password"
        let field: Field = isConfirmation ? .confirmation : .password
        let value = isConfirmation ? $model.passwordConfirmation : $model.password
        let isVisible = visiblePasswordFields.contains(field)

        return fieldShell(key, field: field, symbol: isConfirmation ? "lock.shield" : "lock") {
            HStack(spacing: 8) {
                Group {
                    if isVisible {
                        TextField(localized(key), text: value)
                            .focused($focusedField, equals: field)
                    } else {
                        SecureField(localized(key), text: value)
                            .focused($focusedField, equals: field)
                    }
                }
                .autocorrectionDisabled()
                #if os(iOS)
                .textContentType(model.step == .login ? .password : .newPassword)
                .textInputAutocapitalization(.never)
                #endif
                .submitLabel(model.step == .login || isConfirmation ? .go : .next)
                .onSubmit {
                    if model.step == .login || isConfirmation {
                        submit()
                    } else {
                        focusedField = .confirmation
                    }
                }

                Button {
                    if isVisible {
                        visiblePasswordFields.remove(field)
                    } else {
                        visiblePasswordFields.insert(field)
                    }
                } label: {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .foregroundStyle(palette.secondaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(model.isBusy)
                .accessibilityLabel(Text(verbatim: localized(
                    isVisible ? "account.password.hide" : "account.password.show"
                )))
            }
        }
    }

    private var passwordHint: some View {
        Text(verbatim: String(format: localized("account.password_hint"), model.minimumPasswordLength))
            .font(.footnote)
            .foregroundStyle(palette.secondaryText)
    }

    private var codeField: some View {
        fieldShell("auth.code", field: .code, symbol: "number") {
            TextField(localized("auth.code"), text: $model.code)
                .focused($focusedField, equals: .code)
                .textContentType(.oneTimeCode)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .submitLabel(.go)
                .onSubmit { submit() }
        }
    }

    private func fieldShell(
        _ key: String,
        field: Field,
        symbol: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        let isFocused = focusedField == field
        return VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: localized(key))
                .font(.subheadline.weight(.semibold))
                .accessibilityHidden(true)
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isFocused ? accentColor : palette.secondaryText)
                    .frame(minWidth: 22)
                    .accessibilityHidden(true)
                content()
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(UAPPFieldBackground(isFocused: isFocused, accent: accentColor, palette: palette))
            .contentShape(Rectangle())
            .onTapGesture { focusedField = field }
        }
    }

    private func primaryButton(for step: UAPPAccountModel.Step) -> some View {
        let key = if model.isCompletingSignup {
            "photo.save"
        } else {
            switch step {
            case .login: "account.connect"
            case .signup: "account.create"
            case .confirmSignup, .verifyRecovery: "auth.verify"
            case .recover: "account.send_recovery"
            case .newPassword: "account.save_password"
            }
        }
        return Button(action: submit) {
            UAPPPrimaryButtonLabel(
                title: localized(key),
                systemImage: primarySymbol(for: step),
                isBusy: model.isBusy,
                accent: accentColor,
                palette: palette
            )
            .opacity(model.canSubmit || model.isBusy ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!model.canSubmit)
        .animation(.easeInOut(duration: 0.2), value: model.canSubmit)
    }

    private func primarySymbol(for step: UAPPAccountModel.Step) -> String {
        if model.isCompletingSignup {
            return "checkmark"
        }
        switch step {
        case .login: return "arrow.right.circle.fill"
        case .signup: return "person.badge.plus"
        case .confirmSignup, .verifyRecovery: return "checkmark.seal.fill"
        case .recover: return "paperplane.fill"
        case .newPassword: return "lock.fill"
        }
    }

    @ViewBuilder
    private var socialButtons: some View {
        let methods = model.methods.filter { $0 != .email }
        if !methods.isEmpty {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Rectangle().fill(palette.separator).frame(height: 1)
                    Text(verbatim: localized("account.or")).font(.footnote).foregroundStyle(palette.secondaryText)
                    Rectangle().fill(palette.separator).frame(height: 1)
                }
                HStack(spacing: 12) {
                    ForEach(methods) { method in
                        Button {
                            focusedField = nil
                            Task { await model.signIn(method) }
                        } label: {
                            UAPPLoginServiceIcon(method: method)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .uappCardSurface(palette, cornerRadius: UAPPSurface.largeCornerRadius)
                                .contentShape(RoundedRectangle(
                                    cornerRadius: UAPPSurface.largeCornerRadius,
                                    style: .continuous
                                ))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: localized("auth.\(method.rawValue)")))
                    }
                }
            }
            .disabled(model.isBusy)
        }
    }

    @ViewBuilder
    private var legalLinks: some View {
        if termsURL != nil || privacyURL != nil {
            // Lado a lado quando cabem; com texto ampliado ou tela estreita, um abaixo do outro.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 28) { legalLinkItems }
                VStack(spacing: 8) { legalLinkItems }
            }
            .font(.footnote.weight(.medium))
        }
    }

    @ViewBuilder
    private var legalLinkItems: some View {
        if let termsURL {
            Link(localized("about.terms"), destination: termsURL)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minHeight: 32)
        }
        if let privacyURL {
            Link(localized("about.privacy"), destination: privacyURL)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minHeight: 32)
        }
    }

    private func submit() {
        guard model.canSubmit else { return }
        focusedField = nil
        Task { await model.submit() }
    }

    private func localized(_ key: String) -> String {
        let value = uappLocalized(key, languageIdentifier: selectedLanguage)
        return value == key ? uappLocalized(key, languageIdentifier: "en") : value
    }

    private func loadAppIcon() async {
        guard let url = appIconURL ?? remoteIconURL else { return }
        loadedIcon = try? await UAPPRemoteImageCache.shared.load(url)
    }

    private func loadAppIdentity() async {
        guard let client else { return }
        guard let about = try? await client.about() else { return }
        let project = await client.currentProject()
        discoveredAppName = project?.displayName
        remoteIconURL = project?.iconURL ?? about.apps.first {
            $0.slug == project?.slug || $0.projectId == project?.slug
        }?.iconURL
    }
}

struct UAPPLoginServiceIcon: View {
    let method: UAPPLoginMethod
    var body: some View {
        switch method {
        case .google:
            Image("UAPPGoogleLogin", bundle: .module).resizable().scaledToFit().frame(width: 26, height: 26)
        case .apple:
            Image(systemName: "applelogo").font(.system(size: 28)).foregroundStyle(Color.primary)
        case .github:
            Image("UAPPGitHubLogin", bundle: .module).resizable().scaledToFit().frame(width: 28, height: 28)
                .foregroundStyle(Color.primary)
        case .email:
            Image(systemName: "envelope").foregroundStyle(Color.primary)
        }
    }
}
