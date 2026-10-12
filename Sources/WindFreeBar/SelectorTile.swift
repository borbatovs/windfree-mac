import SwiftUI
import AppKit

/// Cartão de seleção (ícone, nome e valor atual). Ao clicar abre um menu nativo com as opções.
struct SelectorTile: View {
    struct Option {
        let title: String
        let selected: Bool
        let action: () -> Void
    }

    let icon: String
    /// Ajuste óptico: alguns símbolos ocupam a caixa toda e parecem maiores com o mesmo tamanho de fonte.
    var iconSize: CGFloat = 18
    let title: String
    let value: String
    /// Destaca o ícone quando a função está ligada (ex.: Sono, WindFree).
    var active = false
    /// Quando preenchido, o cartão fica desativado e o texto aparece ao passar o mouse.
    var unavailableReason: String? = nil
    let options: () -> [Option]

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button { OptionMenu.show(options()) } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .regular))
                        .foregroundStyle(active ? Color.accentColor : Color.primary)
                        .frame(height: 22)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                Spacer(minLength: 8)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
        }
        .buttonStyle(.hover(cornerRadius: 10))
        .disabled(unavailableReason != nil)
        .opacity(isEnabled && unavailableReason == nil ? 1 : 0.4)
        .help(unavailableReason ?? "\(title): \(value)")
    }
}

/// Menu de contexto nativo, aberto onde o mouse clicou.
enum OptionMenu {
    private final class Target: NSObject {
        let action: () -> Void
        init(_ action: @escaping () -> Void) { self.action = action }
        @objc func run() { action() }
    }

    static func show(_ options: [SelectorTile.Option]) {
        guard let event = NSApp.currentEvent, let view = event.window?.contentView else { return }
        let menu = NSMenu()
        for option in options {
            let target = Target(option.action)
            let item = NSMenuItem(title: option.title, action: #selector(Target.run), keyEquivalent: "")
            item.target = target
            item.representedObject = target   // `target` é referência fraca; isto mantém o objeto vivo
            item.state = option.selected ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: view.convert(event.locationInWindow, from: nil), in: view)
    }
}
