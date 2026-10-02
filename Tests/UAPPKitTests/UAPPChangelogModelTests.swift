import Foundation
import SwiftUI
import Testing
@testable import UAPPKit

@Test("changelog usa o tamanho configurado na primeira página, próximas páginas e retries", arguments: [-10, 0, 1, 10, 20, 50, 100])
@MainActor
func changelogModelUsesConfiguredPageSize(pageSize: Int) async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { request in
        guard queryValue("cursor", in: request) != nil else {
            return response(#"{"entries":[{"title":"2.0","slug":"2","body_md":""}],"nextCursor":"older"}"#)
        }
        if recorder.requests.count == 2 {
            throw TestError.expected
        }
        return response(#"{"entries":[{"title":"1.0","slug":"1","body_md":""}],"nextCursor":null}"#)
    }
    let model = UAPPChangelogModel(client: client, pageSize: pageSize)
    try await model.load()
    await model.loadMore()
    #expect(model.loadMoreError != nil)
    await model.loadMore()
    let expected = min(max(pageSize, 1), 50)
    #expect(model.pageSize == expected)
    #expect(recorder.requests.count == 3)
    #expect(recorder.requests.allSatisfy { queryValue("limit", in: $0) == String(expected) })
    #expect(model.entries.count == 2)
    #expect(model.nextCursor == nil)
}

@Test("changelog carrega páginas, remove versões duplicadas e para no fim")
@MainActor
func changelogModelPaginates() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { request in
        if queryValue("cursor", in: request) == "older" {
            return response(#"{"entries":[{"title":"2.0","slug":"2","body_md":""},{"title":"1.0","slug":"1","body_md":""}],"nextCursor":null}"#)
        }
        return response(#"{"entries":[{"title":"2.0","slug":"2","body_md":""},{"title":"2.0","slug":"2","body_md":""}],"nextCursor":"older"}"#)
    }
    let model = UAPPChangelogModel(client: client)
    try await model.load()
    #expect(model.entries.map(\.slug) == ["2"])
    #expect(model.nextCursor == "older")
    await model.loadMore()
    await model.loadMore()
    #expect(model.entries.map(\.slug) == ["2", "1"])
    #expect(model.nextCursor == nil)
    #expect(!model.isLoadingMore)
    #expect(recorder.requests.count == 2)
    #expect(recorder.requests.allSatisfy { queryValue("limit", in: $0) == "10" })
}

@Test("changelog preserva versões após falha e permite tentar novamente")
@MainActor
func changelogModelRetries() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { request in
        guard queryValue("cursor", in: request) != nil else {
            return response(#"{"entries":[{"title":"2.0","slug":"2","body_md":""}],"nextCursor":"older"}"#)
        }
        if recorder.requests.count == 2 {
            throw TestError.expected
        }
        return response(#"{"entries":[{"title":"1.0","slug":"1","body_md":""}],"nextCursor":null}"#)
    }
    let model = UAPPChangelogModel(client: client)
    try await model.load()
    await model.loadMore()
    #expect(model.loadMoreError != nil)
    #expect(model.entries.count == 1)
    #expect(model.nextCursor == "older")
    await renderInNavigationStack(UAPPFeedbackScreen(client: client, mode: .changelog, testingIsLoading: false, testingChangelogModel: model))
    await model.loadMore()
    #expect(model.loadMoreError == nil)
    #expect(model.entries.count == 2)
}

@Test("changelog interrompe cursores repetidos, inclusive ciclos com páginas vazias")
@MainActor
func changelogModelStopsCursorCycles() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { request in
        switch queryValue("cursor", in: request) {
        case "a": response(#"{"entries":[],"nextCursor":"b"}"#)
        case "b": response(#"{"entries":[],"nextCursor":"a"}"#)
        default: response(#"{"entries":[],"nextCursor":"a"}"#)
        }
    }
    let model = UAPPChangelogModel(client: client)
    try await model.load()
    await model.loadMore()
    #expect(model.nextCursor == "b")
    await model.loadMore()
    await model.loadMore()
    #expect(model.nextCursor == nil)
    #expect(recorder.requests.count == 3)
    try await model.load()
    #expect(model.nextCursor == "a")
    await model.loadMore()
    #expect(model.nextCursor == "b")
    let repeatedClient = makeClient { _ in response(#"{"entries":[],"nextCursor":"same"}"#) }
    let repeated = UAPPChangelogModel(client: repeatedClient)
    try await repeated.load()
    await repeated.loadMore()
    #expect(repeated.nextCursor == nil)
}

@Test("changelog evita páginas simultâneas e exibe carregamento no rodapé")
@MainActor
func changelogModelConcurrentLoads() async throws {
    let gate = RequestGate()
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { request in
        guard queryValue("cursor", in: request) != nil else {
            return response(#"{"entries":[{"title":"2.0","slug":"2","body_md":""}],"nextCursor":"older"}"#)
        }
        await gate.suspend()
        return response(#"{"entries":[],"nextCursor":null}"#)
    }
    let model = UAPPChangelogModel(client: client)
    try await model.load()
    let task = Task { await model.loadMore() }
    await gate.waitUntilStarted()
    #expect(model.isLoadingMore)
    await model.loadMore()
    try await model.load()
    #expect(recorder.requests.count == 2)
    await renderInNavigationStack(UAPPFeedbackScreen(client: client, mode: .changelog, testingIsLoading: false, testingChangelogModel: model))
    await gate.resume()
    await task.value
    #expect(!model.isLoadingMore)
}

@Test("changelog permite recuperar erro inicial e aceita resposta antiga sem cursor")
@MainActor
func changelogModelInitialFailure() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in
        if recorder.requests.count == 1 {
            throw TestError.expected
        }
        return response(#"{"entries":[]}"#)
    }
    let model = UAPPChangelogModel(client: client)
    await #expect(throws: TestError.self) { try await model.load() }
    try await model.load()
    #expect(model.entries.isEmpty)
    #expect(model.nextCursor == nil)
}
