import Foundation

struct UAPPFeedbackLiveConfiguration: Decodable, Sendable {
    let websocketURL: URL
    let apiKey: String
    let topic: String
    enum CodingKeys: String, CodingKey { case websocketURL, apiKey, topic }
}

/// Conexão WebSocket usada pelas invalidações; substituível nos testes.
protocol UAPPLiveSocket: Sendable {
    func resume()
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
    func close()
}

struct URLSessionLiveSocket: UAPPLiveSocket {
    let task: URLSessionWebSocketTask

    func resume() {
        task.resume()
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        try await task.send(message)
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        try await task.receive()
    }

    func close() {
        task.cancel(with: .goingAway, reason: nil)
    }
}

/// Recebe apenas invalidações. Os dados continuam vindo da API pública filtrada.
enum UAPPFeedbackLive {
    static func updates(
        _ configuration: UAPPFeedbackLiveConfiguration,
        heartbeatDelay: Duration = .seconds(10),
        heartbeatInterval: Duration = .seconds(25),
        makeSocket: (URL) -> any UAPPLiveSocket = { URLSessionLiveSocket(task: URLSession.shared.webSocketTask(with: $0)) }
    ) throws -> AsyncThrowingStream<Void, any Error> {
        var components = URLComponents(url: configuration.websocketURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "apikey", value: configuration.apiKey),
            URLQueryItem(name: "vsn", value: "1.0.0")
        ]
        guard let url = components?.url else { throw UAPPKitError.invalidResponse }
        let socket = makeSocket(url)
        let topic = "realtime:\(configuration.topic)"
        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                let health = Health()
                socket.resume()
                let heartbeat = Task {
                    do {
                        try await Task.sleep(for: heartbeatDelay)
                        guard await health.joined else {
                            socket.close()
                            return
                        }
                        var reference = 2
                        while !Task.isCancelled {
                            guard await health.beginHeartbeat() else {
                                socket.close()
                                return
                            }
                            try await socket.send(message(topic: "phoenix", event: "heartbeat", ref: String(reference), payload: [:]))
                            reference += 1
                            try await Task.sleep(for: heartbeatInterval)
                        }
                    } catch {
                        socket.close()
                    }
                }
                defer {
                    heartbeat.cancel()
                    socket.close()
                }
                do {
                    try await socket.send(message(topic: topic, event: "phx_join", ref: "1", payload: [
                        "config": [
                            "broadcast": ["ack": false, "self": false],
                            "presence": ["enabled": false],
                            "private": false
                        ]
                    ]))
                    while !Task.isCancelled {
                        let received = try await socket.receive()
                        let data: Data
                        switch received {
                        case let .string(value): data = Data(value.utf8)
                        case let .data(value): data = value
                        @unknown default: continue
                        }
                        let frame = try JSONDecoder().decode(Frame.self, from: data)
                        if frame.topic == "phoenix", frame.event == "phx_reply" {
                            await health.acknowledgeHeartbeat()
                        }
                        guard frame.topic == topic else { continue }
                        switch try frame.action() {
                        case .joined:
                            await health.markJoined()
                            continuation.yield(()) // Reconcile changes during the connection handshake.
                        case .changed: continuation.yield(())
                        case .ignore: break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                socket.close()
            }
        }
    }

    private static func message(topic: String, event: String, ref: String, payload: [String: Any]) throws -> URLSessionWebSocketTask.Message {
        var object: [String: Any] = [
            "topic": topic, "event": event, "ref": ref,
            "payload": payload
        ]
        if topic != "phoenix" {
            object["join_ref"] = "1"
        }
        let data = try JSONSerialization.data(withJSONObject: object)
        return .string(String(decoding: data, as: UTF8.self))
    }

    struct Frame: Decodable {
        let topic: String
        let event: String
        let ref: String?
        let payload: Payload?

        struct Payload: Decodable {
            let status: String?
            let event: String?
        }

        enum Action: Equatable { case joined, changed, ignore }

        func action() throws -> Action {
            if event == "phx_error" || event == "phx_close" {
                throw UAPPKitError.transport("Live channel closed")
            }
            if event == "phx_reply", ref == "1" {
                guard payload?.status == "ok" else { throw UAPPKitError.transport("Live subscription unavailable") }
                return .joined
            }
            return event == "broadcast" && payload?.event == "changed" ? .changed : .ignore
        }
    }

    private actor Health {
        private(set) var joined = false
        private var heartbeatPending = false
        func markJoined() {
            joined = true
        }

        func beginHeartbeat() -> Bool {
            guard !heartbeatPending else { return false }
            heartbeatPending = true
            return true
        }

        func acknowledgeHeartbeat() {
            heartbeatPending = false
        }
    }
}
