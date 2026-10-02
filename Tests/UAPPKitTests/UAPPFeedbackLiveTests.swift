import Foundation
import Testing
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
