import Foundation
import SwiftUI

@MainActor
final class UAPPParticipationModel: ObservableObject {
    let client: UAPPClient
    @Published private(set) var session: UAPPAuthenticationSession?
    @Published private(set) var identity: UAPPIdentity?
    @Published private(set) var isBusy = false
    @Published private(set) var errorKey: String?
    @Published private(set) var emailCodeSent = false
    @Published var email = ""
    @Published var code = ""
    @Published var showsAccount = false
    private var pendingAction: (@MainActor () async -> Void)?
    private var verificationEmail: String?

    init(client: UAPPClient) {
        self.client = client
    }

    var isEnabled: Bool {
        client.authentication != nil
    }

    var methods: [UAPPLoginMethod] {
        client.authentication?.methods ?? []
    }

    var canRequestCode: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.contains("@") && value.contains(".") && !isBusy
    }

    func refresh() async {
        guard !isBusy else { return }
        guard let provider = client.authentication else {
            identity = await client.currentIdentity()
            return
        }
        do {
            session = try await provider.currentSession()
            identity = session?.identity
            await client.setIdentity(session?.identity)
            errorKey = nil
        } catch {
            session = nil
            identity = nil
            errorKey = "auth.session_error"
        }
    }

    func perform(_ action: @escaping @MainActor () async -> Void) async {
        guard !isBusy else { return }
        guard isEnabled else { await action(); return }
        await refresh()
        if session != nil {
            await action()
        } else {
            pendingAction = action
            showsAccount = true
        }
    }

    func finishPresentation() async {
        let action = pendingAction
        pendingAction = nil
        if session != nil {
            await action?()
        }
    }

    func signIn(_ method: UAPPLoginMethod) async {
        guard let provider = client.authentication else { return }
        await run {
            try await provider.signIn(method: method)
        }
    }

    func requestEmailCode() async {
        guard let provider = client.authentication, canRequestCode else { return }
        isBusy = true
        errorKey = nil
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await provider.requestEmailCode(email: value)
            verificationEmail = value
            emailCodeSent = true
        } catch {
            errorKey = "auth.email_error"
        }
        isBusy = false
    }

    func verifyEmailCode() async {
        guard let provider = client.authentication, let email = verificationEmail else { return }
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        await run { try await provider.verifyEmailCode(email: email, code: code) }
    }

    func changeEmail() {
        guard !isBusy else { return }
        emailCodeSent = false
        verificationEmail = nil
        code = ""
        errorKey = nil
    }

    func signOut() async {
        guard let provider = client.authentication, !isBusy else { return }
        isBusy = true
        errorKey = nil
        do {
            try await provider.signOut()
            session = nil
            identity = nil
            await client.setIdentity(nil)
        } catch {
            session = try? await provider.currentSession()
            identity = session?.identity
            if session == nil {
                await client.setIdentity(nil)
            }
            errorKey = "auth.signout_error"
        }
        pendingAction = nil
        isBusy = false
    }

    private func run(_ operation: () async throws -> UAPPAuthenticationSession) async {
        guard !isBusy else { return }
        isBusy = true
        errorKey = nil
        do {
            let session = try await operation()
            self.session = session
            identity = session.identity
            await client.setIdentity(session.identity)
            showsAccount = false
            changeEmailAfterSignIn()
        } catch UAPPAuthenticationError.cancelled {
            errorKey = nil
        } catch {
            errorKey = "auth.signin_error"
        }
        isBusy = false
    }

    private func changeEmailAfterSignIn() {
        code = ""
        verificationEmail = nil
        emailCodeSent = false
    }
}
