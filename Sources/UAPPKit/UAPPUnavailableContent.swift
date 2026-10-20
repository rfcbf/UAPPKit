#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Situação ilustrada pelo mascote nas telas do UAPPKit.
public enum UAPPMascotState: Sendable {
    case unavailable
    case emptyFeedback
    case connectionError
    case emptyChangelog
    case success

    fileprivate var resourceName: String {
        switch self {
        case .unavailable: "UAPPMascotPrototype"
        case .emptyFeedback: "UAPPMascotEmptyFeedback"
        case .connectionError: "UAPPMascotConnectionError"
        case .emptyChangelog: "UAPPMascotEmptyChangelog"
        case .success: "UAPPMascotSuccess"
        }
    }
}

/// Ilustração do mascote para estados vazios, falhas e confirmações.
public struct UAPPMascotIllustration: View {
    private let state: UAPPMascotState
    private let width: CGFloat

    public init(state: UAPPMascotState) {
        self.init(state: state, width: 144)
    }

    /// Largura reduzida para estados em linha, como colunas vazias do Roadmap.
    init(state: UAPPMascotState, width: CGFloat) {
        self.state = state
        self.width = width
    }

    public var body: some View {
        Group {
            #if canImport(UIKit)
            if let url = Bundle.module.url(forResource: state.resourceName, withExtension: "png"),
               let image = UIImage(contentsOfFile: url.path)
            {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: width, height: width * 1.5)
            }
            #elseif canImport(AppKit)
            if let url = Bundle.module.url(forResource: state.resourceName, withExtension: "png"),
               let image = NSImage(contentsOf: url)
            {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: width, height: width * 1.5)
            }
            #endif
        }
        .accessibilityHidden(true)
    }
}

struct UAPPUnavailableContent: View {
    let message: String
    let accentColor: Color
    var mascotState: UAPPMascotState = .unavailable
    let retry: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    var body: some View {
        UAPPStateCard {
            VStack(spacing: 18) {
                UAPPMascotIllustration(state: mascotState)

                Text(verbatim: uappLocalized("unavailable.title"))
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.body)
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)

                Button {
                    retry()
                } label: {
                    UAPPPrimaryButtonLabel(
                        title: uappLocalized("common.retry"),
                        systemImage: "arrow.clockwise",
                        accent: palette.accent ?? accentColor,
                        palette: palette
                    )
                    .frame(maxWidth: 280)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct UAPPStateCard<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: 520)
            .padding(24)
            .uappEmptyStateSurface(palette)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 16)
    }
}

extension Color {
    init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct UAPPEmptyContent: View {
    let mascotState: UAPPMascotState
    let title: Text
    let message: Text
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    init(mascotState: UAPPMascotState, title: String, message: String) {
        self.mascotState = mascotState
        self.title = Text(verbatim: title)
        self.message = Text(verbatim: message)
    }

    init(mascotState: UAPPMascotState, titleKey: String, messageKey: String) {
        self.mascotState = mascotState
        title = Text(verbatim: uappLocalized(titleKey))
        message = Text(verbatim: uappLocalized(messageKey))
    }

    var body: some View {
        UAPPStateCard {
            VStack(spacing: 12) {
                UAPPMascotIllustration(state: mascotState)

                title
                    .font(.headline)
                    .multilineTextAlignment(.center)

                message
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
#endif
