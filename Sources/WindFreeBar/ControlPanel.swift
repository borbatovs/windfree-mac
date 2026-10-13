import SwiftUI
import AppKit

struct ControlPanel: View {
    @EnvironmentObject var ac: ACController
    /// Ao trocar o idioma o painel é reconstruído (`.id`), para todos os textos `tr(...)` mudarem na hora.
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.pt

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
                    .overlay {
                        // Só explica ao passar o mouse; os cliques já estão bloqueados pelo .disabled.
                        if !ac.state.power {
                            Color.clear.contentShape(Rectangle()).help(tr("Ligue o ar para alterar", "Turn the AC on to change this"))
                        }
                    }
            }

            if let error = ac.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !ac.showSettings {
                Divider()
                footer
            }
        }
        .id(language)
        .padding(16)
        .frame(width: 320)
        .background {
            let st = ac.state
            let range = st.setpointMin...max(st.setpointMin, st.setpointMax)
            ZStack {
                ModeGlow(power: st.power, mode: st.mode, setpoint: st.setpoint, range: range)
                // Frio extremo: neve nos 3 graus mais baixos (16–18°), mais intensa no mínimo.
                Snowfall(amount: st.power && st.mode == "cool"
                         ? Double(max(0, min(3, range.lowerBound + 3 - st.setpoint))) / 3 : 0)
            }
        }
        // Preso no topo: quando a janela salta para o tamanho final antes da animação de altura terminar,
        // o conteúdo não fica centralizado (o que fazia a foto deslizar).
        .frame(maxHeight: .infinity, alignment: .top)
        .task { await ac.refresh(askDevice: true) }
    }

    // MARK: Cabeçalho

    private var header: some View {
        HStack(alignment: .center, spacing: 6) {
            if ac.showSettings && ac.isConnected {
                // Sem conexão não há para onde voltar: o painel ficaria vazio.
                Button { ac.showSettings = false } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.hover(cornerRadius: 6))
                .help(tr("Voltar", "Back"))
                .keyboardShortcut(.cancelAction)
                .padding(.leading, -6)   // alinha o ícone com a margem, já que o hover tem folga
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(ac.deviceLabel).font(.headline)
                HStack(spacing: 10) {
                    if let t = ac.state.roomTemperature {
                        Label(tr("\(Int(t))° no ambiente", "\(Int(t))° in the room"), systemImage: "thermometer.medium")
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
                .symbolBounce(on: on)
                .foregroundStyle(on ? Color(nsColor: .windowBackgroundColor) : Color.secondary)
                .frame(width: 40, height: 40)
                // Ligado: cheio na cor do texto (branco no escuro, preto no claro), neutro e com contraste máximo.
                .background(Circle().fill(on ? Color.primary : Color.primary.opacity(0.07)))
        }
        .buttonStyle(.hoverCircle)
        .help(on ? tr("Desligar", "Turn off") : tr("Ligar", "Turn on"))
        .accessibilityLabel(on ? tr("Desligar", "Turn off") : tr("Ligar", "Turn on"))
        .disabled(ac.showSettings || !ac.hasLoaded)
    }

    // MARK: Controles

    private var controls: some View {
        VStack(alignment: .leading, spacing: 22) {
            setpoint
            modes

            selectors
        }
        // Desligado não envia comandos: o aparelho liga sozinho ao receber, por exemplo, um modo. Só o
        // botão de energia liga.
        .disabled(!ac.hasLoaded || !ac.state.power)
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
        let notAvailable = tr("Não disponível neste aparelho", "Not available on this unit")
        return HStack(spacing: 8) {
            SelectorTile(icon: "fan", title: tr("Velocidade", "Fan speed"), value: Labels.fan(st.fanMode),
                         iconEffect: .spin(speed: FanSpin.speed(st.fanMode)), iconEffectActive: st.power) {
                st.supportedFanModes.map { fan in .init(title: Labels.fan(fan), selected: fan == st.fanMode) { ac.setFan(fan) } }
            }
            SelectorTile(icon: "moon.zzz", title: tr("Sono", "Sleep"), value: Labels.onOff(st.isSleep), active: st.isSleep,
                         unavailableReason: st.supportedOptionalModes.contains("sleep") ? nil : notAvailable) {
                [false, true].map { on in .init(title: Labels.onOff(on), selected: on == st.isSleep) { ac.setSleep(on) } }
            }
            SelectorTile(icon: "arrow.up.and.down.and.arrow.left.and.right", iconSize: 15, title: tr("Direção", "Airflow"),
                         value: Labels.oscillation(st.oscillation)) {
                st.supportedOscillation.map { o in .init(title: Labels.oscillation(o), selected: o == st.oscillation) { ac.setOscillation(o) } }
            }
            // O aparelho recusa WindFree no modo Quente (testado em 12/10/2026).
            SelectorTile(icon: "fan.slash", title: "WindFree", value: Labels.onOff(st.isWindFree), active: st.isWindFree,
                         unavailableReason: !st.supportedOptionalModes.contains("windFree") ? notAvailable
                            : st.mode == "heat" ? tr("WindFree não funciona no modo Quente", "WindFree doesn't work in Heat mode") : nil) {
                [false, true].map { on in .init(title: Labels.onOff(on), selected: on == st.isWindFree) { ac.setWindFree(on) } }
            }
        }
    }

    // MARK: Rodapé

    private var footer: some View {
        HStack(spacing: 4) {
            Button { ac.showSettings = true } label: { footerIcon("gearshape") }
                .help(tr("Configurações", "Settings"))
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
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.pt

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            connection
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(tr("Aparência", "Appearance"))
                Picker("", selection: $appearance) {
                    ForEach(AppAppearance.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .onChange(of: appearance) { $0.apply() }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(tr("Idioma", "Language"))
                Picker("", selection: $language) {
                    ForEach(AppLanguage.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(tr("Inicialização", "Startup"))
                LaunchAtLoginToggle()
                    .disabled(ac.isDemo)   // registraria o executável de desenvolvimento no login
            }
            VStack(alignment: .leading, spacing: 8) {
                Button(tr("Sair do WindFree", "Quit WindFree")) { NSApp.terminate(nil) }
                Text(AppVersion.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .onAppear { if clientId.isEmpty { clientId = ac.savedClientId } }
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(tr("Conexão com a SmartThings", "SmartThings connection"))

            if ac.isConnected {
                Label(tr("Conectado. O acesso é renovado automaticamente.", "Connected. Access renews automatically."), systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                HStack {
                    Button(tr("Atualizar agora", "Refresh now")) { Task { await ac.refresh(askDevice: true) } }
                        .help(tr("Pede ao aparelho o estado atual", "Ask the unit for its current state"))
                    Button(tr("Desconectar", "Disconnect"), role: .destructive) { ac.disconnect() }
                        .disabled(ac.isDemo)
                }
            } else {
                step("1", tr("Client ID e Client Secret do app OAuth da SmartThings", "Client ID and Client Secret of the SmartThings OAuth app"))
                TextField("Client ID", text: $clientId)
                    .textFieldStyle(.roundedBorder)
                SecureField("Client Secret", text: clientSecret)
                    .textFieldStyle(.roundedBorder)

                step("2", tr("Autorize no navegador", "Authorize in the browser"))
                Button(tr("Abrir página de autorização", "Open authorization page")) {
                    openURL(ac.authorizeURL(clientId: clientId))
                }
                .disabled(clientId.isEmpty)

                step("3", tr("Depois de autorizar, copie o endereço da página que abrir (ou só o código) e cole aqui", "After authorizing, copy the address of the page that opens (or just the code) and paste it here"))
                TextField("https://httpbin.org/get?code=…", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(connect)

                HStack {
                    Spacer()
                    if working { ProgressView().controlSize(.small) }
                    Button(tr("Conectar", "Connect"), action: connect)
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
            Toggle(tr("Abrir ao iniciar o Mac", "Open at login"), isOn: Binding(get: { enabled }, set: update))
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.caption)
            if needsApproval {
                Button(tr("Aprovar em Itens de Início", "Approve in Login Items")) { LaunchAtLogin.openLoginItemsSettings() }
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
            self.error = tr("Não foi possível alterar (código \(code)). O app precisa estar em /Applications.", "Couldn't change it (code \(code)). The app must be in /Applications.")
        }
        sync()
    }

    private func sync() {
        enabled = LaunchAtLogin.isEnabled
        needsApproval = LaunchAtLogin.needsApproval
    }
}
