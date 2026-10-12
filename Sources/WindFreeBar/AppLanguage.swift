import Foundation

/// Idioma da interface, escolhido nas configurações (independe do idioma do macOS). Padrão: português.
enum AppLanguage: String, CaseIterable {
    case pt, en

    static let storageKey = "language"

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .pt
    }

    /// Nome de cada idioma nele mesmo, como é costume em seletores de idioma.
    var title: String {
        switch self {
        case .pt: return "Português"
        case .en: return "English"
        }
    }
}

/// Texto no idioma escolhido: `tr("Ligado", "On")`.
func tr(_ portuguese: String, _ english: String) -> String {
    AppLanguage.current == .en ? english : portuguese
}
