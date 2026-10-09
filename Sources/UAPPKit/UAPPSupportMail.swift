import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Motivo do contato, usado no assunto da mensagem de suporte.
enum UAPPSupportTopic: String, CaseIterable, Sendable {
    case question
    case problem
    case suggestion

    var titleKey: String {
        "support.topic.\(rawValue)"
    }

    var systemImage: String {
        switch self {
        case .question: "questionmark.circle"
        case .problem: "exclamationmark.triangle"
        case .suggestion: "lightbulb"
        }
    }
}

/// Sistema e modelo do aparelho, anexados à mensagem para agilizar o atendimento.
struct UAPPSupportDevice: Sendable, Equatable {
    /// Nome e versão do sistema, como `iOS 18.2`.
    let system: String
    /// Identificador do modelo, como `iPhone17,1`.
    let model: String

    @MainActor
    static func current() -> UAPPSupportDevice {
        #if canImport(UIKit)
        let system = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let system = "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #endif
        return UAPPSupportDevice(system: system, model: modelIdentifier())
    }

    static func modelIdentifier() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !simulated.isEmpty {
            return simulated
        }
        #if os(macOS)
        let name = "hw.model"
        #else
        let name = "hw.machine"
        #endif
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return "" }
        return String(decoding: value.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

/// Monta a mensagem de suporte: destinatário, assunto com o nome do app e corpo com os dados
/// do aplicativo e do aparelho.
enum UAPPSupportMail {
    /// E-mail aparado quando tem formato aceitável; qualquer outro valor vira `nil`.
    static func address(_ value: String?) -> String? {
        let email = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, email.contains("@"), !email.contains(" ") else { return nil }
        return email
    }

    /// `[App] [Motivo] - `, pronto para a pessoa completar.
    static func subject(appName: String, topic: UAPPSupportTopic, languageIdentifier: String) -> String {
        let title = uappLocalized(topic.titleKey, languageIdentifier: languageIdentifier)
        return "[\(appName)] [\(title)] - "
    }

    /// Espaço para a mensagem, seguido dos dados que ajudam a reproduzir o problema.
    static func body(
        metadata: UAPPAppMetadata,
        device: UAPPSupportDevice,
        languageIdentifier: String
    ) -> String {
        func label(_ key: String) -> String {
            uappLocalized(key, languageIdentifier: languageIdentifier)
        }
        let app = [metadata.name, metadata.versionText].compactMap(\.self).joined(separator: " ")
        var lines = [
            "",
            "",
            "----------",
            label("support.mail.hint"),
            "\(label("support.mail.app")): \(app)",
            "\(label("support.mail.system")): \(device.system)"
        ]
        if !device.model.isEmpty {
            lines.append("\(label("support.mail.device")): \(device.model)")
        }
        lines.append("\(label("support.mail.language")): \(languageIdentifier)")
        return lines.joined(separator: "\r\n")
    }

    static func url(
        email: String,
        metadata: UAPPAppMetadata,
        topic: UAPPSupportTopic,
        device: UAPPSupportDevice,
        languageIdentifier: String
    ) -> URL? {
        guard let address = address(email) else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(
                name: "subject",
                value: subject(appName: metadata.name, topic: topic, languageIdentifier: languageIdentifier)
            ),
            URLQueryItem(
                name: "body",
                value: body(metadata: metadata, device: device, languageIdentifier: languageIdentifier)
            )
        ]
        return components.url
    }
}
