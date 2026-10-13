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
    @State private var hotShown: Double?
    @State private var coldShown: Double?

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

    /// Temperatura extrema: camada extra no topo nos 3 graus das pontas, mais forte a cada grau (25/50/75%).
    /// Quente 28–30°: vermelho. Frio 18–16°: azul mais profundo. Camadas separadas para uma não "piscar" na
    /// cor da outra ao trocar de modo.
    private var hotTarget: Double {
        guard power, mode == "heat" else { return 0 }
        return Self.extremeOpacity(steps: setpoint - (range.upperBound - 3))
    }
    private var coldTarget: Double {
        guard power, mode == "cool" else { return 0 }
        return Self.extremeOpacity(steps: (range.lowerBound + 3) - setpoint)
    }
    private static func extremeOpacity(steps: Int) -> Double {
        steps > 0 ? Double(min(steps, 3)) / 3 * 0.75 : 0
    }
    private static func extremeColor(_ mode: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: ModeColor.extremeHex(mode, dark: dark) ?? "#000000")
        })
    }

    private func extremeLayer(_ color: Color, opacity: Double) -> some View {
        LinearGradient(stops: [
            .init(color: color, location: 0),
            .init(color: color.opacity(0.4), location: 0.18),
            .init(color: color.opacity(0), location: 0.35),
        ], startPoint: .top, endPoint: .bottom)
        .opacity(opacity)
    }

    var body: some View {
        let color = color
        LinearGradient(stops: [
            .init(color: color, location: 0),
            .init(color: color.opacity(0.35), location: 0.45),
            .init(color: color.opacity(0), location: 1),
        ], startPoint: .top, endPoint: .bottom)
        .opacity(shown ?? target)
        .overlay { extremeLayer(Self.extremeColor("heat"), opacity: hotShown ?? hotTarget) }
        .overlay { extremeLayer(Self.extremeColor("cool"), opacity: coldShown ?? coldTarget) }
        .allowsHitTesting(false)
        .onAppear { shown = target; hotShown = hotTarget; coldShown = coldTarget }
        .onChange(of: hotTarget) { value in
            withAnimation(.easeInOut(duration: 0.5)) { hotShown = value }
        }
        .onChange(of: coldTarget) { value in
            withAnimation(.easeInOut(duration: 0.5)) { coldShown = value }
        }
        .onChange(of: target) { value in
            withAnimation(.easeInOut(duration: 0.5)) { shown = value }
        }
    }
}
