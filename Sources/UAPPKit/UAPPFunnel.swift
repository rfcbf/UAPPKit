import Foundation

/// Evento do funil de assinatura do aplicativo, enviado ao UAPP para medir quantas pessoas abrem
/// o app, veem o paywall, tocam em assinar e concluem a compra.
///
/// É anônimo: o UAPP recebe só o identificador pseudônimo da instalação (o mesmo usado pelo
/// Feedback), a versão do app, a data e o que estiver no próprio evento. Nada de nome, e-mail ou
/// conta. O aplicativo que usa estes eventos declara "Interação com o produto" (não vinculada à
/// pessoa, sem rastreamento) na privacidade da App Store.
public enum UAPPFunnelEvent: Sendable, Equatable {
    /// O app ficou ativo. Repetições em menos de 30 minutos contam uma vez só.
    case appOpened
    /// O paywall apareceu. `source` diz de onde ele foi aberto, por exemplo `"limit_reached"`,
    /// `"settings"` ou `"onboarding"`: letras minúsculas, números, `_`, `.` e `-`, até 64.
    case paywallViewed(source: String? = nil)
    /// A pessoa tocou em assinar ou comprar o produto `productId`.
    case purchaseStarted(productId: String)
    /// A App Store confirmou a compra.
    case purchaseCompleted(productId: String)
    /// A pessoa fechou a folha de pagamento sem comprar.
    case purchaseCancelled(productId: String)
    /// A compra falhou (erro da loja, rede ou verificação).
    case purchaseFailed(productId: String)
    /// A compra aguarda aprovação externa, como o Compartilhamento Familiar.
    case purchasePending(productId: String)
    /// "Restaurar compras" encontrou uma compra ativa.
    case purchaseRestored(productId: String?)

    var name: String {
        switch self {
        case .appOpened: "app_opened"
        case .paywallViewed: "paywall_viewed"
        case .purchaseStarted: "purchase_started"
        case .purchaseCompleted: "purchase_completed"
        case .purchaseCancelled: "purchase_cancelled"
        case .purchaseFailed: "purchase_failed"
        case .purchasePending: "purchase_pending"
        case .purchaseRestored: "purchase_restored"
        }
    }

    var source: String? {
        guard case let .paywallViewed(source) = self else { return nil }
        return UAPPFunnelEvent.normalizedSource(source)
    }

    var productId: String? {
        switch self {
        case .appOpened, .paywallViewed:
            nil
        case let .purchaseStarted(productId), let .purchaseCompleted(productId),
             let .purchaseCancelled(productId), let .purchaseFailed(productId),
             let .purchasePending(productId):
            UAPPFunnelEvent.normalizedProductId(productId)
        case let .purchaseRestored(productId):
            UAPPFunnelEvent.normalizedProductId(productId)
        }
    }

    /// Deixa a origem no formato aceito pelo servidor; uma origem vazia vira `nil`.
    static func normalizedSource(_ value: String?) -> String? {
        guard let value else { return nil }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_.-")
        let normalized = String(
            value.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .map { allowed.contains($0) ? $0 : "_" }
                .prefix(64)
        )
        return normalized.isEmpty ? nil : normalized
    }

    static func normalizedProductId(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty
        else { return nil }
        return String(trimmed.prefix(200))
    }
}

/// Evento guardado no aparelho até o UAPP confirmar o recebimento.
struct UAPPQueuedFunnelEvent: Codable, Sendable, Equatable {
    let id: String
    let name: String
    let source: String?
    let productId: String?
    let appVersion: String?
    let occurredAt: String

    private enum CodingKeys: String, CodingKey {
        case id, name, source, productId, appVersion, occurredAt
    }
}

/// Onde a fila de eventos fica entre aberturas do app. Substituível nos testes.
protocol UAPPFunnelStorage: Sendable {
    func load(key: String) -> Data?
    func save(_ data: Data?, key: String)
}

struct UAPPUserDefaultsFunnelStorage: UAPPFunnelStorage {
    func load(key: String) -> Data? {
        UserDefaults.standard.data(forKey: key)
    }

    func save(_ data: Data?, key: String) {
        if let data {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

/// Fila dos eventos do funil: guarda no aparelho, envia em lotes e apaga o que o UAPP aceitou.
/// Falha de rede ou servidor mantém os eventos para a próxima tentativa.
actor UAPPFunnelTracker {
    static let maxQueuedEvents = 200
    static let batchSize = 50
    static let appOpenedInterval: TimeInterval = 30 * 60

    private let configuration: UAPPConfiguration
    private let transport: UAPPTransport
    private let storage: UAPPFunnelStorage
    private let installationId: String
    private let appVersion: String?
    private let now: @Sendable () -> Date
    private var isSending = false

    init(
        configuration: UAPPConfiguration,
        transport: UAPPTransport,
        storage: UAPPFunnelStorage = UAPPUserDefaultsFunnelStorage(),
        installationId: String? = nil,
        appVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configuration = configuration
        self.transport = transport
        self.storage = storage
        self.installationId = installationId
            ?? UAPPClient.loadInstallationId(projectId: configuration.projectId)
        self.appVersion = appVersion.flatMap { String($0.prefix(32)) }
        self.now = now
    }

    private var queueKey: String {
        "uapp.funnel.queue.\(configuration.projectId)"
    }

    private var lastAppOpenedKey: String {
        "uapp.funnel.lastAppOpened.\(configuration.projectId)"
    }

    /// Eventos ainda não confirmados pelo UAPP.
    func pendingEvents() -> [UAPPQueuedFunnelEvent] {
        guard let data = storage.load(key: queueKey) else { return [] }
        return (try? JSONDecoder().decode([UAPPQueuedFunnelEvent].self, from: data)) ?? []
    }

    private func store(_ events: [UAPPQueuedFunnelEvent]) {
        let kept = Array(events.suffix(Self.maxQueuedEvents))
        storage.save(kept.isEmpty ? nil : try? JSONEncoder().encode(kept), key: queueKey)
    }

    /// Põe o evento na fila. Devolve `false` quando ele é ignorado (abertura repetida).
    @discardableResult
    func record(_ event: UAPPFunnelEvent) -> Bool {
        let date = now()
        if event == .appOpened {
            if let data = storage.load(key: lastAppOpenedKey),
               let last = try? JSONDecoder().decode(Date.self, from: data),
               date.timeIntervalSince(last) >= 0,
               date.timeIntervalSince(last) < Self.appOpenedInterval
            {
                return false
            }
            storage.save(try? JSONEncoder().encode(date), key: lastAppOpenedKey)
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let queued = UAPPQueuedFunnelEvent(
            id: UUID().uuidString.lowercased(),
            name: event.name,
            source: event.source,
            productId: event.productId,
            appVersion: appVersion,
            occurredAt: formatter.string(from: date)
        )
        store(pendingEvents() + [queued])
        return true
    }

    /// Envia a fila em lotes. Para no primeiro lote que falhar por rede, limite ou servidor.
    func flush() async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }

        while true {
            let batch = Array(pendingEvents().prefix(Self.batchSize))
            guard !batch.isEmpty else { return }
            guard let status = await send(batch) else { return }
            // 2xx: aceitos ou descartados pelo servidor. 4xx que não seja limite: o lote nunca
            // vai passar, então também sai da fila para não travar os próximos.
            let isPermanent = (200 ..< 300).contains(status)
                || ((400 ..< 500).contains(status) && status != 408 && status != 429)
            guard isPermanent else { return }
            let sentIds = Set(batch.map(\.id))
            store(pendingEvents().filter { !sentIds.contains($0.id) })
        }
    }

    private func send(_ batch: [UAPPQueuedFunnelEvent]) async -> Int? {
        var request = URLRequest(
            url: configuration.functionsBaseURL.appendingPathComponent("public-app-events")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.projectId, forHTTPHeaderField: "x-uapp-project")
        let body = UAPPFunnelRequest(
            slug: configuration.projectId,
            installationId: installationId,
            events: batch
        )
        guard let data = try? JSONEncoder().encode(body) else { return nil }
        request.httpBody = data
        do {
            let (_, http) = try await transport.send(request)
            return http.statusCode
        } catch {
            return nil
        }
    }
}

private struct UAPPFunnelRequest: Encodable {
    let slug: String
    let installationId: String
    let events: [UAPPQueuedFunnelEvent]

    private enum CodingKeys: String, CodingKey {
        case slug, installationId, events
    }
}
