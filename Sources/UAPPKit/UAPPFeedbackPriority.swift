#if canImport(SwiftUI)
import SwiftUI

/// Prioridade de uma requisição definida pela equipe do aplicativo.
/// O servidor envia um inteiro em `UAPPFeedbackItem.priority`, em que número maior é mais prioritário.
public enum UAPPFeedbackPriority: Int, Sendable, CaseIterable, Comparable {
    case low = 1
    case medium
    case high
    case veryHigh
    case important
    case urgent

    /// Nível do valor recebido; `nil` quando a requisição não tem prioridade.
    /// Valores acima do último nível contam como o mais alto.
    public init?(value: Int) {
        guard value > 0 else { return nil }
        self = Self(rawValue: value) ?? .urgent
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var localizationKey: String {
        switch self {
        case .low: "priority.low"
        case .medium: "priority.medium"
        case .high: "priority.high"
        case .veryHigh: "priority.veryHigh"
        case .important: "priority.important"
        case .urgent: "priority.urgent"
        }
    }

    /// Nome do nível no idioma de apresentação.
    public func title(languageIdentifier: String? = nil) -> String {
        languageIdentifier.map { uappLocalized(localizationKey, languageIdentifier: $0) }
            ?? uappLocalized(localizationKey)
    }

    /// Cor do selo, da mais calma à mais urgente.
    public var color: Color {
        switch self {
        case .low: .gray
        case .medium: .blue
        case .high: .yellow
        case .veryHigh: .orange
        case .important: .purple
        case .urgent: .red
        }
    }

    public var symbol: String {
        switch self {
        case .low: "arrow.down"
        case .medium: "equal"
        case .high: "arrow.up"
        case .veryHigh: "chevron.up.2"
        case .important: "exclamationmark"
        case .urgent: "flame.fill"
        }
    }
}

/// Selo com o nome e a cor da prioridade de uma requisição.
public struct UAPPFeedbackPriorityBadge: View {
    private let priority: UAPPFeedbackPriority
    private let languageIdentifier: String?

    public init(priority: UAPPFeedbackPriority, languageIdentifier: String? = nil) {
        self.priority = priority
        self.languageIdentifier = languageIdentifier
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: priority.symbol)
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(verbatim: priority.title(languageIdentifier: languageIdentifier))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(priority.color)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(priority.color.opacity(0.14), in: Capsule())
    }
}
#endif
