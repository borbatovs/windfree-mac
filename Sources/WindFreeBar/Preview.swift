import SwiftUI
import AppKit

/// `swift run WindFreeBar --preview`: o painel numa janela comum, com dados de exemplo.
/// Não usa a rede nem o Keychain e não interfere no app instalado; os botões só mudam a tela.
struct PreviewApp: App {
    @NSApplicationDelegateAdaptor(PreviewAppDelegate.self) private var appDelegate
    @StateObject private var controller = ACController(demo: true)

    var body: some Scene {
        Window("WindFree — pré-visualização", id: "preview") {
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
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// `swift run WindFreeBar --snapshot <pasta>`: salva PNGs do painel em alguns estados (tema escuro).
@MainActor
enum Snapshots {
    static func render(to directory: String) {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)

        let cases: [(name: String, setup: (ACController) -> Void)] = [
            ("ligado-frio", { _ in }),
            ("ligado-quente", { $0.state.mode = "heat" }),
            ("desligado", { $0.state.power = false }),
            ("configuracoes", { $0.showSettings = true }),
        ]
        let folder = URL(fileURLWithPath: directory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        for item in cases {
            let ac = ACController(demo: true)
            item.setup(ac)
            let view = NSHostingView(rootView: ControlPanel()
                .environmentObject(ac)
                .background(Color(nsColor: .windowBackgroundColor)))
            let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .darkAqua)
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
