import SwiftUI
import AppKit

@main
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
