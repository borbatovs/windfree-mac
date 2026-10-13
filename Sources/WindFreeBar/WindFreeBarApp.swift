import SwiftUI
import AppKit

/// Ponto de entrada. Sem argumentos abre o app normal na barra de menus.
/// `--preview` abre o painel numa janela com dados de exemplo; `--snapshot <pasta>` salva capturas do painel.
@main
enum Launcher {
    @MainActor static func main() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot") {
            Snapshots.render(to: i + 1 < args.count ? args[i + 1] : "snapshots")
        } else if args.contains("--preview") {
            // A pré-visualização começa no layout horizontal; o app instalado, no vertical.
            UserDefaults.standard.register(defaults: [AppLayout.storageKey: AppLayout.horizontal.rawValue])
            PreviewApp.main()
        } else {
            WindFreeBarApp.main()
        }
    }
}

struct WindFreeBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = ACController()

    var body: some Scene {
        MenuBarExtra {
            ControlPanel()
                .environmentObject(controller)
        } label: {
            MenuBarLabel(state: controller.state, loaded: controller.hasLoaded)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Esconde o ícone do Dock mesmo quando rodado com `swift run`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppAppearance.saved.apply()
    }
}

/// Ícone + temperatura que aparecem na barra de menus.
struct MenuBarLabel: View {
    let state: ACState
    let loaded: Bool

    var body: some View {
        let icon = state.power ? Labels.modeIcon(state.mode) : "air.conditioner.horizontal.fill"
        if loaded, state.power {
            Label("\(state.setpoint)°", systemImage: icon)
                .labelStyle(.titleAndIcon)
        } else {
            Image(systemName: icon)
        }
    }
}
