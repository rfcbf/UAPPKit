import CryptoKit
import Foundation
import SwiftUI
import UAPPKit
#if canImport(UIKit)
import UIKit
#endif

/// Exemplo de conta do aplicativo: o mesmo provedor é entregue à área de participação.
@MainActor
final class DemoAccountModel: ObservableObject {
    @Published var name: String
    @Published var email: String
    @Published var photo: Data?
    @Published private(set) var session: UAPPAuthenticationSession?
    @Published var error: String?
    @Published private(set) var hasProfile: Bool
    @Published private(set) var isSigningOut = false

    private let defaults: UserDefaults
    private let userId: String
    private var configurationID = ""
    private var generation = 0
    private(set) var authentication: any UAPPAuthenticationProvider

    init(defaults: UserDefaults = .standard, authentication: (any UAPPAuthenticationProvider)? = nil) {
        self.defaults = defaults
        if DemoMockData.isEnabled {
            // Perfil fictício em memória; o perfil salvo no aparelho não é lido nem alterado.
            name = DemoMockData.profileName
            email = DemoMockData.profileEmail
            photo = nil
            hasProfile = true
        } else {
            name = defaults.string(forKey: "demo.profile.name") ?? ""
            email = defaults.string(forKey: "demo.profile.email") ?? ""
            photo = defaults.data(forKey: "demo.profile.photo")
            hasProfile = defaults.bool(forKey: "demo.profile.saved")
        }
        userId = defaults.string(forKey: "demo.profile.id") ?? UUID().uuidString
        defaults.set(userId, forKey: "demo.profile.id")
        self.authentication = authentication ?? UAPPAuthentication.automatic(
            configuration: .init(projectId: DemoSettings.defaultProjectSlug),
            callbackURL: URL(string: "uappkit://authentication")!
        )
    }

    var identity: UAPPIdentity? {
        if let session {
            return session.identity
        }
        if let mockIdentity = DemoMockData.identity { return mockIdentity }
        guard hasProfile else { return nil }
        return UAPPIdentity(
            userId: userId,
            email: defaults.string(forKey: "demo.profile.email"),
            displayName: defaults.string(forKey: "demo.profile.name"),
            avatarURL: localAvatarURL,
            avatarData: defaults.data(forKey: "demo.profile.photo")
        )
    }

    private var localAvatarURL: URL? {
        guard let data = defaults.data(forKey: "demo.profile.photo"),
              let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let folder = directory.appendingPathComponent("DemoProfilePhotos", isDirectory: true)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let url = folder.appendingPathComponent("\(digest).jpg")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) {
                try data.write(to: url, options: .atomic)
            }
            return url
        } catch {
            return nil
        }
    }

    func configure(projectId: String) {
        let identifier = projectId
        guard configurationID != identifier else { return }
        configurationID = identifier
        generation += 1
        authentication = UAPPAuthentication.automatic(
            configuration: .init(projectId: projectId),
            callbackURL: URL(string: "uappkit://authentication")!
        )
        session = nil
        error = nil
    }

    var canSaveProfile: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        return !hasProfile
            || trimmedName != (defaults.string(forKey: "demo.profile.name") ?? "")
            || trimmedEmail != (defaults.string(forKey: "demo.profile.email") ?? "")
            || photo != defaults.data(forKey: "demo.profile.photo")
    }

    func saveProfile() {
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(name, forKey: "demo.profile.name")
        defaults.set(email, forKey: "demo.profile.email")
        defaults.set(photo, forKey: "demo.profile.photo")
        defaults.set(true, forKey: "demo.profile.saved")
        hasProfile = true
    }

    func removeProfile() {
        name = ""
        email = ""
        photo = nil
        hasProfile = false
        for key in ["name", "email", "photo", "saved"] {
            defaults.removeObject(forKey: "demo.profile.\(key)")
        }
    }

    func setPhoto(_ data: Data?) {
        photo = data.flatMap { UAPPProfileImageProcessor.compressedJPEG(from: $0) }
    }

    func refreshSession() async {
        let capturedGeneration = generation
        do {
            let result = try await authentication.currentSession()
            guard capturedGeneration == generation else { return }
            session = result
        } catch {
            guard capturedGeneration == generation else { return }
            session = nil
            self.error = error.localizedDescription
        }
    }

    func signOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        error = nil
        let capturedGeneration = generation
        let provider = authentication
        defer { isSigningOut = false }
        do {
            try await provider.signOut()
            guard capturedGeneration == generation else { return }
            session = nil
        } catch {
            guard capturedGeneration == generation else { return }
            session = nil
            self.error = error.localizedDescription
        }
    }

    func updateSession(_ session: UAPPAuthenticationSession?) {
        self.session = session
    }

    func text(_ portuguese: String, _ english: String, _ language: String) -> String {
        language.hasPrefix("en") ? english : portuguese
    }
}
