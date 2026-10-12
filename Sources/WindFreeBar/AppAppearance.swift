import AppKit

/// Tema escolhido nas configurações. Vale para o app inteiro (painel e menus) via `NSApp.appearance`.
enum AppAppearance: String, CaseIterable {
    case system, light, dark

    static let storageKey = "appearance"

    var title: String {
        switch self {
        case .system: return tr("Sistema", "System")
        case .light: return tr("Claro", "Light")
        case .dark: return tr("Escuro", "Dark")
        }
    }

    static var saved: AppAppearance {
        AppAppearance(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    @MainActor func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
