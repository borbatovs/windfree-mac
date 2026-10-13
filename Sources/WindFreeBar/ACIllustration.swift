import SwiftUI
import AppKit

/// Um fio do fluxo de ar (componente "Air flow" do Figma). Os dados ficam em `AirFlowStrands.swift`.
struct AirFlowStrand {
    let origin: CGPoint
    let height: CGFloat
    let start: CGPoint
    let control1: CGPoint
    let control2: CGPoint
    let end: CGPoint
    let lineWidth: CGFloat
    /// Índice na paleta de 5 tons.
    let tone: Int
    /// Posição inicial da "cabeça" do trecho no ciclo (0…1,4).
    let phase: Double
    let peakOpacity: Double

    var path: Path {
        var p = Path()
        p.move(to: start)
        p.addCurve(to: end, control1: control1, control2: control2)
        return p
    }
}

/// Imagem do aparelho no topo do painel (componente "ac img" do Figma): aleta fechada quando desligado,
/// aleta aberta com o fluxo de ar animado quando ligado.
struct ACIllustration: View {
    let power: Bool
    let mode: String
    let fanMode: String
    /// Largura fixa: a janela do menu bar mede o conteúdo com altura mínima, e um tamanho só por
    /// proporção (GeometryReader + aspectRatio) encolhia até zero.
    var width: CGFloat = 288

    // Medidas do Figma (variante ligada, 996 × 934): a foto (916 × 353) fica em x = 80 e o fluxo de ar
    // (980 × 682) começa em x = 0, y = 252. A foto fica centralizada no painel; o fluxo, que puxa para a
    // esquerda, avança um pouco sobre a margem.
    private static let canvasWidth: CGFloat = 996
    private static let photoX: CGFloat = 80
    private static let photoWidth: CGFloat = 916
    private static let airFlowY: CGFloat = 252
    private static let airFlowSize = CGSize(width: 980, height: 682)

    private static let transition = Animation.easeInOut(duration: 0.4)
    /// Quanto tirar da altura fixa: a ponta de baixo do fluxo de ar já é transparente, então o dimmer pode
    /// chegar mais perto (o fluxo é desenhado por cima dessa folga).
    private static let bottomTrim: CGFloat = 20
    /// Opacidade da foto ligada, animada à parte. Um `.animation(value: power)` animaria também a
    /// posição da foto quando o painel muda de altura, e ela "deslizaria".
    @State private var onPhotoOpacity: Double?

    var body: some View {
        let s = width / Self.canvasWidth
        let photoLeft = (width - Self.photoWidth * s) / 2
        ZStack(alignment: .topLeading) {
            // "Smart animate": a foto desligada fica sempre por baixo e opaca; a ligada aparece/some por cima,
            // parada. Como o corpo é igual nas duas fotos, só a aleta parece mudar (sem o aparelho ficar
            // translúcido no meio, como acontecia trocando uma foto pela outra).
            photo("ac-off")
                .frame(width: Self.photoWidth * s, height: 337 * s)
                .offset(x: photoLeft)
            photo("ac-on")
                .frame(width: Self.photoWidth * s, height: 353 * s)
                .opacity(onPhotoOpacity ?? (power ? 1 : 0))
                .offset(x: photoLeft)
            if power {
                AirFlowView(fanMode: fanMode, mode: mode)
                    .frame(width: Self.airFlowSize.width * s, height: Self.airFlowSize.height * s)
                    .offset(x: photoLeft - Self.photoX * s, y: Self.airFlowY * s)
                    // O ar sai depois que a aleta abre; ao desligar some logo.
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeInOut(duration: 0.5).delay(0.25)),
                        removal: .opacity.animation(.easeInOut(duration: 0.25))))
            }
        }
        // Altura fixa (a de ligado) mesmo desligado: a janela do painel não muda de tamanho ao ligar/desligar
        // e nada salta; desligado, o espaço do fluxo de ar fica vazio entre o aparelho e o dimmer.
        .frame(width: width, height: (Self.airFlowY + Self.airFlowSize.height) * s - Self.bottomTrim, alignment: .topLeading)
        .onAppear { onPhotoOpacity = power ? 1 : 0 }
        .onChange(of: power) { on in
            withAnimation(Self.transition) { onPhotoOpacity = on ? 1 : 0 }
        }
        .accessibilityLabel(power ? tr("Ar-condicionado ligado", "Air conditioner on") : tr("Ar-condicionado desligado", "Air conditioner off"))
    }

    @ViewBuilder
    private func photo(_ name: String) -> some View {
        if let image = Self.image(name) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
        }
    }

    private static var cache: [String: NSImage] = [:]

    /// As fotos são copiadas para o app pelo build.sh (Contents/Resources). Rodando com `swift run`
    /// (pré-visualização) não há .app: usa a pasta Resources do projeto.
    private static func image(_ name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        let projectResources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/\(name).png")
        let url = Bundle.main.url(forResource: name, withExtension: "png") ?? projectResources
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache[name] = image
        return image
    }
}

/// Fios de ar animados: em cada fio, um trecho com 40% do comprimento percorre o caminho em loop,
/// mais rápido conforme a velocidade do ventilador.
struct AirFlowView: View {
    let fanMode: String
    let mode: String

    /// O painel do menu bar continua existindo fechado; só anima enquanto está na tela.
    @State private var visible = false
    @Environment(\.colorScheme) private var colorScheme

    private static let cycle = 1.4         // a cabeça vai de 0 a 1,4 (o trecho sai inteiro do fio)
    private static let segment = 0.4

    /// 5 tons por modo, um para cada `AirFlowStrand.tone`. Quente usa laranjas escolhidos por nós; os demais
    /// (inclusive o Frio, em azul-gelo) variam a cor do modo (`ModeColor`) para o branco e o preto.
    private static func palette(for mode: String, dark: Bool) -> [Color] {
        switch mode {
        case "heat": return ["#E8731F", "#FA8C2B", "#FFA333", "#E8851F", "#F5A052"].map(Color.init(hex:))
        default:
            let base = NSColor(hex: ModeColor.hex(mode, dark: dark))
            let variants: [(NSColor, CGFloat)] = [(.black, 0.10), (.white, 0.10), (.white, 0.22), (.black, 0.04), (.white, 0.32)]
            return variants.map { Color(nsColor: base.blended(withFraction: $0.1, of: $0.0) ?? base) }
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !visible)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let scale = size.width / 980
                context.scaleBy(x: scale, y: scale)
                let travelled = distance(at: t)
                let palette = Self.palette(for: mode, dark: colorScheme == .dark)

                for strand in AirFlowStrand.all {
                    let head = (strand.phase + travelled).truncatingRemainder(dividingBy: Self.cycle)
                    let from = max(0, head - Self.segment)
                    let to = min(1, head)
                    guard to > from else { continue }

                    var ctx = context
                    ctx.translateBy(x: strand.origin.x, y: strand.origin.y)
                    ctx.opacity = strand.peakOpacity * Self.fade(head)
                    let color = palette[strand.tone]
                    ctx.stroke(
                        strand.path.trimmedPath(from: from, to: to),
                        with: .linearGradient(
                            Gradient(stops: [
                                .init(color: color.opacity(0), location: 0),
                                .init(color: color.opacity(0.6), location: 0.12),
                                .init(color: color.opacity(0.94), location: 0.42),
                                .init(color: color.opacity(0.78), location: 0.72),
                                .init(color: color.opacity(0), location: 1),
                            ]),
                            startPoint: .zero, endPoint: CGPoint(x: 0, y: strand.height)),
                        style: StrokeStyle(lineWidth: strand.lineWidth, lineCap: .round))
                }
            }
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
    }

    /// Quanto a cabeça já andou desde a referência, em comprimentos de fio. Velocidades tiradas do Figma.
    private func distance(at t: Double) -> Double {
        switch fanMode {
        case "low": return 0.525 * t
        case "medium": return 0.875 * t
        case "high": return 1.4 * t
        case "turbo": return 2.1 * t
        default:
            // Auto: velocidade oscila suavemente entre ~0,63 e ~0,87 a cada 8 s.
            let period = 8.0, amplitude = 0.12
            return 0.75 * t - amplitude * period / (2 * .pi) * cos(2 * .pi * t / period)
        }
    }

    /// Aparece no início do percurso e some no fim, como no Figma.
    private static func fade(_ head: Double) -> Double {
        switch head {
        case ..<0.084: return 0
        case ..<0.252: return (head - 0.084) / 0.168
        case ..<1.148: return 1
        case ..<1.316: return (1.316 - head) / 0.168
        default: return 0
        }
    }
}

extension NSColor {
    convenience init(hex: String) {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: String) {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}
