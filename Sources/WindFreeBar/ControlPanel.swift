import SwiftUI
import AppKit

struct ControlPanel: View {
    @EnvironmentObject var ac: ACController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()

            if ac.showSettings {
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
            Toggle("", isOn: Binding(get: { ac.state.power }, set: { ac.setPower($0) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(ac.showSettings || !ac.hasLoaded)
        }
    }

    // MARK: Controles

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            setpoint
            modes

            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("Velocidade")
                Picker("", selection: Binding(get: { ac.state.fanMode }, set: { ac.setFan($0) })) {
                    ForEach(ac.state.supportedFanModes, id: \.self) { Text(Labels.fan($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            windFreeToggle

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    sectionTitle("Direção")
                    Picker("", selection: Binding(get: { ac.state.oscillation }, set: { ac.setOscillation($0) })) {
                        ForEach(ac.state.supportedOscillation, id: \.self) { Text(Labels.oscillation($0)).tag($0) }
                    }
                    .labelsHidden()
                }
                GridRow {
                    sectionTitle("Modo especial")
                    Picker("", selection: Binding(get: { ac.state.optionalMode }, set: { ac.setOptionalMode($0) })) {
                        ForEach(ac.state.supportedOptionalModes, id: \.self) { Text(Labels.optional($0)).tag($0) }
                    }
                    .labelsHidden()
                }
                GridRow {
                    sectionTitle("Auto limpeza")
                    Toggle("", isOn: Binding(get: { ac.state.autoClean }, set: { ac.setAutoClean($0) }))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
            }
        }
        .disabled(!ac.hasLoaded)
    }

    private var setpoint: some View {
        HStack {
            stepButton("minus") { ac.stepSetpoint(-1) }
                .disabled(ac.state.setpoint <= ac.state.setpointMin)
            Spacer()
            Text("\(ac.state.setpoint)°")
                .font(.system(size: 44, weight: .light, design: .rounded))
                .monospacedDigit()
            Spacer()
            stepButton("plus") { ac.stepSetpoint(1) }
                .disabled(ac.state.setpoint >= ac.state.setpointMax)
        }
    }

    private var modes: some View {
        HStack(spacing: 6) {
            ForEach(ac.state.supportedModes, id: \.self) { mode in
                let selected = ac.state.mode == mode
                Button { ac.setMode(mode) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: Labels.modeIcon(mode)).font(.system(size: 15))
                        Text(Labels.mode(mode)).font(.caption2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.05))
                    )
                    .foregroundStyle(selected ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var windFreeToggle: some View {
        Button {
            ac.setOptionalMode(ac.state.isWindFree ? "off" : "windFree")
        } label: {
            HStack {
                Image(systemName: "wind.circle")
                Text("WindFree")
                Spacer()
                Text(ac.state.isWindFree ? "Ligado" : "Desligado")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ac.state.isWindFree ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .disabled(!ac.state.supportedOptionalModes.contains("windFree"))
    }

    // MARK: Rodapé

    private var footer: some View {
        HStack(spacing: 14) {
            Button { Task { await ac.refresh(askDevice: true) } } label: { Image(systemName: "arrow.clockwise") }
                .help("Atualizar")
            Button { ac.showSettings.toggle() } label: { Image(systemName: "gearshape") }
                .help("Configurações")
            if ac.isBusy { ProgressView().controlSize(.small) }
            Spacer()
            Button("Sair") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
    }

    // MARK: Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.primary.opacity(0.07)))
        }
        .buttonStyle(.plain)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Conexão com a SmartThings").font(.subheadline.weight(.semibold))

            if ac.isConnected {
                Label("Conectado. O acesso é renovado automaticamente.", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                HStack {
                    Button("Desconectar", role: .destructive) { ac.disconnect() }
                    Spacer()
                    Button("Fechar") { ac.showSettings = false }
                        .keyboardShortcut(.defaultAction)
                }
            } else {
                step("1", "Dados do app OAuth criado na SmartThings CLI")
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
        .onAppear { if clientId.isEmpty { clientId = ac.savedClientId } }
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
