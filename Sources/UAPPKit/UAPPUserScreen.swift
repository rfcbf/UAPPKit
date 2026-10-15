import SwiftUI

/// Informações da conta conectada, prontas para apresentação em uma sheet.
/// Recebe a sessão já disponível no aplicativo e não inicia autenticação.
@MainActor
public struct UAPPUserScreen: View {
    @StateObject private var model: UAPPUserModel
    private let identity: UAPPIdentity
    private let theme: UAPPTheme
    private let isPublicProfile: Bool
    private let isLocalProfile: Bool
    /// Sessão recebida do aplicativo; quando muda para a mesma conta, a tela passa a exibi-la.
    private let hostSession: UAPPAuthenticationSession?
    private let onEditProfile: (@MainActor () -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.hostIdentifier
    @State private var hasPreparedLanguage = false
    @State private var selectedFeedbackId: String?
    @State private var photoErrorKey: String?
    #if os(iOS)
    @State private var profileDetent: PresentationDetent = .medium
    #endif

    /// - Parameters:
    ///   - onSessionChange: Recebe a sessão atualizada pela tela (nova foto) ou `nil` ao sair da conta.
    ///   - onEditProfile: Quando informado, a barra de navegação mostra um botão de editar perfil, entre sair
    ///     e o idioma, que chama esta ação; o aplicativo apresenta o próprio editor. Depois de salvar, basta passar a sessão
    ///     atualizada em `session` para a tela exibir o novo nome. Sem ação, o botão não aparece.
    public init(
        session: UAPPAuthenticationSession,
        authentication: any UAPPAuthenticationProvider,
        client: UAPPClient? = nil,
        theme: UAPPTheme = .system,
        onSessionChange: @escaping @MainActor (UAPPAuthenticationSession?) -> Void = { _ in },
        onEditProfile: (@MainActor () -> Void)? = nil
    ) {
        _model = StateObject(wrappedValue: UAPPUserModel(
            session: session, authentication: authentication, client: client, onSessionChange: onSessionChange
        ))
        identity = session.identity
        self.theme = theme
        isPublicProfile = false
        isLocalProfile = false
        hostSession = session
        self.onEditProfile = onEditProfile
    }

    /// Perfil público sem e-mail ou ações da conta; com cliente e feedback, consulta nome e estatísticas públicos.
    public init(
        publicIdentity: UAPPIdentity,
        theme: UAPPTheme = .system,
        client: UAPPClient? = nil,
        feedbackId: String? = nil
    ) {
        _model = StateObject(wrappedValue: UAPPUserModel(client: client, feedbackId: feedbackId))
        identity = UAPPIdentity(
            userId: publicIdentity.userId,
            displayName: publicIdentity.displayName,
            avatarURL: publicIdentity.avatarURL
        )
        self.theme = theme
        isPublicProfile = true
        isLocalProfile = false
        hostSession = nil
        onEditProfile = nil
    }

    /// Perfil local e sua participação pública nesta instalação, sem iniciar login.
    public init(profile: UAPPIdentity, client: UAPPClient, theme: UAPPTheme = .system) {
        _model = StateObject(wrappedValue: UAPPUserModel(client: client, usesInstallationProfile: true))
        identity = profile
        self.theme = theme
        isPublicProfile = true
        isLocalProfile = true
        hostSession = nil
        onEditProfile = nil
    }

    /// O botão de editar perfil só existe na conta conectada e quando o aplicativo informa a ação.
    var showsEditProfile: Bool {
        !isPublicProfile && onEditProfile != nil
    }

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    private var accentColor: Color {
        palette.accent ?? .accentColor
    }

    private var name: String? {
        nonempty(isLocalProfile ? identity.displayName : model.publicProfile?.author.name ?? identity.displayName)
    }

    private var email: String? {
        nonempty(identity.email)
    }

    public var body: some View {
        screenBody.uappTextSizeLimit()
    }

    @ViewBuilder private var screenBody: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    HStack(spacing: 20) {
                        avatarFrame
                        VStack(alignment: .leading, spacing: 10) {
                            Text(verbatim: name.map { isPublicProfile ? $0 : UAPPDisplayName.abbreviated($0) } ?? email ?? localized("user.account"))
                                .font(.headline)
                                .lineLimit(isPublicProfile ? nil : 1)
                                .minimumScaleFactor(isPublicProfile ? 1 : 0.75)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel(Text(verbatim: name ?? email ?? localized("user.account")))
                            if let email, name != nil, email != name {
                                Text(verbatim: email)
                                    .font(.subheadline)
                                    .foregroundStyle(palette.secondaryText)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if isPublicProfile {
                        publicActivityContent
                    } else {
                        activityContent
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
            }
            .background(palette.background.ignoresSafeArea())
            .foregroundStyle(palette.primaryText)
            .uappNavigationBar(verbatimTitle: "", accentColor: accentColor, onClose: {
                guard !model.isBusy else { return }
                dismiss()
            })
            .toolbar {
                if !isPublicProfile {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await model.signOut() }
                        } label: {
                            if model.isBusy {
                                ProgressView().tint(.red)
                            } else {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundStyle(Color.red)
                            }
                        }
                        .accessibilityLabel(Text(verbatim: localized("auth.signout")))
                        .disabled(model.isBusy || model.isUploadingPhoto)
                    }
                }
                // Entre sair e o idioma, que a barra de navegação acrescenta depois.
                if showsEditProfile {
                    ToolbarItem(placement: .primaryAction) {
                        editProfileButton
                    }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedFeedbackId != nil },
                set: {
                    if !$0 {
                        selectedFeedbackId = nil
                    }
                }
            )) {
                if let selectedFeedbackId {
                    UAPPProfileFeedbackDestination(model: model, itemId: selectedFeedbackId, accentColor: accentColor)
                }
            }
        }
        .environment(\.uappTheme, theme)
        .uappToast(message: Binding(
            get: { (photoErrorKey ?? model.errorKey).map { localized($0) } },
            set: {
                if $0 == nil {
                    photoErrorKey = nil
                    model.dismissError()
                }
            }
        ))
        .environment(\.locale, Locale(identifier: selectedLanguage))
        .task {
            guard !hasPreparedLanguage else { return }
            hasPreparedLanguage = true
            selectedLanguage = UAPPLocalizationPreferences.preparePresentation(initialIdentifier: locale.identifier)
            if isPublicProfile {
                await model.loadPublicProfile()
            } else {
                await model.loadActivity()
            }
        }
        .interactiveDismissDisabled(model.isBusy || model.isUploadingPhoto)
        .modifier(UAPPFeedbackLiveModifier(client: model.profileClient) {
            await model.reconcileActivity()
        })
        .uappOnChange(of: hostSession) { session in
            if let session {
                model.adoptSession(session)
            }
        }
        .uappOnChange(of: model.session == nil) { signedOut in
            if signedOut, !isPublicProfile {
                dismiss()
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large], selection: $profileDetent)
        .presentationDragIndicator(.visible)
        #endif
    }

    private var editProfileButton: some View {
        Button {
            onEditProfile?()
        } label: {
            Image(systemName: "pencil")
                .foregroundStyle(accentColor)
        }
        .accessibilityLabel(Text(verbatim: localized("user.edit_profile")))
        .disabled(model.isBusy || model.isUploadingPhoto)
    }

    private var avatarRing: some View {
        Circle().strokeBorder(
            accentColor.opacity(UAPPSurface.accentFillOpacity(colorScheme) * 2),
            lineWidth: 2
        )
    }

    @ViewBuilder
    private var avatarFrame: some View {
        #if os(iOS)
        if !isPublicProfile, model.supportsProfilePhoto {
            UAPPProfilePhotoPicker(
                photo: Binding(
                    get: { model.profilePhoto },
                    set: { data in
                        guard let data else { return }
                        Task { await model.updateProfilePhoto(data) }
                    }
                ),
                theme: theme,
                languageIdentifier: selectedLanguage,
                avatarOnly: .init(remoteURL: profileAvatarURL, size: 104) { key in photoErrorKey = key }
            )
            .overlay {
                if model.isUploadingPhoto {
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        ProgressView().tint(accentColor)
                    }
                    .frame(width: 104, height: 104)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: localized("photo.uploading")))
                }
            }
            .padding(4)
            .overlay { avatarRing.allowsHitTesting(false) }
            .disabled(model.isUploadingPhoto || model.isBusy)
        } else {
            readOnlyAvatar
        }
        #else
        readOnlyAvatar
        #endif
    }

    private var readOnlyAvatar: some View {
        avatar
            .frame(width: 104, height: 104)
            .clipShape(Circle())
            .padding(4)
            .overlay { avatarRing }
            .accessibilityHidden(true)
    }

    private var profileAvatarURL: URL? {
        if isLocalProfile, let avatarURL = identity.avatarURL {
            return avatarURL
        }
        if !isPublicProfile {
            return model.avatarURL ?? identity.avatarURL
        }
        // Um perfil carregado sem foto não deve recuperar uma imagem antiga do card.
        if let profile = model.publicProfile {
            return profile.author.avatarURL
        }
        return identity.avatarURL
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = profileAvatarURL {
            UAPPCachedImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else if phase.error != nil {
                    avatarPlaceholder
                } else {
                    UAPPImageLoadingPlaceholder()
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle().fill(palette.cardBackground)
            Image(systemName: "person.fill")
                .font(.system(size: 44))
                .foregroundStyle(accentColor)
        }
    }

    private var publicActivityContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(verbatim: localized("user.public_activity"))
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { activityCards }
                VStack(spacing: 10) { activityCards }
            }
            HStack {
                Text(verbatim: localized("user.requests")).font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 12)
                Menu {
                    UAPPStatusFilterOptions(statuses: model.publicProfile?.statuses ?? [], selection: Binding(
                        get: { model.publicStatusId },
                        set: { statusId in Task { await model.filterPublicHistory(statusId: statusId) } }
                    ))
                } label: {
                    Label(
                        model.publicProfile?.statuses.first { $0.id == model.publicStatusId }?.name
                            ?? localized("feedback.filter.status"),
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                    .font(.subheadline)
                }
                .disabled(model.isLoadingActivity)
            }
            LazyVStack(spacing: 0) {
                ForEach(model.history) { item in
                    Button {
                        #if os(iOS)
                        profileDetent = .large
                        #endif
                        selectedFeedbackId = item.id
                    } label: {
                        publicHistoryRow(item)
                    }
                    .buttonStyle(.plain)
                    if item.id != model.history.last?.id {
                        Divider().overlay(palette.separator)
                    }
                }
            }
            .padding(.horizontal, model.history.isEmpty ? 0 : 16)
            .background {
                if !model.history.isEmpty {
                    Color.clear.uappCardSurface(palette)
                }
            }
            if model.isLoadingActivity {
                ProgressView().frame(maxWidth: .infinity)
            }
            if let key = model.activityErrorKey {
                UAPPInlineBanner(message: localized(key), style: .error, accent: accentColor)
                Button {
                    Task { await model.loadPublicProfile(loadMore: !model.history.isEmpty && model.publicProfile?.nextCursor != nil) }
                } label: {
                    secondaryLabel("user.retry", symbol: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(model.isLoadingActivity)
            } else if model.publicProfile != nil, model.history.isEmpty {
                emptyHistory(model.publicStatusId == nil ? "user.history_empty" : "feedback.filter.empty")
            }
            if model.publicProfile?.nextCursor != nil, model.activityErrorKey == nil {
                Button { Task { await model.loadPublicProfile(loadMore: true) } } label: {
                    secondaryLabel("user.more", symbol: "chevron.down")
                }
                .buttonStyle(.plain)
                .disabled(model.isLoadingActivity)
            }
        }
    }

    private var activityContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { activityCards }
                VStack(spacing: 10) { activityCards }
            }
            Text(verbatim: localized("user.history"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if model.isLoadingActivity {
                ProgressView().frame(maxWidth: .infinity)
            }
            ForEach(model.history) { item in
                historyCard(item)
            }
            if let key = model.activityErrorKey {
                UAPPInlineBanner(message: localized(key), style: .error, accent: accentColor)
                Button {
                    Task { await model.loadActivity(loadMore: !model.history.isEmpty && model.activity?.nextCursor != nil) }
                } label: {
                    secondaryLabel("user.retry", symbol: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(model.isLoadingActivity || model.isBusy)
            } else if model.activity != nil, model.history.isEmpty {
                emptyHistory("user.history_empty")
            }
            if model.activity?.nextCursor != nil, model.activityErrorKey == nil {
                Button { Task { await model.loadActivity(loadMore: true) } } label: {
                    secondaryLabel("user.more", symbol: "chevron.down")
                }
                .buttonStyle(.plain)
                .disabled(model.isLoadingActivity || model.isBusy)
            }
        }
    }
}

/// Partes do histórico e dos cartões de atividade, fora do corpo da tela para mantê-lo enxuto.
extension UAPPUserScreen {
    private func historyCard(_ item: UAPPUserActivityPage.Item) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !isPublicProfile {
                Text(verbatim: item.appName ?? item.appSlug ?? localized("user.application"))
                    .font(.caption.weight(.semibold)).foregroundStyle(palette.secondaryText)
            }
            Text(verbatim: item.title).font(.subheadline.weight(.semibold))
            HStack(alignment: .top) {
                UAPPStatusBadge(status: historyStatus(item), title: statusLabel(item))
                Spacer(minLength: 8)
                Text(item.createdAt, format: .dateTime.day().month().year())
                    .font(.caption).foregroundStyle(palette.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .uappCardSurface(palette)
    }

    private func secondaryLabel(_ key: String, symbol: String) -> some View {
        UAPPSecondaryButtonLabel(
            title: localized(key),
            systemImage: symbol,
            accent: accentColor,
            minHeight: 44
        )
    }

    private func emptyHistory(_ key: String) -> some View {
        HStack(spacing: 12) {
            UAPPAccentIconBadge(
                systemImage: "tray",
                accent: accentColor,
                size: 40,
                cornerRadius: 12,
                font: .body.weight(.semibold)
            )
            Text(verbatim: localized(key))
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .uappCardSurface(palette)
    }

    private func historyStatus(_ item: UAPPUserActivityPage.Item) -> UAPPRoadmapColumn.Status? {
        if let status = model.publicProfile?.statuses.first(where: { $0.id == item.statusId || $0.key == item.statusKey }) {
            return status
        }
        guard let key = item.statusKey else { return nil }
        return .init(id: item.statusId ?? key, key: key, name: statusLabel(item), position: 0, color: item.statusColor)
    }

    private func publicHistoryRow(_ item: UAPPUserActivityPage.Item) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(verbatim: item.title).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                if let count = item.voteCount {
                    Label(count.formatted(), systemImage: "arrow.up.circle")
                        .font(.caption.weight(.semibold)).foregroundStyle(accentColor)
                }
            }
            if let body = item.body, !body.isEmpty {
                Text(verbatim: body).font(.subheadline).foregroundStyle(palette.secondaryText).lineLimit(3)
            }
            HStack(spacing: 8) {
                UAPPStatusBadge(status: historyStatus(item), title: statusLabel(item))
                if let count = item.commentCount {
                    Label(count.formatted(), systemImage: "bubble.right")
                        .font(.caption).foregroundStyle(palette.secondaryText)
                }
                Spacer(minLength: 8)
                Text(item.createdAt, format: .dateTime.day().month().year())
                    .font(.caption).foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var activityCards: some View {
        let totals = isPublicProfile ? model.publicProfile?.totals : model.activity?.totals
        activityCard("user.votes", symbol: "arrow.up.circle", count: totals?.votes)
        activityCard("user.comments", symbol: "bubble.left", count: totals?.comments)
        activityCard("user.requests", symbol: "lightbulb", count: totals?.feedbacks)
    }

    private func activityCard(_ key: String, symbol: String, count: Int?) -> some View {
        VStack(spacing: 8) {
            UAPPAccentIconBadge(
                systemImage: symbol,
                accent: accentColor,
                size: 34,
                cornerRadius: 10,
                font: .subheadline.weight(.semibold)
            )
            Text(verbatim: count.map { String($0) } ?? "—")
                .font(.title2.bold()).monospacedDigit()
            Text(verbatim: localized(key))
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112)
        .uappCardSurface(palette)
        .accessibilityElement(children: .combine)
    }

    private func statusLabel(_ item: UAPPUserActivityPage.Item) -> String {
        if item.state != "published" {
            return localized("user.state.\(item.state)")
        }
        if let key = item.statusKey {
            let translated = uappLocalized("status.\(key)", languageIdentifier: selectedLanguage)
            if translated != "status.\(key)" {
                return translated
            }
        }
        return item.statusName ?? localized("user.state.published")
    }

    private func nonempty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func localized(_ key: String) -> String {
        let value = uappLocalized(key, languageIdentifier: selectedLanguage)
        return value == key ? uappLocalized(key, languageIdentifier: "en") : value
    }
}
