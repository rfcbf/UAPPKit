#if canImport(SwiftUI)
import SwiftUI

/// Resumo das avaliações no topo da lista: média, estrelas, total e a distribuição por nota.
struct UAPPReviewSummaryCard: View {
    let summary: UAPPReviewSummary
    let palette: UAPPResolvedPalette

    /// A mesma cor das estrelas de cada avaliação da lista.
    private var accent: Color {
        palette.accent ?? .yellow
    }

    private var averageText: String {
        summary.average.formatted(.number.precision(.fractionLength(1)))
    }

    private var countText: String {
        Self.countText(summary.count)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            average
                .frame(minWidth: 104)

            Rectangle()
                .fill(palette.secondaryText.opacity(0.16))
                .frame(width: 1)
                .padding(.vertical, 4)
                .accessibilityHidden(true)

            distribution
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .uappCardSurface(palette, cornerRadius: UAPPSurface.largeCornerRadius)
    }

    private var average: some View {
        VStack(spacing: 6) {
            Text(verbatim: averageText)
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 3) {
                ForEach(1 ... 5, id: \.self) { star in
                    Image(systemName: Self.starSymbol(star, average: summary.average))
                }
            }
            .font(.footnote)
            .foregroundStyle(accent)
            Text(verbatim: countText)
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(averageText) ★ · \(countText)"))
    }

    private var distribution: some View {
        VStack(spacing: 7) {
            ForEach([5, 4, 3, 2, 1], id: \.self) { rating in
                let count = summary.distribution[String(rating)] ?? 0
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Text(verbatim: "\(rating)")
                            .monospacedDigit()
                        Image(systemName: "star.fill")
                            .imageScale(.small)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                    .frame(width: 26, alignment: .leading)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(palette.secondaryText.opacity(0.16))
                            Capsule()
                                .fill(accent)
                                .frame(width: max(count > 0 ? 6 : 0, proxy.size.width * summary.share(of: rating)))
                        }
                    }
                    .frame(height: 8)

                    Text(verbatim: count.formatted(.number))
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.secondaryText)
                        .frame(minWidth: 18, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(rating) ★"))
                .accessibilityValue(Text(verbatim: "\(count)"))
            }
        }
    }

    /// "1 avaliação" ou "20 avaliações", no idioma de apresentação.
    static func countText(_ count: Int) -> String {
        count == 1
            ? uappLocalized("reviews.count.one")
            : uappLocalizedFormat("reviews.count.other", count.formatted(.number))
    }

    /// Estrela cheia, meia ou vazia para a posição, conforme a média.
    static func starSymbol(_ star: Int, average: Double) -> String {
        if average >= Double(star) - 0.25 {
            return "star.fill"
        }
        return average >= Double(star) - 0.75 ? "star.leadinghalf.filled" : "star"
    }
}
#endif
