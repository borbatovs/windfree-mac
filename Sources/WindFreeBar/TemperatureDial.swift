import SwiftUI
import AppKit

/// Dimmer de temperatura: anel de marcações do mínimo ao máximo, arco até o valor atual na cor do modo e,
/// no centro, modo + temperatura. Ajuste com a rolagem do mouse/trackpad sobre o dimmer ou clicando e
/// arrastando para cima/baixo.
struct TemperatureDial: View {
    let value: Int
    let range: ClosedRange<Int>
    let mode: String
    let power: Bool
    /// +1 / −1 grau. O ACController aplica limites e o debounce de envio.
    let onStep: (Int) -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    private static let size: CGFloat = 200
    private static let knobSize: CGFloat = 144
    // Abertura de 120° embaixo: começa em 150° (embaixo à esquerda) e varre 240° passando pelo topo.
    private static let startAngle = 150.0
    private static let sweep = 240.0

    private var fraction: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        let f = Double(value - range.lowerBound) / Double(range.upperBound - range.lowerBound)
        return min(max(f, 0), 1)
    }

    private var color: Color { power ? ModeColor.dial(mode, setpoint: value, range: range) : Color.secondary }
    private var valueAngle: Angle { .degrees(Self.startAngle + Self.sweep * fraction) }

    var body: some View {
        ZStack {
            ring
            knob
            DialInput(enabled: isEnabled, onStep: onStep, onHover: { hovering = $0 })
                .frame(width: Self.size, height: Self.size)
        }
        .frame(width: Self.size, height: Self.size)
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.15), value: value)
        .animation(.easeOut(duration: 0.2), value: mode)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Temperatura", "Temperature"))
        .accessibilityValue(tr("\(value) graus, modo \(Labels.mode(mode))", "\(value) degrees, \(Labels.mode(mode)) mode"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onStep(1)
            case .decrement: onStep(-1)
            @unknown default: break
            }
        }
    }

    // MARK: Anel

    private var ring: some View {
        let fraction = fraction, color = color
        let lower = range.lowerBound, upper = range.upperBound
        return Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            func point(_ radius: CGFloat, _ angle: Angle) -> CGPoint {
                CGPoint(x: center.x + radius * cos(angle.radians), y: center.y + radius * sin(angle.radians))
            }

            // Marcações a cada meio grau; as dos graus inteiros são mais longas.
            let steps = max((upper - lower) * 2, 1)
            for i in 0...steps {
                let f = Double(i) / Double(steps)
                let angle = Angle.degrees(Self.startAngle + Self.sweep * f)
                let whole = i.isMultiple(of: 2)
                var tick = Path()
                tick.move(to: point(99, angle))
                tick.addLine(to: point(whole ? 90 : 93, angle))
                let reached = f <= fraction + 0.0001
                context.stroke(tick, with: .color(reached ? color : Color.primary.opacity(0.18)),
                               style: StrokeStyle(lineWidth: whole ? 2 : 1.5, lineCap: .round))
            }

            // Trilho e arco de progresso.
            func arc(to f: Double) -> Path {
                var p = Path()
                p.addArc(center: center, radius: 82, startAngle: .degrees(Self.startAngle),
                         endAngle: .degrees(Self.startAngle + Self.sweep * f), clockwise: false)
                return p
            }
            let style = StrokeStyle(lineWidth: 4, lineCap: .round)
            context.stroke(arc(to: 1), with: .color(Color.primary.opacity(0.08)), style: style)
            // No mínimo ainda mostra um pedacinho do arco, para o dimmer não parecer apagado.
            context.stroke(arc(to: max(fraction, 0.03)), with: .color(color), style: style)
        }
    }

    // MARK: Botão central

    private var knob: some View {
        let dotRadius = Self.knobSize / 2 - 12
        return ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.primary.opacity(hovering ? 0.13 : 0.10),
                                              Color.primary.opacity(hovering ? 0.05 : 0.03)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 6)

            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .offset(x: dotRadius * cos(valueAngle.radians), y: dotRadius * sin(valueAngle.radians))

            VStack(spacing: 2) {
                Text(Labels.mode(mode).uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(color)
                Text("\(value)°")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Image(systemName: Labels.modeIcon(mode))
                    .font(.system(size: 13))
                    .foregroundStyle(color)
                    .symbolReplaceTransition()
                    .modeSymbolEffect(mode, active: power)
            }
        }
        .frame(width: Self.knobSize, height: Self.knobSize)
    }
}

/// Cor de cada modo: dimmer, botão do modo e fluxo de ar.
enum ModeColor {
    /// - Parameter dark: tema escuro. Frio e Ventilar mudam com o tema: azul-gelo claro no escuro e mais fundo
    ///   no claro; Ventilar branco puro no escuro e quase preto no claro.
    static func hex(_ mode: String, dark: Bool = true) -> String {
        switch mode {
        case "cool": return dark ? "#8CD6F5" : "#1E96CC"
        case "heat": return "#FA8C2B"
        case "dry": return "#2EC4B6"
        case "wind": return dark ? "#FFFFFF" : "#3A3A3C"
        default: return "#8E7CF0"   // auto
        }
    }

    /// Cor que se ajusta sozinha ao tema da janela.
    static func of(_ mode: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: hex(mode, dark: dark))
        })
    }

    /// Cor extrema (mesmas do fundo): Frio azul vivo, Quente vermelho.
    static func extremeHex(_ mode: String, dark: Bool) -> String? {
        switch mode {
        case "cool": return dark ? "#14A0FF" : "#0A8FE8"
        case "heat": return "#E5392F"
        default: return nil
        }
    }

    /// Quanto da cor extrema usar (0…1): nos 3 graus das pontas, 1/3 por grau — Frio 18→16°, Quente 28→30°.
    static func extremeAmount(_ mode: String, setpoint: Int, range: ClosedRange<Int>) -> Double {
        let steps: Int
        switch mode {
        case "cool": steps = (range.lowerBound + 3) - setpoint
        case "heat": steps = setpoint - (range.upperBound - 3)
        default: return 0
        }
        return Double(min(max(steps, 0), 3)) / 3
    }

    /// Cor do dimmer: a do modo; no Quente puxa para o vermelho nos 3 graus mais altos. O Frio fica no
    /// azul-gelo (no frio extremo só um pedacinho do arco aparece, e o azul vivo não fez efeito).
    static func dial(_ mode: String, setpoint: Int, range: ClosedRange<Int>) -> Color {
        let amount = mode == "heat" ? extremeAmount(mode, setpoint: setpoint, range: range) : 0
        return Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let base = NSColor(hex: hex(mode, dark: dark))
            guard amount > 0, let extreme = extremeHex(mode, dark: dark) else { return base }
            return base.blended(withFraction: amount, of: NSColor(hex: extreme)) ?? base
        })
    }
}

/// Camada AppKit por cima do dimmer: o SwiftUI do macOS 13 não entrega a roda do mouse.
private struct DialInput: NSViewRepresentable {
    var enabled: Bool
    var onStep: (Int) -> Void
    var onHover: (Bool) -> Void

    func makeNSView(context: Context) -> InputView { InputView() }

    func updateNSView(_ view: InputView, context: Context) {
        view.enabled = enabled
        view.onStep = onStep
        view.onHover = onHover
    }

    final class InputView: NSView {
        var enabled = true
        var onStep: (Int) -> Void = { _ in }
        var onHover: (Bool) -> Void = { _ in }

        /// Pontos de arraste / rolagem de trackpad por grau.
        private let dragStep: CGFloat = 8
        private let preciseScrollStep: CGFloat = 12
        private var accumulated: CGFloat = 0
        private var lastDragY: CGFloat = 0

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: .zero,
                                           options: [.mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect],
                                           owner: self))
        }

        override func mouseEntered(with event: NSEvent) { onHover(true) }
        override func mouseExited(with event: NSEvent) { onHover(false) }

        override func cursorUpdate(with event: NSEvent) {
            if enabled { NSCursor.resizeUpDown.set() } else { super.cursorUpdate(with: event) }
        }

        override func scrollWheel(with event: NSEvent) {
            guard enabled else { return super.scrollWheel(with: event) }
            // Ignora a inércia do trackpad para não "disparar" vários graus sozinho.
            guard event.momentumPhase.isEmpty else { return }
            // Direção física: para cima sobe, com ou sem rolagem natural.
            let dy = event.scrollingDeltaY * (event.isDirectionInvertedFromDevice ? -1 : 1)
            if event.hasPreciseScrollingDeltas {
                accumulated += dy
                emit(step: preciseScrollStep)
            } else if dy != 0 {
                onStep(dy > 0 ? 1 : -1)   // roda do mouse: um grau por clique
            }
        }

        override func mouseDown(with event: NSEvent) {
            guard enabled else { return }
            lastDragY = event.locationInWindow.y
            accumulated = 0
        }

        override func mouseDragged(with event: NSEvent) {
            guard enabled else { return }
            let y = event.locationInWindow.y   // cresce para cima
            accumulated += y - lastDragY
            lastDragY = y
            emit(step: dragStep)
        }

        private func emit(step: CGFloat) {
            while accumulated >= step { onStep(1); accumulated -= step }
            while accumulated <= -step { onStep(-1); accumulated += step }
        }
    }
}
