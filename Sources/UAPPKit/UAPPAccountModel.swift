import Foundation
import SwiftUI

@MainActor
final class UAPPAccountModel: ObservableObject {
    enum Step: Hashable {
        case login, signup, confirmSignup, recover, verifyRecovery, newPassword
    }

    @Published var step = Step.login
    @Published var email = ""
    @Published var name = ""
    @Published var photo: Data?
    @Published private(set) var pendingRegistrationSession: UAPPAuthenticationSession?
    @Published var password = ""
    @Published var passwordConfirmation = ""
    @Published var code = ""
    @Published private(set) var session: UAPPAuthenticationSession?
    @Published private(set) var isBusy = false
    @Published private(set) var errorKey: String?
    @Published private(set) var noticeKey: String?
    private(set) var pendingEmail = ""
    private var recoveryVerified = false
    private let provider: any UAPPAuthenticationProvider
    private let onSessionChange: @MainActor (UAPPAuthenticationSession?) -> Void
    let minimumPasswordLength: Int

    init(
        provider: any UAPPAuthenticationProvider,
        minimumPasswordLength: Int,
        onSessionChange: @escaping @MainActor (UAPPAuthenticationSession?) -> Void
    ) {
        self.provider = provider
        self.minimumPasswordLength = max(6, minimumPasswordLength)
        self.onSessionChange = onSessionChange
    }

    var methods: [UAPPLoginMethod] { provider.methods }
    var supportsProfilePhoto: Bool { provider.supportsProfilePhoto }
    var isCompletingSignup: Bool { pendingRegistrationSession != nil }
    var normalizedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    var validEmail: Bool {
        let parts = normalizedEmail.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".")
            && !normalizedEmail.contains(where: \.isWhitespace)
    }
    var canSubmit: Bool {
        guard !isBusy else { return false }
        if isCompletingSignup { return true }
        switch step {
        case .login: return validEmail && !password.isEmpty
        case .signup:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && validEmail && validNewPassword
        case .recover: return validEmail
        case .confirmSignup, .verifyRecovery: return code.trimmingCharacters(in: .whitespacesAndNewlines).count >= 6
        case .newPassword: return validNewPassword
        }
    }
    private var validNewPassword: Bool {
        password.count >= minimumPasswordLength && password == passwordConfirmation
    }

    func navigate(to step: Step) {
        guard !isBusy, !recoveryVerified, !isCompletingSignup else { return }
        self.step = step
        password = ""
        passwordConfirmation = ""
        code = ""
        errorKey = nil
        noticeKey = nil
    }

    func refresh() async {
        await perform(errorKey: "account.operation_error") {
            let current = try await self.provider.currentSession()
            self.session = current
            if current != nil { self.onSessionChange(current) }
        }
    }

    func signIn(_ method: UAPPLoginMethod) async {
        await perform(errorKey: "auth.signin_error") {
            self.accept(try await self.provider.signIn(method: method))
        }
    }

    func submit() async {
        guard canSubmit else { return }
        let submittedStep = step
        await perform(errorKey: submittedStep == .login ? "account.login_error" : "account.operation_error") {
            if let session = self.pendingRegistrationSession {
                try await self.completeSignup(session)
                return
            }
            switch submittedStep {
            case .login:
                self.accept(try await self.provider.signIn(email: self.normalizedEmail, password: self.password))
            case .signup:
                let destination = self.normalizedEmail
                let result = try await self.provider.signUp(
                    email: destination, password: self.password,
                    displayName: self.name.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                switch result {
                case let .signedIn(session): try await self.completeSignup(session)
                case .confirmationRequired:
                    self.pendingEmail = destination
                    self.clearSecrets()
                    self.step = .confirmSignup
                    self.noticeKey = "account.confirm_sent"
                }
            case .confirmSignup:
                let confirmed = try await self.provider.verifySignupCode(
                    email: self.pendingEmail, code: self.code.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                try await self.completeSignup(confirmed)
            case .recover:
                let destination = self.normalizedEmail
                try await self.provider.requestPasswordReset(email: destination)
                self.pendingEmail = destination
                self.clearSecrets()
                self.step = .verifyRecovery
                self.noticeKey = "account.recovery_sent"
            case .verifyRecovery:
                try await self.provider.verifyPasswordResetCode(email: self.pendingEmail, code: self.code.trimmingCharacters(in: .whitespacesAndNewlines))
                self.recoveryVerified = true
                self.clearSecrets()
                self.step = .newPassword
                self.noticeKey = nil
            case .newPassword:
                let session = try await self.provider.updatePassword(self.password)
                self.recoveryVerified = false
                self.accept(session)
                self.noticeKey = "account.password_updated"
            }
        }
    }

    func resendCode() async {
        let submittedStep = step
        guard submittedStep == .confirmSignup || submittedStep == .verifyRecovery else { return }
        await perform(errorKey: "account.operation_error") {
            if submittedStep == .confirmSignup {
                try await self.provider.resendSignupCode(email: self.pendingEmail)
            } else {
                try await self.provider.requestPasswordReset(email: self.pendingEmail)
            }
            self.noticeKey = "account.resent"
        }
    }

    func signOut() async {
        await perform(errorKey: "auth.signout_error") {
            defer {
                self.session = nil
                self.pendingRegistrationSession = nil
                self.photo = nil
                self.recoveryVerified = false
                self.clearSecrets()
                self.step = .login
                self.onSessionChange(nil)
            }
            try await self.provider.signOut()
        }
    }

    func cancelRecovery() async {
        guard session == nil else { return }
        guard recoveryVerified || (isBusy && (step == .verifyRecovery || step == .newPassword)) else { return }
        recoveryVerified = false
        try? await provider.signOut()
        clearSecrets()
    }

    private func completeSignup(_ session: UAPPAuthenticationSession) async throws {
        pendingRegistrationSession = session
        clearSecrets()
        do {
            let completed: UAPPAuthenticationSession
            if let photo {
                completed = try await provider.uploadProfilePhoto(photo)
            } else {
                completed = session
            }
            pendingRegistrationSession = nil
            photo = nil
            accept(completed)
        } catch {
            errorKey = "photo.upload_error"
            throw error
        }
    }

    private func accept(_ session: UAPPAuthenticationSession) {
        self.session = session
        clearSecrets()
        onSessionChange(session)
    }

    private func clearSecrets() {
        password = ""
        passwordConfirmation = ""
        code = ""
    }

    private func perform(errorKey: String, operation: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        self.errorKey = nil
        noticeKey = nil
        defer { isBusy = false }
        do {
            try await operation()
        } catch UAPPAuthenticationError.cancelled {
            return
        } catch UAPPAuthenticationError.unsupportedMethod {
            self.errorKey = "account.unsupported"
        } catch {
            self.errorKey = self.errorKey ?? errorKey
        }
    }
}
