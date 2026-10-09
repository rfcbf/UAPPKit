import SwiftUI

public extension View {
    /// Solta alguns joinhas subindo do botão quando a pessoa vota, e joinhas para baixo, descendo,
    /// quando ela retira o voto. Aplique no próprio botão de voto.
    ///
    /// O efeito só aparece em resposta a um toque: mudanças de `isSelected` que chegam ao
    /// carregar a tela não disparam nada. Com Reduzir Movimento ligado, não há animação.
    @ViewBuilder
    func uappVoteBurst(isSelected: Bool, tint: Color? = nil) -> some View {
        if #available(iOS 17, macOS 14, *) {
            modifier(UAPPVoteBurstModifier(isSelected: isSelected, tint: tint))
        } else {
            self
        }
    }
}

/// Regras do efeito, separadas da tela para poderem ser testadas.
enum UAPPVoteBurst {
    /// Quantos símbolos saem em cada voto.
    static let count = 5
    static let duration: TimeInterval = 1.9
    /// Cada símbolo vive por este tanto do progresso; o último trecho é o esmaecimento.
    static let lifetime: CGFloat = 4
    /// Distância que o símbolo percorre a cada unidade de progresso.
    static let rise: CGFloat = 38
    static let symbolSize: CGFloat = 24
    /// Depois do toque, a mudança do voto precisa chegar dentro deste prazo para animar.
    static let armedInterval: TimeInterval = 10

    /// Valor final da animação: o último símbolo parte em `count - 1` e vive `lifetime`.
    static var finalProgress: CGFloat {
        CGFloat(count - 1) + lifetime
    }

    static func symbol(isSelected: Bool) -> String {
        isSelected ? "hand.thumbsup.fill" : "hand.thumbsdown.fill"
    }

    /// A mudança de voto só anima quando veio de um toque recente no botão.
    static func shouldFire(armedAt: Date?, now: Date, reduceMotion: Bool) -> Bool {
        guard !reduceMotion, let armedAt else { return false }
        let elapsed = now.timeIntervalSince(armedAt)
        return elapsed >= 0 && elapsed <= armedInterval
    }

    struct Particle: Equatable {
        var opacity: CGFloat
        var scale: CGFloat
        var offset: CGSize
    }

    /// Estado do símbolo `index` em um ponto da animação. Os símbolos partem um depois do outro,
    /// alternando os lados, crescem ao sair e somem no fim do percurso: para cima ao votar, para
    /// baixo ao retirar o voto.
    static func particle(index: Int, progress: CGFloat, rises: Bool = true) -> Particle {
        let local = min(max(progress - CGFloat(index), 0), lifetime)
        let fade = max(local - (lifetime - 1), 0)
        return Particle(
            opacity: local > 0 ? 1 - fade : 0,
            scale: min(local / 0.5, 1),
            offset: CGSize(
                width: index.isMultiple(of: 2) ? -symbolSize / 2 : symbolSize / 2,
                height: (rises ? -1 : 1) * local * rise
            )
        )
    }
}

@available(iOS 17, macOS 14, *)
private struct UAPPVoteBurstModifier: ViewModifier {
    let isSelected: Bool
    let tint: Color?

    @State private var armedAt: Date?
    @State private var burst = 0
    @State private var rises = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.self) private var environment
    #if os(iOS)
    @State private var anchor = UAPPVoteBurstAnchor()
    #endif

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(TapGesture().onEnded { armedAt = Date() })
            #if os(iOS)
            .background { UAPPVoteBurstAnchorView(anchor: anchor).accessibilityHidden(true) }
            #endif
            .overlay(alignment: rises ? .top : .bottom) {
                UAPPVoteBurstParticles(rises: rises, tint: tint, trigger: burst)
            }
            .onChange(of: isSelected) { _, selected in
                guard UAPPVoteBurst.shouldFire(armedAt: armedAt, now: Date(), reduceMotion: reduceMotion) else {
                    return
                }
                armedAt = nil
                fire(rises: selected)
            }
            .sensoryFeedback(.selection, trigger: burst)
    }

    /// No iOS os símbolos saem em uma camada por cima da janela, para não serem cortados pela
    /// célula ou pelo cartão em que o botão está. Sem janela, saem do próprio botão.
    private func fire(rises: Bool) {
        self.rises = rises
        #if os(iOS)
        let particles = UAPPVoteBurstParticles(rises: rises, tint: tint, trigger: 0, startsOnAppear: true)
            .environment(\.self, environment)
        if anchor.present(particles, fromTop: rises) {
            return
        }
        #endif
        burst += 1
    }
}

@available(iOS 17, macOS 14, *)
private struct UAPPVoteBurstParticles: View {
    let rises: Bool
    let tint: Color?
    let trigger: Int
    var startsOnAppear = false

    @State private var appeared = 0

    var body: some View {
        KeyframeAnimator(initialValue: CGFloat.zero, trigger: trigger + appeared) { progress in
            ZStack {
                ForEach(0 ..< UAPPVoteBurst.count, id: \.self) { index in
                    let particle = UAPPVoteBurst.particle(index: index, progress: progress, rises: rises)
                    Image(systemName: UAPPVoteBurst.symbol(isSelected: rises))
                        .font(.system(size: UAPPVoteBurst.symbolSize, weight: .semibold))
                        .foregroundStyle(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.tint))
                        .opacity(particle.opacity)
                        .scaleEffect(particle.scale, anchor: rises ? .bottom : .top)
                        .offset(particle.offset)
                }
            }
        } keyframes: { _ in
            MoveKeyframe(0)
            LinearKeyframe(UAPPVoteBurst.finalProgress, duration: UAPPVoteBurst.duration)
        }
        .fixedSize()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            if startsOnAppear {
                appeared = 1
            }
        }
    }
}

#if os(iOS)
/// Guarda a view UIKit atrás do botão, de onde saem a janela e a posição do efeito.
@MainActor
final class UAPPVoteBurstAnchor {
    weak var view: UIView?

    /// Mostra o efeito por cima da janela do botão. Devolve `false` quando não há janela.
    @available(iOS 17, *)
    func present(_ particles: some View, fromTop: Bool) -> Bool {
        guard let view, let window = view.window else { return false }
        let origin = view.convert(view.bounds, to: window)
        let host = UIHostingController(
            rootView: particles
                .position(x: origin.midX, y: fromTop ? origin.minY : origin.maxY)
                .ignoresSafeArea()
        )
        host.safeAreaRegions = []
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        host.view.frame = window.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(host.view)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(UAPPVoteBurst.duration + 0.3))
            host.view.removeFromSuperview()
        }
        return true
    }
}

private struct UAPPVoteBurstAnchorView: UIViewRepresentable {
    let anchor: UAPPVoteBurstAnchor

    func makeUIView(context _: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        anchor.view = view
        return view
    }

    func updateUIView(_ uiView: UIView, context _: Context) {
        anchor.view = uiView
    }
}
#endif

#Preview("Voto com joinhas") {
    struct Demo: View {
        @State private var voted = false

        var body: some View {
            Button { voted.toggle() } label: {
                Label(voted ? "13" : "12", systemImage: voted ? "arrow.up.circle.fill" : "arrow.up.circle")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(.tint.opacity(voted ? 0.2 : 0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            .uappVoteBurst(isSelected: voted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    return Demo()
}
