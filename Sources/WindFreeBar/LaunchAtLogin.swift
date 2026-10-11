import Foundation
import ServiceManagement

/// Liga/desliga a abertura automática no login (Ajustes do Sistema › Geral › Itens de Início).
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// O macOS pode exigir aprovação manual em Itens de Início na primeira vez.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
