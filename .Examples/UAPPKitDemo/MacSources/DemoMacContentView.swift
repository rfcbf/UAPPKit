import SwiftUI
import UAPPKit

private enum DemoMacSection: String, CaseIterable, Identifiable {
    case home
    case changelog

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .home: "Início"
        case .changelog: "Novidades embutidas"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "square.grid.2x2"
        case .changelog: "sparkles"
        }
    }
}

struct DemoMacContentView: View {
    /// Mesmo modelo do Demo do iPhone: conta conectada ou perfil local (nome, e-mail e foto).
    @StateObject private var account = DemoAccountModel()
    @State private var section: DemoMacSection? = .home
    @State private var projectSlug = DemoMacSettings.savedSlug
    @State private var status: String?
    @State private var isTesting = false

    var body: some View {
        NavigationSplitView {
            List(DemoMacSection.allCases, selection: $section) { item in
                Label(item.title, systemImage: item.systemImage).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch section ?? .home {
            case .home:
                home
            case .changelog:
                embeddedChangelog
            }
        }
        .task {
            configureAccount()
            await account.refreshSession()
        }
    }

    // MARK: - Início

    private var home: some View {
        Form {
            Section {
                TextField("Projeto (public_slug)", text: $projectSlug)
                HStack {
                    if let status {
                        Text(status).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Testar conexão") { Task { await testConnection() } }
                        .disabled(isTesting)
                    Button("Salvar") { save() }
                        .keyboardShortcut("s", modifiers: .command)
                }
            } header: {
                Text("Projeto")
            } footer: {
                if DemoMockData.isEnabled {
                    Text("Dados fictícios ativos (--mock-data): o projeto salvo não é usado.")
                }
            }

            Section("Telas do UAPPKit (janelas próprias)") {
                screenButton("Feedback", systemImage: "bubble.left.and.text.bubble.right") { openFeedback() }
                screenButton("Roadmap", systemImage: "map") { openRoadmap() }
                screenButton("Novidades", systemImage: "sparkles") { try UAPPKit.showChangelog() }
                screenButton("Avaliações", systemImage: "star.bubble") { try UAPPKit.showReviews(pageSize: 20) }
                screenButton("Sobre o app", systemImage: "info.circle") {
                    try UAPPKit.showAbout(configuration: DemoMacSettings.aboutConfiguration)
                }
                screenButton("Sobre o desenvolvedor", systemImage: "person.crop.square") {
                    try UAPPKit.showDeveloperAbout()
                }
                screenButton("Avaliar na App Store", systemImage: "arrow.up.forward.app") {
                    Task {
                        do {
                            try await UAPPKit.openAppStoreReview()
                        } catch {
                            status = error.localizedDescription
                        }
                    }
                }
            }

            Section {
                if let session = account.session {
                    LabeledContent(
                        "Conectado",
                        value: session.identity.displayName ?? session.identity.email ?? session.identity.userId
                    )
                    screenButton("Minha conta", systemImage: "person.crop.circle") {
                        try UAPPKit.showUser(session: session, authentication: account.authentication) {
                            account.updateSession($0)
                        }
                    }
                    screenButton("Sair da conta", systemImage: "rectangle.portrait.and.arrow.right") {
                        Task { await account.signOut() }
                    }
                } else {
                    screenButton("Entrar ou criar conta", systemImage: "person.badge.plus") {
                        try UAPPKit.showAuthentication(authentication: account.authentication) {
                            account.updateSession($0)
                        }
                    }
                }
            } header: {
                Text("Conta")
            } footer: {
                Text("Feedback e Roadmap usam a conta conectada; sem conta, o perfil local abaixo.")
            }

            Section {
                HStack(alignment: .top, spacing: 20) {
                    UAPPProfilePhotoPicker(
                        photo: Binding(get: { account.photo }, set: { account.setPhoto($0) }),
                        remoteURL: nil,
                        size: 72,
                        onRemove: { account.setPhoto(nil) }
                    )
                    VStack(spacing: 10) {
                        TextField("Nome", text: $account.name)
                        TextField("E-mail", text: $account.email)
                            .textContentType(.emailAddress)
                    }
                }
                HStack {
                    if account.hasProfile {
                        Button("Apagar perfil local", role: .destructive) { account.removeProfile() }
                    }
                    Spacer()
                    Button("Salvar perfil") { account.saveProfile() }
                        .disabled(!account.canSaveProfile)
                }
            } header: {
                Text("Perfil local")
            } footer: {
                Text(
                    "Nome e e-mail são enviados ao kit como identidade declarada, sem autenticar uma conta. "
                        + "A foto fica só neste Mac."
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle("UAPPKit Demo")
    }

    private func screenButton(
        _ title: String,
        systemImage: String,
        action: @escaping @MainActor () throws -> Void
    ) -> some View {
        Button {
            do {
                try action()
            } catch {
                status = error.localizedDescription
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.link)
    }

    // MARK: - Embutido

    /// Mesma tela de `showChangelog()`, colocada na navegação do próprio aplicativo.
    @ViewBuilder
    private var embeddedChangelog: some View {
        if let client = try? UAPPKit.makeClient() {
            NavigationStack {
                UAPPFeedbackScreen(client: client, mode: .changelog)
            }
        } else {
            Text("Configure o projeto em Início.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Ações

    private func save() {
        guard !DemoMockData.isEnabled else { return }
        let slug = projectSlug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slug.isEmpty else {
            status = "Informe o projeto."
            return
        }
        UserDefaults.standard.set(slug, forKey: DemoMacSettings.projectSlug)
        UAPPKit.setup(projectId: slug, locale: Locale(identifier: Locale.preferredLanguages.first ?? "pt-BR"))
        account.configure(projectId: slug)
        status = "Configuração salva."
    }

    private func testConnection() async {
        save()
        isTesting = true
        defer { isTesting = false }
        do {
            _ = try await UAPPKit.makeClient().feedbackPage(limit: 1)
            status = "Conexão funcionando."
        } catch {
            status = "Falha na conexão: \(error.localizedDescription)"
        }
    }

    /// O provedor da conta segue o projeto configurado.
    private func configureAccount() {
        account.configure(projectId: DemoMockData.isEnabled ? DemoMockData.projectSlug : DemoMacSettings.savedSlug)
    }

    /// Como no iPhone: sem conta conectada e com perfil local, o kit recebe só a identidade
    /// declarada; caso contrário, o provedor da conta.
    private func openFeedback() {
        Task {
            await account.refreshSession()
            do {
                if account.session == nil, account.hasProfile {
                    try await UAPPKit.showFeedback(identity: account.identity, accessTokenProvider: nil)
                } else {
                    try await UAPPKit.showFeedback(identity: account.identity, authentication: account.authentication)
                }
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func openRoadmap() {
        Task {
            await account.refreshSession()
            do {
                if account.session == nil, account.hasProfile {
                    try await UAPPKit.showRoadmap(identity: account.identity, accessTokenProvider: nil)
                } else {
                    try await UAPPKit.showRoadmap(identity: account.identity, authentication: account.authentication)
                }
            } catch {
                status = error.localizedDescription
            }
        }
    }
}
