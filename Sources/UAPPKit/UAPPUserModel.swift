import SwiftUI

@MainActor
final class UAPPUserModel: ObservableObject {
    func dismissError() {
        errorKey = nil
    }

    @Published private(set) var session: UAPPAuthenticationSession?
    @Published private(set) var isBusy = false
    @Published private(set) var errorKey: String?
    @Published private(set) var activity: UAPPUserActivityPage?
    @Published private(set) var history: [UAPPUserActivityPage.Item] = []
    @Published private(set) var isLoadingActivity = false
    @Published private(set) var activityErrorKey: String?
    @Published private(set) var publicProfile: UAPPPublicAuthorProfile?
    @Published private(set) var publicStatusId: String?
    /// Última foto definida nesta tela, exibida antes que a URL da sessão seja carregada.
    @Published private(set) var profilePhoto: Data?
    @Published private(set) var isUploadingPhoto = false
    private let publicFeedbackId: String?
    private let usesInstallationProfile: Bool
    private let client: UAPPClient?
    private var isReconciling = false
    var profileClient: UAPPClient? {
        guard let client, !client.isAccountActivityOnly else { return nil }
        return client
    }

    private let authentication: (any UAPPAuthenticationProvider)?
    private let onSessionChange: @MainActor (UAPPAuthenticationSession?) -> Void

    init(client: UAPPClient? = nil, feedbackId: String? = nil, usesInstallationProfile: Bool = false) {
        session = nil
        authentication = nil
        self.client = client
        publicFeedbackId = feedbackId
        self.usesInstallationProfile = usesInstallationProfile
        onSessionChange = { _ in }
    }

    init(
        session: UAPPAuthenticationSession,
        authentication: any UAPPAuthenticationProvider,
        client: UAPPClient? = nil,
        onSessionChange: @escaping @MainActor (UAPPAuthenticationSession?) -> Void
    ) {
        self.session = session
        self.authentication = authentication
        self.client = client
        self.onSessionChange = onSessionChange
        publicFeedbackId = nil
        usesInstallationProfile = false
    }

    func loadPublicProfile(loadMore: Bool = false) async {
        while isReconciling {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
        }
        guard !isLoadingActivity, client != nil, publicFeedbackId != nil || usesInstallationProfile else { return }
        if loadMore, publicProfile?.nextCursor == nil {
            return
        }
        isLoadingActivity = true
        activityErrorKey = nil
        defer { isLoadingActivity = false }
        do {
            let page = try await fetchPublicProfile(cursor: loadMore ? publicProfile?.nextCursor : nil)
            guard !Task.isCancelled else { return }
            let existing = loadMore ? history : []
            let ids = Set(existing.map(\.id))
            history = existing + page.items.filter { !ids.contains($0.id) }
            publicProfile = page
        } catch {
            activityErrorKey = "user.activity_error"
        }
    }

    private func fetchPublicProfile(cursor: String?) async throws -> UAPPPublicAuthorProfile {
        guard let client else { throw UAPPKitError.invalidResponse }
        if let publicFeedbackId {
            return try await client.authorProfile(for: publicFeedbackId, cursor: cursor, statusId: publicStatusId)
        }
        return try await client.participationProfile(cursor: cursor, statusId: publicStatusId)
    }

    func filterPublicHistory(statusId: String?) async {
        while isReconciling {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
        }
        guard !isLoadingActivity else { return }
        publicStatusId = statusId
        history = []
        await loadPublicProfile()
    }

    func feedbackPage(itemId: String) async throws -> UAPPFeedbackPage? {
        try await client?.feedbackPage(itemId: itemId)
    }

    func loadActivity(loadMore: Bool = false) async {
        while isReconciling {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
        }
        guard !isLoadingActivity, !isBusy, session != nil else { return }
        guard let client, let authentication else {
            activityErrorKey = "user.activity_unavailable"
            return
        }
        if loadMore, activity?.nextCursor == nil {
            return
        }
        isLoadingActivity = true
        activityErrorKey = nil
        defer { isLoadingActivity = false }
        do {
            guard let current = try await authentication.currentSession(),
                  current.identity.userId == session?.identity.userId
            else {
                throw UAPPAuthenticationError.signInRequired
            }
            let page = try await client.userActivity(session: current, cursor: loadMore ? activity?.nextCursor : nil)
            guard !Task.isCancelled, session?.identity.userId == current.identity.userId else { return }
            let existing = loadMore ? history : []
            let ids = Set(existing.map(\.id))
            history = existing + page.items.filter { !ids.contains($0.id) }
            activity = page
        } catch {
            guard !Task.isCancelled, session != nil else { return }
            activityErrorKey = "user.activity_error"
        }
    }

    /// Reconciles the currently loaded history without dropping subsequent pages.
    func reconcileActivity() async {
        while isLoadingActivity || isReconciling || isBusy {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
        }
        guard !Task.isCancelled, let client else { return }
        isReconciling = true
        defer { isReconciling = false }
        let targetCount = max(1, history.count)
        do {
            var refreshed: [UAPPUserActivityPage.Item] = []
            var cursor: String?
            var visited = Set<String>()
            if publicFeedbackId != nil || usesInstallationProfile {
                var lastPage: UAPPPublicAuthorProfile?
                repeat {
                    let page = try await fetchPublicProfile(cursor: cursor)
                    let ids = Set(refreshed.map(\.id))
                    refreshed += page.items.filter { !ids.contains($0.id) }
                    lastPage = page
                    cursor = page.nextCursor
                } while refreshed.count < targetCount && cursor.map({ visited.insert($0).inserted }) == true
                try Task.checkCancellation()
                history = refreshed
                publicProfile = lastPage
            } else {
                guard let authentication, let current = try await authentication.currentSession(),
                      current.identity.userId == session?.identity.userId else { return }
                var lastPage: UAPPUserActivityPage?
                repeat {
                    let page = try await client.userActivity(session: current, cursor: cursor)
                    let ids = Set(refreshed.map(\.id))
                    refreshed += page.items.filter { !ids.contains($0.id) }
                    lastPage = page
                    cursor = page.nextCursor
                } while refreshed.count < targetCount && cursor.map({ visited.insert($0).inserted }) == true
                try Task.checkCancellation()
                guard session?.identity.userId == current.identity.userId else {
                    return
                }
                history = refreshed
                activity = lastPage
            }
            activityErrorKey = nil
        } catch UAPPKitError.http(status: 403, _) {
            if publicFeedbackId != nil || usesInstallationProfile {
                history = []
                publicProfile = nil
                activityErrorKey = "user.activity_error"
            }
        } catch UAPPKitError.http(status: 404, _) {
            if publicFeedbackId != nil || usesInstallationProfile {
                history = []
                publicProfile = nil
                activityErrorKey = "user.activity_error"
            }
        } catch {
            // Keep the loaded history during temporary failures; the next event retries.
        }
    }

    var supportsProfilePhoto: Bool {
        session != nil && authentication?.supportsProfilePhoto == true
    }

    var avatarURL: URL? {
        session?.identity.avatarURL
    }

    /// Envia a nova foto e substitui a sessão; em caso de falha, mantém a última foto definida.
    func updateProfilePhoto(_ data: Data) async {
        guard !isBusy, !isUploadingPhoto, supportsProfilePhoto, let authentication,
              let userId = session?.identity.userId else { return }
        let previous = profilePhoto
        profilePhoto = data
        isUploadingPhoto = true
        errorKey = nil
        defer { isUploadingPhoto = false }
        do {
            let updated = try await authentication.uploadProfilePhoto(data)
            guard session?.identity.userId == userId else { return }
            session = updated
            onSessionChange(updated)
        } catch {
            guard session?.identity.userId == userId else { return }
            profilePhoto = previous
            errorKey = "photo.update_error"
        }
    }

    /// Adota a sessão que o aplicativo passou depois de editar o perfil fora da tela.
    /// Só vale para a mesma conta e fora de envio de foto ou saída, para não desfazer essas operações.
    func adoptSession(_ updated: UAPPAuthenticationSession) {
        guard !isBusy, !isUploadingPhoto, let current = session,
              current.identity.userId == updated.identity.userId,
              current != updated else { return }
        session = updated
    }

    func signOut() async {
        guard !isBusy, !isUploadingPhoto, session != nil, let authentication else { return }
        isBusy = true
        errorKey = nil
        defer { isBusy = false }
        do {
            try await authentication.signOut()
            session = nil
            profilePhoto = nil
            onSessionChange(nil)
        } catch {
            // Alguns provedores limpam a sessão local mesmo quando a rede falha.
            do {
                if try await authentication.currentSession() == nil {
                    session = nil
                    profilePhoto = nil
                    onSessionChange(nil)
                    return
                }
            } catch {
                // Sem confirmação, mantenha a conta visível e permita tentar novamente.
            }
            errorKey = "auth.signout_error"
        }
    }
}
