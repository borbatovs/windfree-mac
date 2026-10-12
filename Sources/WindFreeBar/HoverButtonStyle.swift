import SwiftUI

/// Estilo dos botões do painel: clareia (ou escurece, no tema claro) ao passar o mouse e um pouco mais
/// ao clicar. A camada fica por cima do fundo do próprio botão, no formato `shape`.
struct HoverButtonStyle<S: Shape>: ButtonStyle {
    var shape: S

    func makeBody(configuration: Configuration) -> some View {
        HoverBody(configuration: configuration, shape: shape)
    }

    private struct HoverBody: View {
        let configuration: Configuration
        let shape: S
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let highlight: Double = !isEnabled ? 0 : configuration.isPressed ? 0.14 : hovering ? 0.07 : 0
            configuration.label
                .overlay(shape.fill(Color.primary.opacity(highlight)).allowsHitTesting(false))
                .contentShape(shape)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == HoverButtonStyle<Circle> {
    static var hoverCircle: Self { .init(shape: Circle()) }
}

extension ButtonStyle where Self == HoverButtonStyle<RoundedRectangle> {
    static func hover(cornerRadius: CGFloat) -> Self { .init(shape: RoundedRectangle(cornerRadius: cornerRadius)) }
}
