import Foundation

struct UAPPPagingIndicatorMetrics {
    let progress: CGFloat

    init(progress: CGFloat, count: Int) {
        self.progress = progress.isFinite ? min(max(progress, 0), CGFloat(max(0, count - 1))) : 0
    }

    private var activeIndex: Int {
        Int(progress)
    }

    private var nextIndex: Int {
        Int(progress.rounded(.awayFromZero))
    }

    private var fraction: CGFloat {
        progress - CGFloat(activeIndex)
    }

    func width(at index: Int) -> CGFloat {
        8 + (index == activeIndex ? 18 * (1 - fraction) : index == nextIndex ? 18 * fraction : 0)
    }

    func opacity(at index: Int) -> Double {
        index == activeIndex ? Double(1 - fraction) : index == nextIndex ? Double(fraction) : 0
    }
}

#if canImport(SwiftUI)
import SwiftUI

struct UAPPPagingIndicator: View {
    let count: Int
    let progress: CGFloat
    let selection: Int
    var activeTint: Color = .primary
    var inActiveTint: Color = .primary.opacity(0.15)
    var onSelect: (Int) -> Void

    var body: some View {
        if count > 1 {
            ViewThatFits(in: .horizontal) {
                indicators
                ScrollView(.horizontal, showsIndicators: false) { indicators }
            }
            .frame(height: 44)
        }
    }

    private var indicators: some View {
        let metrics = UAPPPagingIndicatorMetrics(progress: progress, count: count)
        return HStack(spacing: 10) {
            ForEach(0 ..< max(0, count), id: \.self) { index in
                Button { onSelect(index) } label: {
                    ZStack {
                        Capsule().fill(inActiveTint)
                        Capsule().fill(activeTint).opacity(metrics.opacity(at: index))
                    }
                    .frame(width: metrics.width(at: index), height: 8)
                    .frame(height: 44)
                    .contentShape(Rectangle().inset(by: -5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: uappLocalizedFormat("changelog.image_page", index + 1, count)))
                .accessibilityAddTraits(index == selection ? .isSelected : [])
            }
        }
    }
}
#endif
