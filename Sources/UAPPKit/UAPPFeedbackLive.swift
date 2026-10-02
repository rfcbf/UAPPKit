import Foundation

struct UAPPFeedbackLiveConfiguration: Decodable, Sendable {
    let websocketURL: URL
    let apiKey: String
    let topic: String
    enum CodingKeys: String, CodingKey { case websocketURL, apiKey, topic }
}

/// Recebe apenas invalidações. Os dados continuam vindo da API pública filtrada.
enum UAPPFeedbackLive {
    static func updates(_ configuration: UAPPFeedbackLiveConfiguration) throws -> AsyncThrowingStream<Void, any Error> {
        var components = URLComponents(url: configuration.websocketURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "apikey", value: configuration.apiKey),
                                  URLQueryItem(name: "vsn", value: "1.0.0")]
        guard let url = components?.url else { throw UAPPKitError.invalidResponse }
        let socket = URLSession.shared.webSocketTask(with: url)
        let topic = "realtime:\(configuration.topic)"
        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                let health = Health()
                socket.resume()
                let heartbeat = Task {
                    do {
                        try await Task.sleep(for: .seconds(10))
                        guard await health.joined else {
                            socket.cancel(with: .goingAway, reason: nil)
                            return
                        }
                        var reference = 2
                        while !Task.isCancelled {
                            guard await health.beginHeartbeat() else {
                                socket.cancel(with: .goingAway, reason: nil)
                                return
                            }
                            try await socket.send(message(topic: "phoenix", event: "heartbeat", ref: String(reference), payload: [:]))
                            reference += 1
                            try await Task.sleep(for: .seconds(25))
                        }
                    } catch {
                        socket.cancel(with: .goingAway, reason: nil)
                    }
                }
                defer {
                    heartbeat.cancel()
                    socket.cancel(with: .goingAway, reason: nil)
                }
                do {
                    try await socket.send(message(topic: topic, event: "phx_join", ref: "1", payload: [
                        "config": ["broadcast": ["ack": false, "self": false],
                                   "presence": ["enabled": false], "private": false]
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
                socket.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    private static func message(topic: String, event: String, ref: String, payload: [String: Any]) throws -> URLSessionWebSocketTask.Message {
        var object: [String: Any] = [
            "topic": topic, "event": event, "ref": ref,
            "payload": payload
        ]
        if topic != "phoenix" { object["join_ref"] = "1" }
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
            if event == "phx_error" || event == "phx_close" { throw UAPPKitError.transport("Live channel closed") }
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
        func markJoined() { joined = true }
        func beginHeartbeat() -> Bool {
            guard !heartbeatPending else { return false }
            heartbeatPending = true
            return true
        }
        func acknowledgeHeartbeat() { heartbeatPending = false }
    }
}
