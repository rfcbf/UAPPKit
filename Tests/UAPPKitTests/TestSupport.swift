import Foundation
import ImageIO
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

actor StubAuthentication: UAPPAuthenticationProvider {
    nonisolated let methods: [UAPPLoginMethod] = [.apple, .google, .github, .email]
    var session: UAPPAuthenticationSession?
    var error: UAPPAuthenticationError?
    var sessionFails = false
    var requestedEmail: String?

    func setSession(_ session: UAPPAuthenticationSession?) {
        self.session = session
    }

    func setError(_ error: UAPPAuthenticationError?) {
        self.error = error
    }

    func setSessionFails(_ value: Bool) {
        sessionFails = value
    }

    func currentSession() throws -> UAPPAuthenticationSession? {
        if sessionFails {
            throw TestError.expected
        }
        return session
    }

    func signIn(method _: UAPPLoginMethod) throws -> UAPPAuthenticationSession {
        if let error {
            throw error
        }
        let session = UAPPAuthenticationSession(
            identity: UAPPIdentity(userId: "verified", email: "person@example.test", displayName: "Pessoa"),
            accessToken: "verified-token"
        )
        self.session = session
        return session
    }

    func requestEmailCode(email: String) throws {
        if let error {
            throw error
        }
        requestedEmail = email
    }

    func verifyEmailCode(email _: String, code _: String) throws -> UAPPAuthenticationSession {
        try signIn(method: .email)
    }

    func signOut() throws {
        if let error {
            throw error
        }
        session = nil
    }
}

final class AuthenticationClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 1000)

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return date
    }

    func advance() {
        lock.lock()
        date = date.addingTimeInterval(4000)
        lock.unlock()
    }
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
func render(
    _ view: some View, settling: Bool = false,
    whileVisible interaction: (@MainActor () async -> Void)? = nil
) async {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let hostingController = UIHostingController(rootView: testable(view))
    window.rootViewController = hostingController
    window.makeKeyAndVisible()
    hostingController.view.frame = window.bounds
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()
    if let interaction {
        await Task.yield()
        await interaction()
    }
    for _ in 0 ..< (settling ? 40 : 10) {
        await settle(settling)
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
    }
    window.isHidden = true
}
#elseif canImport(AppKit)
@MainActor
func render(
    _ view: some View, settling: Bool = false,
    whileVisible interaction: (@MainActor () async -> Void)? = nil
) async {
    let hostingView = NSHostingView(rootView: testable(view))
    hostingView.frame = NSRect(x: 0, y: 0, width: 640, height: 800)
    hostingView.layoutSubtreeIfNeeded()
    _ = hostingView.fittingSize
    if let interaction {
        await Task.yield()
        await interaction()
    }
    for _ in 0 ..< (settling ? 40 : 10) {
        await settle(settling)
        hostingView.layoutSubtreeIfNeeded()
    }
}
#endif

/// O framework Translation não está disponível no runner de testes e registraria erros no console.
@MainActor
private func testable(_ view: some View) -> some View {
    view.environment(\.uappSystemTranslationEnabled, false)
}

/// Com `settling`, dá tempo para as tarefas da tela consumirem o transporte falso.
@MainActor
private func settle(_ settling: Bool) async {
    if settling {
        try? await Task.sleep(nanoseconds: 2_000_000)
    } else {
        await Task.yield()
    }
}

/// Telas com `navigationDestination` precisam de uma pilha de navegação,
/// como acontece no app hospedeiro e em `UAPPKit.present`.
@MainActor
func renderInNavigationStack(_ view: some View, settling: Bool = false) async {
    await render(NavigationStack { view }, settling: settling)
}

/// JPEG sólido gerado em memória para testes de imagem sem arquivos externos.
func sampleJPEG(width: Int = 64, height: Int = 48) -> Data {
    guard let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return Data() }
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let output = NSMutableData()
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil)
    else { return Data() }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination) ? output as Data : Data()
}

/// Grava os dados em um arquivo temporário local, para imagens carregadas por URL sem rede.
func temporaryFile(_ data: Data, extension pathExtension: String = "jpg") throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("uappkit-\(UUID().uuidString)")
        .appendingPathExtension(pathExtension)
    try data.write(to: url)
    return url
}
