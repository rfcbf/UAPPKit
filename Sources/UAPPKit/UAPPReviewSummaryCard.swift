#if canImport(SwiftUI)
import SwiftUI

/// Resumo das avaliações no topo da lista: média, estrelas, total e a distribuição por nota.
struct UAPPReviewSummaryCard: View {
    let summary: UAPPReviewSummary
    let palette: UAPPResolvedPalette

    private var averageText: String {
        summary.average.formatted(.number.precision(.fractionLength(1)))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: averageText)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(palette.primaryText)
                HStack(spacing: 2) {
                    ForEach(1 ... 5, id: \.self) { star in
                        Image(systemName: Self.starSymbol(star, average: summary.average))
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.yellow)
                Text(verbatim: summary.count.formatted(.number))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(palette.secondaryText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(averageText) ★ · \(summary.count.formatted(.number))"))

            VStack(spacing: 5) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { rating in
                    HStack(spacing: 8) {
                        Text(verbatim: "\(rating)")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(palette.secondaryText)
                            .frame(width: 10)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(palette.secondaryText.opacity(0.18))
                                Capsule()
                                    .fill(Color.yellow)
                                    .frame(width: proxy.size.width * summary.share(of: rating))
                            }
                        }
                        .frame(height: 7)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "\(rating) ★"))
                    .accessibilityValue(Text(verbatim: "\(summary.distribution[String(rating)] ?? 0)"))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .uappCardSurface(palette, cornerRadius: 24)
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
