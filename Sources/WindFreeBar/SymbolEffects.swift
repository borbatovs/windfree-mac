import SwiftUI

/// Animações dos SF Symbols. Só existem a partir do macOS 14 (bounce, replace) e 15 (rotate,
/// breathe); nas versões anteriores os ícones ficam estáticos.
extension View {
    /// "Pulo" a cada mudança de `trigger` (botão de energia).
    @ViewBuilder func symbolBounce<V: Equatable>(on trigger: V) -> some View {
        if #available(macOS 14, *) {
            symbolEffect(.bounce, value: trigger)
        } else {
            self
        }
    }

    /// Troca animada quando o nome do símbolo muda (ícone do modo).
    @ViewBuilder func symbolReplaceTransition() -> some View {
        if #available(macOS 14, *) {
            contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }

    /// Giro contínuo (pás do ventilador). `speed` 1 = velocidade padrão do efeito.
    @ViewBuilder func symbolSpinning(_ active: Bool, speed: Double) -> some View {
        if #available(macOS 15, *) {
            symbolEffect(.rotate, options: .speed(speed), isActive: active)
        } else {
            self
        }
    }

    /// Efeito contínuo do ícone de cada modo no centro do dimmer.
    @ViewBuilder func modeSymbolEffect(_ mode: String, active: Bool) -> some View {
        if #available(macOS 15, *) {
            switch mode {
            case "auto": symbolEffect(.rotate, options: .speed(0.3), isActive: active)
            // `.plain` só muda o tamanho; o padrão (`.pulse`) também varia a opacidade.
            default: symbolEffect(.breathe.plain, isActive: active)
            }
        } else {
            self
        }
    }
}

/// Ritmo do giro do ventilador para cada velocidade.
enum FanSpin {
    static func speed(_ fanMode: String) -> Double {
        switch fanMode {
        case "low": return 0.5
        case "medium": return 1
        case "high": return 1.6
        case "turbo": return 2.6
        default: return 1   // auto
        }
    }
}
