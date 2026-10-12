import SwiftUI
import AppKit

struct ControlPanel: View {
    @EnvironmentObject var ac: ACController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if !ac.showSettings {
                ACIllustration(power: ac.state.power, mode: ac.state.mode, fanMode: ac.state.fanMode,
                               width: 288 * 0.9)
                    .frame(maxWidth: .infinity)
            }

            if ac.showSettings {
                Divider()
                SettingsView()
            } else {
                controls
                    .opacity(ac.state.power ? 1 : 0.55)
            }

            if let error = ac.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
        .task { await ac.refresh(askDevice: true) }
    }

    // MARK: Cabeçalho

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ac.deviceLabel).font(.headline)
                HStack(spacing: 10) {
                    if let t = ac.state.roomTemperature {
                        Label("\(Int(t))° no ambiente", systemImage: "thermometer.medium")
                    }
                    if let h = ac.state.humidity {
                        Label("\(Int(h))%", systemImage: "humidity")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            powerButton
        }
    }

    private var powerButton: some View {
        let on = ac.state.power
        return Button { ac.setPower(!on) } label: {
            Image(systemName: "power")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(on ? Color.white : Color.secondary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(on ? Color.accentColor : Color.primary.opacity(0.07)))
        }
        .buttonStyle(.hoverCircle)
        .help(on ? "Desligar" : "Ligar")
        .accessibilityLabel(on ? "Desligar" : "Ligar")
        .disabled(ac.showSettings || !ac.hasLoaded)
        .animation(.easeInOut(duration: 0.2), value: on)
    }

    // MARK: Controles

    private var controls: some View {
        VStack(alignment: .leading, spacing: 22) {
            setpoint
            modes

            selectors
        }
        .disabled(!ac.hasLoaded)
    }

    private var setpoint: some View {
        TemperatureDial(value: ac.state.setpoint,
                        range: ac.state.setpointMin...max(ac.state.setpointMin, ac.state.setpointMax),
                        mode: ac.state.mode,
                        power: ac.state.power) { ac.stepSetpoint($0) }
    }

    private var modes: some View {
        HStack(spacing: 6) {
            ForEach(ac.state.supportedModes, id: \.self) { mode in
                let selected = ac.state.mode == mode
                let tint = ModeColor.of(mode)
                Button { ac.setMode(mode) } label: {
                    Image(systemName: Labels.modeIcon(mode))
                        .font(.system(size: 17))
                        .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selected ? tint.opacity(0.22) : Color.primary.opacity(0.05))
                    )
                    .foregroundStyle(selected ? tint : Color.primary)
                }
                .buttonStyle(.hover(cornerRadius: 8))
                .help(Labels.mode(mode))
                .accessibilityLabel(Labels.mode(mode))
            }
        }
    }

    private var selectors: some View {
        let st = ac.state
        let onOff = ["Desligado", "Ligado"]
        return HStack(spacing: 8) {
            SelectorTile(icon: "fan", title: "Velocidade", value: Labels.fan(st.fanMode)) {
                st.supportedFanModes.map { fan in .init(title: Labels.fan(fan), selected: fan == st.fanMode) { ac.setFan(fan) } }
            }
            SelectorTile(icon: "moon.zzz", title: "Sono", value: onOff[st.isSleep ? 1 : 0], active: st.isSleep) {
                [false, true].map { on in .init(title: onOff[on ? 1 : 0], selected: on == st.isSleep) { ac.setSleep(on) } }
            }
            .disabled(!st.supportedOptionalModes.contains("sleep"))
            SelectorTile(icon: "arrow.up.and.down.and.arrow.left.and.right", iconSize: 15, title: "Direção",
                         value: Labels.oscillation(st.oscillation)) {
                st.supportedOscillation.map { o in .init(title: Labels.oscillation(o), selected: o == st.oscillation) { ac.setOscillation(o) } }
            }
            SelectorTile(icon: "fan.slash", title: "WindFree", value: onOff[st.isWindFree ? 1 : 0], active: st.isWindFree) {
                [false, true].map { on in .init(title: onOff[on ? 1 : 0], selected: on == st.isWindFree) { ac.setWindFree(on) } }
            }
            .disabled(!st.supportedOptionalModes.contains("windFree"))
        }
    }

    // MARK: Rodapé

    private var footer: some View {
        HStack(spacing: 4) {
            if !ac.showSettings {
                Button { ac.showSettings = true } label: { footerIcon("gearshape") }
                    .help("Configurações")
            } else if ac.isConnected {
                // Sem conexão não há para onde voltar: o painel ficaria vazio.
                Button { ac.showSettings = false } label: { footerIcon("chevron.left") }
                    .help("Voltar")
                    .keyboardShortcut(.cancelAction)
            }
            if ac.isBusy { ProgressView().controlSize(.small).padding(.leading, 4) }
            Spacer()
        }
        .buttonStyle(.hover(cornerRadius: 6))
        .padding(.horizontal, -6)   // alinha os ícones com a margem, já que o hover tem folga
    }

    private func footerIcon(_ symbol: String) -> some View {
        Image(systemName: symbol).frame(width: 26, height: 26)
    }
}

struct SettingsView: View {
    @EnvironmentObject var ac: ACController
    @Environment(\.openURL) private var openURL
    // Guardados fora da view: o painel do menu bar é recriado quando você vai ao navegador.
    @AppStorage("oauthClientId") private var clientId = ""
    @State private var code = ""
    private var clientSecret: Binding<String> { $ac.draftClientSecret }
    @State private var working = false
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            connection
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Aparência")
                Picker("", selection: $appearance) {
                    ForEach(AppAppearance.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .onChange(of: appearance) { $0.apply() }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Inicialização")
                LaunchAtLoginToggle()
                    .disabled(ac.isDemo)   // registraria o executável de desenvolvimento no login
            }
            Button("Sair do WindFree") { NSApp.terminate(nil) }
        }
        .onAppear { if clientId.isEmpty { clientId = ac.savedClientId } }
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Conexão com a SmartThings")

            if ac.isConnected {
                Label("Conectado. O acesso é renovado automaticamente.", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                HStack {
                    Button("Atualizar agora") { Task { await ac.refresh(askDevice: true) } }
                        .help("Pede ao aparelho o estado atual")
                    Button("Desconectar", role: .destructive) { ac.disconnect() }
                        .disabled(ac.isDemo)
                }
            } else {
                step("1", "Client ID e Client Secret do app OAuth da SmartThings")
                TextField("Client ID", text: $clientId)
                    .textFieldStyle(.roundedBorder)
                SecureField("Client Secret", text: clientSecret)
                    .textFieldStyle(.roundedBorder)

                step("2", "Autorize no navegador")
                Button("Abrir página de autorização") {
                    openURL(ac.authorizeURL(clientId: clientId))
                }
                .disabled(clientId.isEmpty)

                step("3", "Depois de autorizar, copie o endereço da página que abrir (ou só o código) e cole aqui")
                TextField("https://httpbin.org/get?code=…", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(connect)

                HStack {
                    Spacer()
                    if working { ProgressView().controlSize(.small) }
                    Button("Conectar", action: connect)
                        .keyboardShortcut(.defaultAction)
                        .disabled(clientId.isEmpty || ac.draftClientSecret.isEmpty || code.isEmpty || working)
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold))
    }

    private func step(_ number: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(number)
                .font(.caption2.weight(.bold))
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.accentColor.opacity(0.2)))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private func connect() {
        working = true
        Task {
            await ac.connect(clientId: clientId, clientSecret: ac.draftClientSecret, code: code)
            working = false
            if ac.isConnected { code = ""; ac.draftClientSecret = "" }
        }
    }
}

struct LaunchAtLoginToggle: View {
    @State private var enabled = LaunchAtLogin.isEnabled
    @State private var needsApproval = LaunchAtLogin.needsApproval
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Abrir ao iniciar o Mac", isOn: Binding(get: { enabled }, set: update))
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.caption)
            if needsApproval {
                Button("Aprovar em Itens de Início") { LaunchAtLogin.openLoginItemsSettings() }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            if let error {
                Text(error).font(.caption2).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear(perform: sync)
    }

    private func update(_ value: Bool) {
        do {
            try LaunchAtLogin.set(value)
            error = nil
        } catch {
            let code = (error as NSError).code
            self.error = "Não foi possível alterar (código \(code)). O app precisa estar em /Applications."
        }
        sync()
    }

    private func sync() {
        enabled = LaunchAtLogin.isEnabled
        needsApproval = LaunchAtLogin.needsApproval
    }
}
