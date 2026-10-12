import SwiftUI
import AppKit

/// `swift run WindFreeBar --preview`: o painel numa janela comum, com dados de exemplo.
/// Não usa a rede nem o Keychain e não interfere no app instalado; os botões só mudam a tela.
struct PreviewApp: App {
    @NSApplicationDelegateAdaptor(PreviewAppDelegate.self) private var appDelegate
    @StateObject private var controller = ACController(demo: true)

    var body: some Scene {
        Window(tr("WindFree — pré-visualização", "WindFree — preview"), id: "preview") {
            ControlPanel()
                .environmentObject(controller)
        }
        .windowResizability(.contentSize)
    }
}

final class PreviewAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Rodado pelo Terminal, o processo não vira app "de frente" sozinho.
        NSApp.setActivationPolicy(.regular)
        AppAppearance.saved.apply()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// `swift run WindFreeBar --snapshot <pasta>`: salva PNGs do painel em alguns estados (temas escuro e claro;
/// os casos com prefixo `en-` saem em inglês).
@MainActor
enum Snapshots {
    static func render(to directory: String) {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)

        let cases: [(name: String, dark: Bool, setup: (ACController) -> Void)] = [
            ("ligado-frio", true, { _ in }),
            ("ligado-quente", true, { $0.state.mode = "heat" }),   // WindFree desativado
            ("ligado-frio-16", true, { $0.state.setpoint = 16 }),        // fundo no máximo
            ("ligado-quente-30", true, { $0.state.mode = "heat"; $0.state.setpoint = 30 }),
            ("ligado-seco", true, { $0.state.mode = "dry" }),
            ("ligado-ventilar", true, { $0.state.mode = "wind" }),
            ("ligado-auto", true, { $0.state.mode = "auto" }),
            ("desligado", true, { $0.state.power = false }),
            ("configuracoes", true, { $0.showSettings = true }),
            ("claro-ligado-frio", false, { _ in }),
            ("claro-ligado-ventilar", false, { $0.state.mode = "wind" }),
            ("claro-configuracoes", false, { $0.showSettings = true }),
            ("en-ligado-frio", true, { _ in }),
            ("en-configuracoes", true, { $0.showSettings = true }),
        ]
        // O idioma vem das preferências; guarda o da pré-visualização para restaurar no fim.
        let defaults = UserDefaults.standard
        let savedLanguage = defaults.string(forKey: AppLanguage.storageKey)
        defer { defaults.set(savedLanguage, forKey: AppLanguage.storageKey) }
        let folder = URL(fileURLWithPath: directory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        for item in cases {
            defaults.set(item.name.hasPrefix("en-") ? AppLanguage.en.rawValue : AppLanguage.pt.rawValue,
                         forKey: AppLanguage.storageKey)
            let ac = ACController(demo: true)
            item.setup(ac)
            let view = NSHostingView(rootView: ControlPanel()
                .environmentObject(ac)
                .background(Color(nsColor: .windowBackgroundColor)))
            let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: item.dark ? .darkAqua : .aqua)
            window.contentView = view
            window.setContentSize(view.fittingSize)
            // Deixa o SwiftUI montar a tela (imagens, layout) antes de capturar.
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            view.layoutSubtreeIfNeeded()

            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            let url = folder.appendingPathComponent("\(item.name).png")
            do {
                try rep.representation(using: .png, properties: [:])?.write(to: url)
                print("Salvo: \(url.path)")
            } catch {
                print("Falha ao salvar \(url.path): \(error.localizedDescription)")
            }
        }
    }
}
