import Foundation
import Testing
@testable import UAPPKit

@Test("Reviews mantém tamanho configurado em todas as páginas e retries", arguments: [-10, 0, 1, 10, 20, 50, 100])
@MainActor
func reviewsModelUsesConfiguredPageSize(pageSize: Int) async {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { request in
        guard queryValue("cursor", in: request) != nil else {
            return response(#"{"reviews":[{"id":"1","rating":5}],"nextCursor":"next"}"#)
        }
        if recorder.requests.count == 2 {
            throw TestError.expected
        }
        return response(#"{"reviews":[{"id":"2","rating":4}],"nextCursor":null}"#)
    }
    let model = UAPPReviewsModel(client: client, pageSize: pageSize)
    await model.loadIfNeeded()
    await model.loadMore()
    #expect(model.hasMoreError)
    await model.loadMore()
    let expected = String(min(max(pageSize, 1), 50))
    #expect(recorder.requests.count == 3)
    #expect(recorder.requests.allSatisfy { queryValue("limit", in: $0) == expected })
    #expect(model.reviews.count == 2)
    #expect(model.nextCursor == nil)
}

@Test("Reviews carrega páginas de 20, remove duplicatas e para no fim")
@MainActor
func reviewsModelPaginates() async {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { request in
        if queryValue("cursor", in: request) == "next" {
            return response(#"{"reviews":[{"id":"1","rating":5},{"id":"2","rating":4}],"nextCursor":null}"#)
        }
        return response(#"{"reviews":[{"id":"1","rating":5}],"nextCursor":"next"}"#)
    }
    let model = UAPPReviewsModel(client: client)
    await model.loadIfNeeded()
    await model.loadIfNeeded()
    #expect(model.reviews.map(\.id) == ["1"])
    #expect(model.nextCursor == "next")
    await model.loadMore()
    await model.loadMore()
    #expect(model.reviews.map(\.id) == ["1", "2"])
    #expect(model.nextCursor == nil)
    #expect(!model.isLoading && !model.isLoadingMore)
    #expect(recorder.requests.count == 2)
    #expect(recorder.requests.allSatisfy { queryValue("limit", in: $0) == "20" })
    #expect(queryValue("cursor", in: recorder.requests[1]) == "next")
}

@Test("Reviews preserva conteúdo ao falhar próxima página e permite repetir")
@MainActor
func reviewsModelRetriesNextPage() async {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { request in
        guard queryValue("cursor", in: request) != nil else {
            return response(#"{"reviews":[{"id":"1","rating":5}],"nextCursor":"next"}"#)
        }
        if recorder.requests.count == 2 {
            throw TestError.expected
        }
        return response(#"{"reviews":[{"id":"2","rating":4}],"nextCursor":null}"#)
    }
    let model = UAPPReviewsModel(client: client)
    await model.loadIfNeeded()
    await model.loadMore()
    #expect(model.hasMoreError)
    #expect(!model.hasError)
    #expect(model.reviews.map(\.id) == ["1"])
    #expect(model.nextCursor == "next")
    await model.loadMore()
    #expect(!model.hasMoreError)
    #expect(model.reviews.count == 2)
}

@Test("Reviews recupera falha inicial e aceita endpoint legado sem cursor")
@MainActor
func reviewsModelRetriesInitialPage() async {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in
        if recorder.requests.count == 1 {
            return response(500, #"{"error":"Falha"}"#)
        }
        return response(#"{"reviews":[]}"#)
    }
    let model = UAPPReviewsModel(client: client)
    await model.loadIfNeeded()
    #expect(model.hasError)
    #expect(!model.isLoading)
    await model.load()
    #expect(!model.hasError)
    #expect(model.reviews.isEmpty)
    #expect(model.nextCursor == nil)
}

@Test("Reviews interrompe paginação com cursor repetido")
@MainActor
func reviewsModelStopsRepeatedCursor() async {
    let client = makeClient { _ in response(#"{"reviews":[{"id":"1","rating":5}],"nextCursor":"same"}"#) }
    let model = UAPPReviewsModel(client: client)
    await model.loadIfNeeded()
    await model.loadMore()
    #expect(model.nextCursor == nil)
    #expect(model.reviews.count == 1)
}

@Test("Reviews evita requisições simultâneas da próxima página")
@MainActor
func reviewsModelPreventsConcurrentLoads() async {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { request in
        guard queryValue("cursor", in: request) != nil else {
            return response(#"{"reviews":[{"id":"1","rating":5}],"nextCursor":"next"}"#)
        }
        await Task.yield()
        return response(#"{"reviews":[{"id":"2","rating":4}],"nextCursor":null}"#)
    }
    let model = UAPPReviewsModel(client: client)
    await model.loadIfNeeded()
    async let first: Void = model.loadMore()
    async let second: Void = model.loadMore()
    _ = await (first, second)
    #expect(recorder.requests.count == 2)
    #expect(model.reviews.map(\.id) == ["1", "2"])
}
