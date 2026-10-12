import SwiftUI

/// Gradiente suave no fundo do painel, na cor do modo. No Frio fica mais intenso quanto mais baixa a
/// temperatura; no Quente, quanto mais alta. Nos outros modos a intensidade é fixa. Desligado, some.
struct ModeGlow: View {
    let power: Bool
    let mode: String
    let setpoint: Int
    let range: ClosedRange<Int>

    /// Intensidade exibida, animada à parte (como a foto ligada): um `.animation(value:)` aqui animaria
    /// também o tamanho do fundo quando o painel muda de altura.
    @State private var shown: Double?

    private static let minOpacity = 0.08
    private static let maxOpacity = 0.45

    private var target: Double {
        guard power else { return 0 }
        let span = Double(max(range.upperBound - range.lowerBound, 1))
        let position = min(max(Double(setpoint - range.lowerBound) / span, 0), 1)   // 0 = mínimo, 1 = máximo
        let strength: Double
        switch mode {
        case "cool": strength = 1 - position
        case "heat": strength = position
        default: strength = 0.5
        }
        return Self.minOpacity + (Self.maxOpacity - Self.minOpacity) * strength
    }

    /// O azul-gelo do Frio é claro e pouco saturado: no fundo escuro virava quase cinza. Para o
    /// gradiente usa um azul mais saturado da mesma família; os demais modos usam a cor do modo.
    private var color: Color {
        guard mode == "cool" else { return ModeColor.of(mode) }
        return Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: dark ? "#3FAEF5" : "#1E96CC")
        })
    }

    var body: some View {
        let color = color
        LinearGradient(stops: [
            .init(color: color, location: 0),
            .init(color: color.opacity(0.35), location: 0.45),
            .init(color: color.opacity(0), location: 1),
        ], startPoint: .top, endPoint: .bottom)
        .opacity(shown ?? target)
        .allowsHitTesting(false)
        .onAppear { shown = target }
        .onChange(of: target) { value in
            withAnimation(.easeInOut(duration: 0.5)) { shown = value }
        }
    }
}
