import Foundation
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

final class MemoryFunnelStorage: UAPPFunnelStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func load(key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func save(_ data: Data?, key: String) {
        lock.lock()
        values[key] = data
        lock.unlock()
    }
}

final class FunnelClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ date: Date) {
        current = date
    }

    var date: Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(_ seconds: TimeInterval) {
        lock.lock()
        current = current.addingTimeInterval(seconds)
        lock.unlock()
    }
}

private let funnelConfiguration = UAPPConfiguration(
    projectId: "meu-app",
    host: URL(string: "https://example.supabase.co")!
)
private let funnelInstallationId = "0B5E7C1A-3F2D-4C8E-9A1B-000000000001"

private func makeTracker(
    storage: MemoryFunnelStorage = MemoryFunnelStorage(),
    clock: FunnelClock = FunnelClock(Date(timeIntervalSince1970: 1_800_000_000)),
    recorder: RequestRecorder = RequestRecorder(),
    status: @escaping @Sendable () -> Int = { 200 }
) -> UAPPFunnelTracker {
    UAPPFunnelTracker(
        configuration: funnelConfiguration,
        transport: StubTransport { request in
            recorder.record(request)
            return (status(), Data(#"{"ok":true}"#.utf8))
        },
        storage: storage,
        installationId: funnelInstallationId,
        appVersion: "1.2.3",
        now: { clock.date }
    )
}

private func sentEvents(_ request: URLRequest) throws -> [[String: Any]] {
    let body = try #require(request.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(json["slug"] as? String == "meu-app")
    #expect(json["installationId"] as? String == funnelInstallationId)
    return try #require(json["events"] as? [[String: Any]])
}

@Suite("UAPPFunnelEvent")
struct UAPPFunnelEventTests {
    @Test("names match the server contract")
    func names() {
        #expect(UAPPFunnelEvent.appOpened.name == "app_opened")
        #expect(UAPPFunnelEvent.paywallViewed().name == "paywall_viewed")
        #expect(UAPPFunnelEvent.purchaseStarted(productId: "a").name == "purchase_started")
        #expect(UAPPFunnelEvent.purchaseCompleted(productId: "a").name == "purchase_completed")
        #expect(UAPPFunnelEvent.purchaseCancelled(productId: "a").name == "purchase_cancelled")
        #expect(UAPPFunnelEvent.purchaseFailed(productId: "a").name == "purchase_failed")
        #expect(UAPPFunnelEvent.purchasePending(productId: "a").name == "purchase_pending")
        #expect(UAPPFunnelEvent.purchaseRestored(productId: nil).name == "purchase_restored")
    }

    @Test("source is normalized and only sent for the paywall")
    func source() {
        #expect(UAPPFunnelEvent.paywallViewed(source: " Limite Atingido ").source == "limite_atingido")
        #expect(UAPPFunnelEvent.paywallViewed(source: "   ").source == nil)
        #expect(UAPPFunnelEvent.paywallViewed(source: String(repeating: "a", count: 80)).source?.count == 64)
        #expect(UAPPFunnelEvent.appOpened.source == nil)
    }

    @Test("product id is trimmed and empty becomes nil")
    func productId() {
        #expect(UAPPFunnelEvent.purchaseStarted(productId: " app.pro.yearly ").productId == "app.pro.yearly")
        #expect(UAPPFunnelEvent.purchaseRestored(productId: " ").productId == nil)
        #expect(UAPPFunnelEvent.paywallViewed(source: "x").productId == nil)
    }
}

@Suite("UAPPFunnelTracker")
struct UAPPFunnelTrackerTests {
    @Test("records and sends a batch, then clears the queue")
    func sendsBatch() async throws {
        let recorder = RequestRecorder()
        let tracker = makeTracker(recorder: recorder)
        await tracker.record(.paywallViewed(source: "settings"))
        await tracker.record(.purchaseStarted(productId: "app.pro.monthly"))
        await tracker.flush()

        let request = try #require(recorder.requests.first)
        #expect(recorder.requests.count == 1)
        #expect(request.url?.path == "/functions/v1/public-app-events")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "x-uapp-project") == "meu-app")
        let events = try sentEvents(request)
        #expect(events.map { $0["name"] as? String } == ["paywall_viewed", "purchase_started"])
        #expect(events.first?["source"] as? String == "settings")
        #expect(events.last?["productId"] as? String == "app.pro.monthly")
        #expect(events.first?["appVersion"] as? String == "1.2.3")
        #expect(events.first?["occurredAt"] as? String == "2027-01-15T08:00:00.000Z")
        #expect(await tracker.pendingEvents().isEmpty)
    }

    @Test("keeps events when the server fails or limits")
    func keepsOnFailure() async {
        for status in [429, 500, 503] {
            let tracker = makeTracker(status: { status })
            await tracker.record(.appOpened)
            await tracker.flush()
            #expect(await tracker.pendingEvents().count == 1)
        }
    }

    @Test("keeps events when the network is down")
    func keepsOnNetworkError() async {
        let tracker = UAPPFunnelTracker(
            configuration: funnelConfiguration,
            transport: StubTransport { _ in throw TestError.expected },
            storage: MemoryFunnelStorage(),
            installationId: funnelInstallationId,
            appVersion: nil
        )
        await tracker.record(.purchaseFailed(productId: "x"))
        await tracker.flush()
        #expect(await tracker.pendingEvents().count == 1)
    }

    @Test("drops a batch the server rejects as invalid")
    func dropsRejectedBatch() async {
        let tracker = makeTracker(status: { 400 })
        await tracker.record(.purchaseCancelled(productId: "x"))
        await tracker.flush()
        #expect(await tracker.pendingEvents().isEmpty)
    }

    @Test("counts app opens at most once every 30 minutes")
    func appOpenedDebounce() async {
        let clock = FunnelClock(Date(timeIntervalSince1970: 1_800_000_000))
        let tracker = makeTracker(clock: clock)
        #expect(await tracker.record(.appOpened))
        clock.advance(10 * 60)
        #expect(await tracker.record(.appOpened) == false)
        clock.advance(25 * 60)
        #expect(await tracker.record(.appOpened))
        #expect(await tracker.pendingEvents().count == 2)
    }

    @Test("queue survives a new tracker and is capped")
    func persistenceAndCap() async {
        let storage = MemoryFunnelStorage()
        let first = makeTracker(storage: storage, status: { 500 })
        for index in 0 ..< UAPPFunnelTracker.maxQueuedEvents + 5 {
            await first.record(.paywallViewed(source: "s\(index)"))
        }
        let second = makeTracker(storage: storage)
        let pending = await second.pendingEvents()
        #expect(pending.count == UAPPFunnelTracker.maxQueuedEvents)
        #expect(pending.first?.source == "s5")
    }

    @Test("sends large queues in batches of 50")
    func batches() async {
        let recorder = RequestRecorder()
        let tracker = makeTracker(recorder: recorder)
        for _ in 0 ..< 120 {
            await tracker.record(.purchaseStarted(productId: "x"))
        }
        await tracker.flush()
        #expect(recorder.requests.count == 3)
        #expect(await tracker.pendingEvents().isEmpty)
    }

    @MainActor
    @Test("fixed-project trackers are reused per project and host")
    func fixedProjectTrackers() throws {
        let host = try #require(URL(string: "https://example.supabase.co"))
        let other = try #require(URL(string: "https://other.supabase.co"))
        let first = UAPPKit.funnelTracker(projectId: "uapp-pulse", host: host)
        #expect(UAPPKit.funnelTracker(projectId: "uapp-pulse", host: host) === first)
        #expect(UAPPKit.funnelTracker(projectId: "calcjuros", host: host) !== first)
        #expect(UAPPKit.funnelTracker(projectId: "uapp-pulse", host: other) !== first)
    }
}
