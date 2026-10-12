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

    // Medidas do Figma: quadro de 1442 × 1063 quando ligado; a foto (916 de largura) fica a 22,12% da esquerda
    // e o fluxo de ar (1442 × 811) começa a 23,71% do topo.
    private static let canvasWidth: CGFloat = 1442
    private static let photoX: CGFloat = 319
    private static let photoWidth: CGFloat = 916
    private static let airFlowY: CGFloat = 252
    private static let airFlowHeight: CGFloat = 811

    var body: some View {
        let s = width / Self.canvasWidth
        ZStack(alignment: .topLeading) {
            photo(on: power)
                .frame(width: Self.photoWidth * s, height: (power ? 353 : 337) * s)
                .offset(x: Self.photoX * s)
                .id(power)
                .transition(.opacity)
            if power {
                AirFlowView(fanMode: fanMode, heat: mode == "heat")
                    .frame(width: Self.canvasWidth * s, height: Self.airFlowHeight * s)
                    .offset(y: Self.airFlowY * s)
                    .transition(.opacity)
            }
        }
        .frame(width: width, height: (power ? Self.airFlowY + Self.airFlowHeight : 337) * s, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.35), value: power)
        .accessibilityLabel(power ? "Ar-condicionado ligado" : "Ar-condicionado desligado")
    }

    @ViewBuilder
    private func photo(on: Bool) -> some View {
        if let image = Self.image(on ? "ac-on" : "ac-off") {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
        }
    }

    private static var cache: [String: NSImage] = [:]

    /// As fotos são copiadas para o app pelo build.sh (Contents/Resources).
    private static func image(_ name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        cache[name] = image
        return image
    }
}

/// Fios de ar animados: em cada fio, um trecho com 40% do comprimento percorre o caminho em loop,
/// mais rápido conforme a velocidade do ventilador.
struct AirFlowView: View {
    let fanMode: String
    let heat: Bool

    /// O painel do menu bar continua existindo fechado; só anima enquanto está na tela.
    @State private var visible = false

    private static let cycle = 1.4         // a cabeça vai de 0 a 1,4 (o trecho sai inteiro do fio)
    private static let segment = 0.4

    private static let blue = ["#1F91E8", "#2BADFA", "#33C4FF", "#21A3E8", "#52B8F5"].map(Color.init(hex:))
    private static let orange = ["#E8731F", "#FA8C2B", "#FFA333", "#E8851F", "#F5A052"].map(Color.init(hex:))

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !visible)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let scale = size.width / 1442
                context.scaleBy(x: scale, y: scale)
                let travelled = distance(at: t)
                let palette = heat ? Self.orange : Self.blue

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

private extension Color {
    init(hex: String) {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}
