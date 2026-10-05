import Foundation
import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import UAPPKit

private let liveItemId = "00000000-0000-4000-8000-000000000001"

@Test("canal do aplicativo acompanha listas vazias sem depender de um feedback")
func liveConfigurationSubscribesToApp() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in
        response(#"{"websocketURL":"wss://exemplo.uapp.com/realtime/v1/websocket","apiKey":"public-key","topic":"uapp-feedback-app:meu-app"}"#)
    }
    let configuration = try await client.feedbackLiveConfiguration()
    let request = try #require(recorder.requests.first)
    #expect(queryValue("itemId", in: request) == nil)
    #expect(queryValue("slug", in: request) == "meu-app")
    #expect(configuration.topic == "uapp-feedback-app:meu-app")
}

@Test("configuração live identifica o feedback sem enviar token pessoal")
func liveConfigurationUsesPublicAPI() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in
        response(#"{"websocketURL":"wss://exemplo.uapp.com/realtime/v1/websocket","apiKey":"public-key","topic":"uapp-feedback:00000000-0000-4000-8000-000000000001"}"#)
    }
    let configuration = try await client.feedbackLiveConfiguration(itemId: liveItemId)
    let request = try #require(recorder.requests.first)
    #expect(request.url?.lastPathComponent == "public-feedback-live")
    #expect(queryValue("itemId", in: request) == liveItemId)
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(configuration.topic == "uapp-feedback:\(liveItemId)")
}

@Test("configuração live não permite outro host ou outro feedback")
func liveConfigurationRejectsDifferentDestination() async {
    let client = makeClient { _ in
        response(#"{"websocketURL":"wss://other.example.test/realtime/v1/websocket","apiKey":"public-key","topic":"uapp-feedback:other"}"#)
    }
    await #expect(throws: UAPPKitError.invalidResponse) {
        try await client.feedbackLiveConfiguration(itemId: liveItemId)
    }
}

@Test("invalidações live reconhecem publicação, ignoram outros eventos e detectam desconexão")
func liveFramesReconcilePublicChanges() throws {
    let decoder = JSONDecoder()
    func frame(_ json: String) throws -> UAPPFeedbackLive.Frame {
        try decoder.decode(UAPPFeedbackLive.Frame.self, from: Data(json.utf8))
    }
    #expect(try frame(#"{"topic":"realtime:item","event":"broadcast","payload":{"event":"changed","payload":{}}}"#).action() == .changed)
    #expect(try frame(#"{"topic":"realtime:item","event":"broadcast","payload":{"event":"other"}}"#).action() == .ignore)
    #expect(try frame(#"{"topic":"realtime:item","event":"phx_reply","ref":"1","payload":{"status":"ok"}}"#).action() == .joined)
    #expect(throws: UAPPKitError.self) {
        try frame(#"{"topic":"realtime:item","event":"phx_reply","ref":"1","payload":{"status":"error"}}"#).action()
    }
    #expect(throws: UAPPKitError.self) {
        try frame(#"{"topic":"realtime:item","event":"phx_close"}"#).action()
    }
}

/// WebSocket roteirizado: entrega as mensagens na ordem e registra o que foi enviado.
private final class ScriptedSocket: UAPPLiveSocket, @unchecked Sendable {
    private let lock = NSLock()
    private var script: [URLSessionWebSocketTask.Message]
    private let holdsOpen: Bool
    private(set) var sent: [String] = []
    private(set) var resumed = false
    private(set) var closed = false

    init(_ script: [URLSessionWebSocketTask.Message], holdsOpen: Bool = false) {
        self.script = script
        self.holdsOpen = holdsOpen
    }

    func resume() {
        lock.withLock { resumed = true }
    }

    func close() {
        lock.withLock { closed = true }
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        if case let .string(value) = message {
            lock.withLock { sent.append(value) }
        }
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        if let next = lock.withLock({ script.isEmpty ? nil : script.removeFirst() }) {
            return next
        }
        if holdsOpen {
            while !Task.isCancelled {
                try await Task.sleep(for: .milliseconds(5))
            }
            throw CancellationError()
        }
        throw URLError(.networkConnectionLost)
    }
}

private let liveConfiguration = UAPPFeedbackLiveConfiguration(
    websocketURL: URL(string: "wss://exemplo.uapp.com/realtime/v1/websocket")!,
    apiKey: "public-key",
    topic: "uapp-feedback-app:meu-app"
)

private func frame(_ json: String, binary: Bool = false) -> URLSessionWebSocketTask.Message {
    binary ? .data(Data(json.utf8)) : .string(json)
}

@Test("canal live entra no tópico, ignora outros eventos e sinaliza publicações")
func liveStreamYieldsJoinAndChanges() async throws {
    let socket = ScriptedSocket([
        frame(#"{"topic":"realtime:uapp-feedback-app:meu-app","event":"phx_reply","ref":"1","payload":{"status":"ok"}}"#),
        frame(#"{"topic":"phoenix","event":"phx_reply","ref":"2","payload":{"status":"ok"}}"#),
        frame(#"{"topic":"realtime:outro","event":"broadcast","payload":{"event":"changed"}}"#),
        frame(#"{"topic":"realtime:uapp-feedback-app:meu-app","event":"presence_state"}"#),
        frame(#"{"topic":"realtime:uapp-feedback-app:meu-app","event":"broadcast","payload":{"event":"changed"}}"#, binary: true)
    ])
    var requested: URL?
    let stream = try UAPPFeedbackLive.updates(liveConfiguration) { url in
        requested = url
        return socket
    }
    var signals = 0
    do {
        for try await _ in stream {
            signals += 1
        }
        Issue.record("O fim do roteiro deveria encerrar com erro")
    } catch {
        #expect(error is URLError)
    }
    #expect(signals == 2)
    #expect(socket.resumed)
    #expect(socket.closed)
    #expect(socket.sent.first?.contains("phx_join") == true)
    let query = try URLComponents(url: #require(requested), resolvingAgainstBaseURL: false)?.queryItems
    #expect(query?.contains(URLQueryItem(name: "apikey", value: "public-key")) == true)
}

@Test("canal live encerra com erro quando a inscrição é recusada")
func liveStreamFailsOnRejectedJoin() async throws {
    let socket = ScriptedSocket([
        frame(#"{"topic":"realtime:uapp-feedback-app:meu-app","event":"phx_reply","ref":"1","payload":{"status":"error"}}"#)
    ])
    let stream = try UAPPFeedbackLive.updates(liveConfiguration) { _ in socket }
    await #expect(throws: UAPPKitError.transport("Live subscription unavailable")) {
        for try await _ in stream {}
    }
}

@Test("heartbeat é enviado após entrar e a conexão fecha quando não há resposta")
func liveStreamHeartbeatClosesStaleConnection() async throws {
    let socket = ScriptedSocket([
        frame(#"{"topic":"realtime:uapp-feedback-app:meu-app","event":"phx_reply","ref":"1","payload":{"status":"ok"}}"#)
    ], holdsOpen: true)
    let stream = try UAPPFeedbackLive.updates(
        liveConfiguration, heartbeatDelay: .milliseconds(1), heartbeatInterval: .milliseconds(1)
    ) { _ in socket }
    let consumer = Task { for try await _ in stream {} }
    for _ in 0 ..< 200 where !socket.closed {
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(socket.sent.contains { $0.contains("heartbeat") })
    #expect(socket.closed)
    consumer.cancel()
    _ = await consumer.result
}

@Test("sem confirmação de entrada o heartbeat fecha a conexão")
func liveStreamClosesWithoutJoin() async throws {
    let socket = ScriptedSocket([], holdsOpen: true)
    let stream = try UAPPFeedbackLive.updates(liveConfiguration, heartbeatDelay: .milliseconds(1)) { _ in socket }
    let consumer = Task { for try await _ in stream {} }
    for _ in 0 ..< 200 where !socket.closed {
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(socket.closed)
    #expect(!socket.sent.contains { $0.contains("heartbeat") })
    consumer.cancel()
    _ = await consumer.result
}

@MainActor
private final class ChangeCounter {
    var count = 0
}

@Test("modificador live recarrega ao receber invalidações, reconecta e mantém atualização periódica")
@MainActor
func liveModifierRefreshesOnChanges() async {
    let client = makeClient { _ in
        response(#"{"websocketURL":"wss://exemplo.uapp.com/realtime/v1/websocket","apiKey":"public-key","topic":"uapp-feedback-app:meu-app"}"#)
    }
    let counter = ChangeCounter()
    var connections = 0
    let modifier = UAPPFeedbackLiveModifier(
        client: client,
        onChange: { counter.count += 1 },
        updates: { _ in
            connections += 1
            return AsyncThrowingStream { continuation in
                continuation.yield(())
                continuation.yield(())
                continuation.finish(throwing: URLError(.networkConnectionLost))
            }
        },
        debounce: .milliseconds(1), reconnectDelay: .milliseconds(1), fallbackInterval: .milliseconds(5)
    )
    await render(Text("Lista").modifier(modifier).environment(\.scenePhase, .active), settling: true) {
        #if canImport(UIKit)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        await Task.yield()
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        #endif
    }
    #expect(counter.count >= 3)
    #expect(connections >= 1)
}

@Test("modificador live sem cliente não consulta nem recarrega")
@MainActor
func liveModifierWithoutClientIsIdle() async {
    let counter = ChangeCounter()
    await render(Text("Changelog").modifier(UAPPFeedbackLiveModifier(client: nil) { counter.count += 1 }), settling: true)
    #expect(counter.count == 0)
}
