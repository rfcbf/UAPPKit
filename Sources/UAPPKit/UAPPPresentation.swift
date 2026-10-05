#if canImport(SwiftUI)
import SwiftUI

extension View {
    @ViewBuilder
    func uappPresentationPlacement(_ placement: UAPPPresentationPlacement) -> some View {
        // `presentationPlacement` só existe no SDK do iOS 27 (Swift 6.4+);
        // em toolchains anteriores o símbolo não compila, mesmo sob `#available`.
        #if os(iOS) && compiler(>=6.4)
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

    #if os(iOS) && compiler(>=6.4)
    @available(iOS 27, *)
    var swiftUIValue: PresentationPlacement {
        switch self {
        case .trailing: .trailing
        }
    }
    #endif
}
#endif
