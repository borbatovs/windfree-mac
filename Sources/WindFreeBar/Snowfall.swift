import SwiftUI

/// Flocos de neve sutis caindo no fundo do painel (Frio nos 3 graus mais baixos). `amount` vai de 0 (nenhum)
/// a 1 (mais flocos); a entrada e a saída são em fade.
struct Snowfall: View {
    let amount: Double

    @State private var visible = false
    @State private var shown: Double?
    /// Mantém a neve caindo durante o fade de saída (senão os flocos congelariam enquanto somem).
    @State private var fadingOut = false
    @Environment(\.colorScheme) private var colorScheme

    private struct Flake {
        let x: Double          // posição horizontal (0…1)
        let offset: Double     // atraso no ciclo de queda (0…1)
        let speed: Double      // pontos por segundo
        let size: Double       // diâmetro em pontos
        let sway: Double       // amplitude do balanço lateral em pontos
        let swaySpeed: Double  // radianos por segundo
        let phase: Double
        let alpha: Double
    }

    private static let maxFlakes = 40
    /// Sempre os mesmos flocos (sorteio com semente fixa), para não "pularem" quando o painel é redesenhado.
    private static let flakes: [Flake] = {
        var seed: UInt64 = 0x5EED
        func random() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(1 << 53)
        }
        return (0..<maxFlakes).map { _ in
            Flake(x: random(), offset: random(), speed: 14 + random() * 22, size: 1.5 + random() * 2.5,
                  sway: 4 + random() * 10, swaySpeed: 0.6 + random() * 1.2, phase: random() * .pi * 2,
                  alpha: 0.25 + random() * 0.4)
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !visible || (amount == 0 && !fadingOut))) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                // Quantidade proporcional à intensidade: de ~1/3 dos flocos até todos.
                let count = Int((Double(Self.maxFlakes) * (0.35 + 0.65 * amount)).rounded())
                let color: Color = colorScheme == .dark ? .white : Color(hex: "#7FB8D8")
                let fall = Double(size.height) + 20
                for flake in Self.flakes.prefix(count) {
                    let y = (flake.offset * fall + t * flake.speed).truncatingRemainder(dividingBy: fall) - 10
                    let x = flake.x * Double(size.width) + sin(t * flake.swaySpeed + flake.phase) * flake.sway
                    // Some aos poucos na metade de baixo.
                    let fade = max(0, min(1, 1.6 - 1.4 * y / Double(size.height)))
                    let rect = CGRect(x: x - flake.size / 2, y: y - flake.size / 2, width: flake.size, height: flake.size)
                    context.opacity = flake.alpha * fade
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        // A intensidade mínima (18°) já aparece inteira; o fade é só para entrar e sair.
        .opacity(min((shown ?? amount) * 3, 1))
        .allowsHitTesting(false)
        .onAppear { visible = true; shown = amount }
        .onDisappear { visible = false }
        .onChange(of: amount) { value in
            if value == 0 {
                fadingOut = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { fadingOut = false }
            }
            withAnimation(.easeInOut(duration: 0.8)) { shown = value }
        }
    }
}
