import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@Test("cápsula ativa transfere largura e cor durante a rolagem")
func pagingIndicatorInterpolatesProgress() {
    let start = UAPPPagingIndicatorMetrics(progress: 0, count: 3)
    #expect(start.width(at: 0) == 26)
    #expect(start.width(at: 1) == 8)
    #expect(start.opacity(at: 0) == 1)
    let halfway = UAPPPagingIndicatorMetrics(progress: 0.5, count: 3)
    #expect(halfway.width(at: 0) == 17)
    #expect(halfway.width(at: 1) == 17)
    #expect(halfway.opacity(at: 0) == 0.5)
    #expect(halfway.opacity(at: 1) == 0.5)
    #expect(halfway.width(at: 2) == 8)
    #expect(halfway.opacity(at: 2) == 0)
    #expect((0 ..< 3).reduce(CGFloat.zero) { $0 + halfway.width(at: $1) } == 42)
    let last = UAPPPagingIndicatorMetrics(progress: 2, count: 3)
    #expect(last.width(at: 2) == 26)
    #expect(last.opacity(at: 1) == 0)
}

@Test("indicador limita progresso no retorno, overscroll e mudanças de quantidade")
func pagingIndicatorClampsProgress() {
    #expect(UAPPPagingIndicatorMetrics(progress: -1, count: 3).progress == 0)
    #expect(UAPPPagingIndicatorMetrics(progress: 4, count: 3).progress == 2)
    #expect(UAPPPagingIndicatorMetrics(progress: 2, count: 1).progress == 0)
    #expect(UAPPPagingIndicatorMetrics(progress: 2, count: 0).progress == 0)
    #expect(UAPPPagingIndicatorMetrics(progress: .nan, count: 3).progress == 0)
    #expect(UAPPPagingIndicatorMetrics(progress: .infinity, count: 3).progress == 0)
}

@Test("indicador renderiza progresso fracionário e fica oculto para zero ou uma imagem")
@MainActor
func pagingIndicatorRenders() async {
    for count in [0, 1, 3] {
        await render(UAPPPagingIndicator(count: count, progress: 0.5, selection: 1, onSelect: { _ in }))
    }
}
