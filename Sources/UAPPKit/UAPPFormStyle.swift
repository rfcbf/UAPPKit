#if canImport(SwiftUI)
import SwiftUI

/// Componentes visuais compartilhados pelas telas nativas, na mesma linguagem do
/// compositor de feedback: ícones sobre fundo de destaque, cartões com borda
/// suave, campos com borda de foco, banners de aviso e botões com ícone.
enum UAPPSurface {
    static let cornerRadius: CGFloat = 14
    static let largeCornerRadius: CGFloat = 16

    static func accentFillOpacity(_ colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? 0.22 : 0.12
    }

    static func selectionFillOpacity(_ colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? 0.2 : 0.1
    }
}

/// Ícone SF sobre um fundo arredondado com a cor de destaque.
struct UAPPAccentIconBadge: View {
    let systemImage: String
    let accent: Color
    var size: CGFloat = 52
    var cornerRadius: CGFloat = 16
    var font: Font = .title2.weight(.semibold)
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(systemName: systemImage)
            .font(font)
            .foregroundStyle(accent)
            .frame(width: size, height: size)
            .background(
                accent.opacity(UAPPSurface.accentFillOpacity(colorScheme)),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

/// Banner de erro ou aviso com ícone e fundo tingido.
struct UAPPInlineBanner: View {
    enum Style {
        case error
        case notice
        case success
    }

    let message: String
    var style: Style = .error
    var accent: Color = .accentColor
    @Environment(\.colorScheme) private var colorScheme

    private var tint: Color {
        switch style {
        case .error: .red
        case .notice: accent
        case .success: .green
        }
    }

    private var symbol: String {
        switch style {
        case .error: "exclamationmark.triangle.fill"
        case .notice: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        }
    }

    var body: some View {
        Label {
            Text(verbatim: message)
                .foregroundStyle(style == .error ? AnyShapeStyle(Color.red) : AnyShapeStyle(HierarchicalShapeStyle.primary))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
        }
        .font(.subheadline)
        .multilineTextAlignment(.leading)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            tint.opacity(colorScheme == .dark ? 0.18 : 0.08),
            in: RoundedRectangle(cornerRadius: UAPPSurface.cornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Fundo de campo em cartão, com borda de destaque quando focado.
struct UAPPFieldBackground: View {
    let isFocused: Bool
    let accent: Color
    let palette: UAPPResolvedPalette
    var cornerRadius: CGFloat = UAPPSurface.cornerRadius

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(palette.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isFocused ? accent : palette.separator.opacity(0.5),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            }
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

/// Rótulo do botão principal: cor de destaque, ícone e progresso no lugar do ícone.
struct UAPPPrimaryButtonLabel: View {
    let title: String
    var systemImage: String?
    var isBusy = false
    let accent: Color
    let palette: UAPPResolvedPalette

    var body: some View {
        HStack(spacing: 10) {
            if isBusy {
                ProgressView().tint(palette.buttonText)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            Text(verbatim: title)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 52)
        .foregroundStyle(palette.buttonText)
        .background(accent, in: RoundedRectangle(cornerRadius: UAPPSurface.largeCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: UAPPSurface.largeCornerRadius, style: .continuous))
    }
}

/// Rótulo de botão secundário: texto de destaque sobre fundo tingido.
struct UAPPSecondaryButtonLabel: View {
    let title: String
    var systemImage: String?
    let accent: Color
    var expands = true
    var minHeight: CGFloat = 52
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            Text(verbatim: title)
                .multilineTextAlignment(.center)
        }
        .font(expands ? .headline : .subheadline.weight(.semibold))
        .foregroundStyle(accent)
        .padding(.horizontal, 16)
        .frame(maxWidth: expands ? .infinity : nil, minHeight: minHeight)
        .background(
            accent.opacity(UAPPSurface.selectionFillOpacity(colorScheme)),
            in: RoundedRectangle(
                cornerRadius: expands ? UAPPSurface.largeCornerRadius : UAPPSurface.cornerRadius,
                style: .continuous
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: UAPPSurface.largeCornerRadius, style: .continuous))
    }
}

/// Cabeçalho de seção com título semibold e detalhe opcional à direita.
struct UAPPSectionHeader: View {
    let title: String
    var detail: String?
    let palette: UAPPResolvedPalette
    var font: Font = .subheadline.weight(.semibold)

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: title)
                .font(font)
                .foregroundStyle(palette.primaryText)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let detail {
                Text(verbatim: detail)
                    .monospacedDigit()
                    .font(.footnote)
                    .foregroundStyle(palette.secondaryText)
            }
        }
    }
}

extension View {
    /// Cartão com fundo da paleta e borda suave, como os cartões do compositor.
    func uappCardSurface(
        _ palette: UAPPResolvedPalette,
        cornerRadius: CGFloat = UAPPSurface.largeCornerRadius
    ) -> some View {
        background(
            palette.cardBackground,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(palette.separator.opacity(0.5), lineWidth: 1)
        }
    }
}
#endif
