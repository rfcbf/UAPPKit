import Foundation
import SwiftUI
import Testing
@testable import UAPPKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct StubTransport: UAPPTransport {
    let handler: @Sendable (URLRequest) async throws -> (Int, Data)

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (status, data) = try await handler(request)
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: status,
                  httpVersion: nil,
                  headerFields: nil
              )
        else { throw UAPPKitError.invalidResponse }
        return (data, response)
    }
}

final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequests: [URLRequest] = []

    func record(_ request: URLRequest) {
        lock.lock()
        storedRequests.append(request)
        lock.unlock()
    }

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storedRequests
    }
}

enum TestError: Error {
    case expected
}

actor RequestGate {
    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var responseWaiter: CheckedContinuation<Void, Never>?

    func suspend() async {
        await withCheckedContinuation { continuation in
            responseWaiter = continuation
            started = true
            startWaiters.forEach { $0.resume() }
            startWaiters.removeAll()
        }
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func resume() {
        responseWaiter?.resume()
        responseWaiter = nil
    }
}

func makeClient(
    recorder: RequestRecorder? = nil,
    signatureProvider: UAPPSignatureProvider? = nil,
    locale: Locale? = nil,
    handler: @escaping @Sendable (URLRequest) async throws -> (Int, Data)
) -> UAPPClient {
    let configuration = UAPPConfiguration(
        projectId: "meu-app",
        host: URL(string: "https://exemplo.uapp.com")!,
        signatureProvider: signatureProvider,
        locale: locale
    )
    return UAPPClient(
        configuration: configuration,
        transport: StubTransport { request in
            recorder?.record(request)
            return try await handler(request)
        }
    )
}

func json(_ string: String) -> Data {
    Data(string.utf8)
}

func response(_ status: Int = 200, _ body: String) -> (Int, Data) {
    (status, json(body))
}

func response(_ body: String) -> (Int, Data) {
    response(200, body)
}

func queryItems(in request: URLRequest) -> [URLQueryItem] {
    guard let url = request.url,
          let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
    else { return [] }
    return items
}

func queryValue(_ name: String, in request: URLRequest) -> String? {
    queryItems(in: request).first { $0.name == name }?.value
}

#if canImport(UIKit)
@MainActor
func render(_ view: some View) async {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let hostingController = UIHostingController(rootView: view)
    window.rootViewController = hostingController
    window.makeKeyAndVisible()
    hostingController.view.frame = window.bounds
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()
    for _ in 0 ..< 10 {
        await Task.yield()
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
    }
    window.isHidden = true
}
#elseif canImport(AppKit)
@MainActor
func render(_ view: some View) async {
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = NSRect(x: 0, y: 0, width: 640, height: 800)
    hostingView.layoutSubtreeIfNeeded()
    _ = hostingView.fittingSize
    for _ in 0 ..< 10 {
        await Task.yield()
        hostingView.layoutSubtreeIfNeeded()
    }
}
#endif
