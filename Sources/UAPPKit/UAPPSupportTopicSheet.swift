#if canImport(SwiftUI)
import SwiftUI

/// Folha inferior com os motivos do contato; escolher um fecha a folha e abre a mensagem.
struct UAPPSupportTopicSheet: View {
    let palette: UAPPResolvedPalette
    let onSelect: (UAPPSupportTopic) -> Void
    @State private var contentHeight: CGFloat = 320

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: uappLocalized("about.support"))
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: uappLocalized("support.topic.prompt"))
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }
            .padding(.bottom, 6)
            ForEach(UAPPSupportTopic.allCases, id: \.self) { topic in
                Button {
                    onSelect(topic)
                } label: {
                    row(topic)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.primaryText)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            contentHeight = height
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
    }

    private func row(_ topic: UAPPSupportTopic) -> some View {
        HStack(spacing: 12) {
            UAPPAccentIconBadge(
                systemImage: topic.systemImage, accent: palette.accent ?? .accentColor,
                size: 34, cornerRadius: 10, font: .subheadline.weight(.semibold)
            )
            Text(verbatim: uappLocalized(topic.titleKey))
                .font(.body)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .uappCardSurface(palette)
        .contentShape(RoundedRectangle(cornerRadius: UAPPSurface.largeCornerRadius, style: .continuous))
    }
}
#endif
