#if os(iOS)
import SwiftUI

@available(iOS 17, *)
struct UAPPChangelogParallaxCarousel: View {
    let items: [UAPPChangelogItem]
    @Binding var selection: Int
    @Binding var progress: CGFloat
    var onOpen: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var scrollSelection: Binding<Int?> {
        Binding(get: { selection }, set: {
            if let value = $0 {
                selection = value
            }
        })
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width - 28)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        GeometryReader { proxy in
                            let offset = proxy.frame(in: .scrollView(axis: .horizontal)).minX - 14
                            UAPPChangelogImage(item: item, parallaxOffset: reduceMotion ? 0 : offset)
                                .scaleEffect(reduceMotion ? 1 : max(0.95, 1 - abs(offset) / width * 0.05))
                                .onTapGesture(perform: onOpen)
                        }
                        .frame(width: width, height: width * 21 / 40)
                        .id(item.id)
                    }
                }
                .scrollTargetLayout()
                .onGeometryChange(for: CGFloat.self) { proxy in
                    let minX = proxy.frame(in: .scrollView(axis: .horizontal)).minX
                    return (14 - minX) / (width + 12)
                } action: { value in
                    if #available(iOS 18, *) {
                        // ScrollGeometry supplies continuous progress on newer systems.
                    } else {
                        progress = value
                    }
                }
            }
            .contentMargins(.horizontal, 14, for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: scrollSelection, anchor: .center)
            .modifier(UAPPChangelogScrollProgressModifier(progress: $progress, stride: width + 12))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.55), value: selection)
        }
        .aspectRatio(40.0 / 21.0, contentMode: .fit)
    }
}

@available(iOS 17, *)
private struct UAPPChangelogScrollProgressModifier: ViewModifier {
    @Binding var progress: CGFloat
    let stride: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                (geometry.contentOffset.x + geometry.contentInsets.leading) / stride
            } action: { _, value in
                progress = value
            }
        } else {
            content
        }
    }
}
#endif
