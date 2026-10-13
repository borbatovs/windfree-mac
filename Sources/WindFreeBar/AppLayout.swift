import Foundation

/// Disposição do painel: uma coluna (vertical) ou duas colunas (horizontal). O app instalado usa só o
/// horizontal; a escolha aparece apenas na pré-visualização, que começa em horizontal (ver `Launcher`).
enum AppLayout: String, CaseIterable {
    case vertical, horizontal

    static let storageKey = "layout"

    var title: String {
        switch self {
        case .vertical: return tr("Vertical", "Vertical")
        case .horizontal: return tr("Horizontal", "Horizontal")
        }
    }
}
