#if canImport(SwiftUI)
import SwiftUI

extension View {
    @ViewBuilder
    func uappPresentationPlacement(_ placement: UAPPPresentationPlacement) -> some View {
        #if os(iOS)
        if #available(iOS 27, *) {
            presentationPlacement(placement.swiftUIValue)
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func uappPresentationBackground(_ color: Color) -> some View {
        if #available(iOS 16.4, macOS 13.3, *) {
            presentationBackground(color)
        } else {
            background(color.ignoresSafeArea())
        }
    }
}

enum UAPPPresentationPlacement {
    case trailing

    #if os(iOS)
    @available(iOS 27, *)
    var swiftUIValue: PresentationPlacement {
        switch self {
        case .trailing: .trailing
        }
    }
    #endif
}
#endif
