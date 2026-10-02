import Foundation
import UAPPKit

extension ContentView {
    @MainActor
    func saveConfiguration(showSuccessMessage: Bool = true) -> Bool {
        let slug = projectSlug.trimmingCharacters(in: .whitespacesAndNewlines)
        let serverString = normalizedServer

        guard
            !slug.isEmpty,
            let server = URL(string: serverString),
            let scheme = server.scheme,
            !scheme.isEmpty,
            server.host != nil
        else {
            showStatus(localized("demo.invalid_configuration"), success: false)
            return false
        }

        projectSlug = slug
        supabaseServer = serverString
        UAPPKit.setup(projectId: slug, host: server, theme: configuredTheme)
        account.configure(projectId: slug, host: server)

        if showSuccessMessage {
            showStatus(localized("demo.configuration_saved"), success: true)
        }
        return true
    }

    @MainActor
    func testConnection() {
        guard saveConfiguration(showSuccessMessage: false) else { return }

        isTestingConnection = true
        statusMessage = nil

        Task {
            do {
                let client = try UAPPKit.makeClient()
                _ = try await client.feedbackPage(limit: 1)
                showStatus(localized("demo.connection_success"), success: true)
            } catch {
                showStatus("\(localized("demo.connection_failure")) \(error.localizedDescription)", success: false)
            }
            isTestingConnection = false
        }
    }

    @MainActor
    func present(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            showStatus(error.localizedDescription, success: false)
        }
    }

    @MainActor
    func openFeedback() {
        guard saveConfiguration(showSuccessMessage: false) else { return }
        Task {
            await account.refreshSession()
            do {
                if account.session == nil, account.hasProfile {
                    try await UAPPKit.showFeedback(identity: account.identity, accessTokenProvider: nil)
                } else {
                    try await UAPPKit.showFeedback(identity: account.identity, authentication: account.authentication)
                }
            } catch {
                showStatus(error.localizedDescription, success: false)
            }
        }
    }

    @MainActor
    func openRoadmap() {
        guard saveConfiguration(showSuccessMessage: false) else { return }
        Task {
            await account.refreshSession()
            do {
                if account.session == nil, account.hasProfile {
                    try await UAPPKit.showRoadmap(identity: account.identity, accessTokenProvider: nil)
                } else {
                    try await UAPPKit.showRoadmap(identity: account.identity, authentication: account.authentication)
                }
            } catch {
                showStatus(error.localizedDescription, success: false)
            }
        }
    }

    func showStatus(_ message: String, success: Bool) {
        statusMessage = message
        statusIsSuccess = success
        isShowingStatus = true
    }

    func localized(_ key: String) -> String {
        DemoLocalized.string(key, languageIdentifier: languageIdentifier)
    }
}
