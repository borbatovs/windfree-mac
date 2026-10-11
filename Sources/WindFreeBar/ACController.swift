import Foundation
import SwiftUI

@MainActor
final class ACController: ObservableObject {
    @Published var state = ACState()
    @Published var deviceLabel = "Ar-condicionado"
    @Published var errorMessage: String?
    @Published var isBusy = false
    @Published var hasLoaded = false
    @Published var showSettings: Bool

    private var deviceId: String? {
        get { UserDefaults.standard.string(forKey: "deviceId") }
        set { UserDefaults.standard.set(newValue, forKey: "deviceId") }
    }
    private var pollTimer: Timer?
    private var setpointTask: Task<Void, Never>?
    private var followUpTask: Task<Void, Never>?

    /// Valores enviados que a nuvem ainda não confirmou.
    /// O aparelho não reporta em tempo real (reportStateRealtime = disabled), então por alguns
    /// segundos a API devolve o estado antigo. Enquanto não chega a confirmação, o valor pedido prevalece.
    private struct Pending {
        let apply: (inout ACState) -> Void
        let expires: Date
    }
    private var pending: [String: Pending] = [:]
    private let pendingWindow: TimeInterval = 45

    let auth: AuthManager
    @Published var isConnected: Bool
    /// Client Secret digitado mas ainda não salvo (some se o app fechar).
    @Published var draftClientSecret = ""

    init() {
        auth = AuthManager()
        isConnected = auth.isConfigured
        showSettings = !auth.isConfigured
        if let label = UserDefaults.standard.string(forKey: "deviceLabel") { deviceLabel = label }

        // Atualiza a cada 60 s, mesmo com o painel fechado. Isso também mantém o token renovado.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
        Task { await refresh(askDevice: true) }
    }

    private var client: SmartThingsClient? { auth.isConfigured ? SmartThingsClient(auth: auth) : nil }

    // MARK: - Configuração

    var savedClientId: String { auth.credentials?.clientId ?? "" }

    func authorizeURL(clientId: String) -> URL {
        OAuthConfig.authorizeURL(clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func connect(clientId: String, clientSecret: String, code: String) async {
        do {
            try await auth.connect(
                clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
                clientSecret: clientSecret.trimmingCharacters(in: .whitespacesAndNewlines),
                codeInput: code)
            isConnected = true
            deviceId = nil
            errorMessage = nil
            await refresh(askDevice: true)
            if errorMessage == nil { showSettings = false }
        } catch {
            handle(error)
        }
    }

    func disconnect() {
        auth.disconnect()
        isConnected = false
        hasLoaded = false
        showSettings = true
    }

    // MARK: - Leitura

    /// - Parameter askDevice: antes de ler, pede ao aparelho que reporte o estado atual
    ///   (capability `refresh`) e espera um pouco para a nuvem atualizar.
    func refresh(askDevice: Bool = false) async {
        guard let client else { return }
        do {
            if deviceId == nil {
                let found = try await client.findAirConditioner()
                deviceId = found.id
                setLabel(found.label)
            }
            guard let deviceId else { return }

            if askDevice {
                if let label = try? await client.label(deviceId: deviceId) { setLabel(label) }
                try? await client.send(deviceId: deviceId, capability: "refresh", command: "refresh")
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }

            let fresh = try await client.status(deviceId: deviceId)
            state = merge(fresh)
            hasLoaded = true
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    private func setLabel(_ label: String) {
        guard label != deviceLabel else { return }
        deviceLabel = label
        UserDefaults.standard.set(label, forKey: "deviceLabel")
    }

    /// Combina o estado vindo da nuvem com os comandos ainda não confirmados.
    private func merge(_ fresh: ACState) -> ACState {
        var merged = fresh
        let now = Date()
        for (key, item) in pending {
            var withCommand = fresh
            item.apply(&withCommand)
            let confirmed = withCommand == fresh   // a nuvem já mostra o valor pedido
            if confirmed || item.expires < now {
                pending[key] = nil
            } else {
                item.apply(&merged)
            }
        }
        // Não sobrescreve a temperatura enquanto o usuário ainda está clicando em − / +.
        if setpointTask != nil { merged.setpoint = state.setpoint }
        return merged
    }

    // MARK: - Comandos

    func setPower(_ on: Bool) {
        send("switch", on ? "on" : "off") { $0.power = on }
    }

    func setMode(_ mode: String) {
        send("airConditionerMode", "setAirConditionerMode", [mode]) { $0.mode = mode }
    }

    func setFan(_ fan: String) {
        send("airConditionerFanMode", "setFanMode", [fan]) { $0.fanMode = fan }
    }

    func setOscillation(_ value: String) {
        send("fanOscillationMode", "setFanOscillationMode", [value]) { $0.oscillation = value }
    }

    func setOptionalMode(_ value: String) {
        send("custom.airConditionerOptionalMode", "setAcOptionalMode", [value]) { $0.optionalMode = value }
    }

    func setAutoClean(_ on: Bool) {
        send("custom.autoCleaningMode", "setAutoCleaningMode", [on ? "on" : "off"]) { $0.autoClean = on }
    }

    /// Ajusta a temperatura localmente e só envia depois de 0,7 s sem novos cliques.
    func stepSetpoint(_ delta: Int) {
        let target = min(max(state.setpoint + delta, state.setpointMin), state.setpointMax)
        guard target != state.setpoint else { return }
        state.setpoint = target
        setpointTask?.cancel()
        setpointTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled, let self else { return }
            self.setpointTask = nil
            self.send("thermostatCoolingSetpoint", "setCoolingSetpoint", [target]) { $0.setpoint = target }
        }
    }

    private func send(_ capability: String, _ command: String, _ args: [Any] = [],
                      apply: @escaping (inout ACState) -> Void) {
        guard let client, let deviceId else { return }
        let previousState = state
        let previousPending = pending[capability]

        apply(&state)
        pending[capability] = Pending(apply: apply, expires: Date().addingTimeInterval(pendingWindow))
        isBusy = true

        Task {
            do {
                try await client.send(deviceId: deviceId, capability: capability, command: command, arguments: args)
                errorMessage = nil
                scheduleFollowUpRefresh()
            } catch {
                pending[capability] = previousPending
                state = previousState
                handle(error)
            }
            isBusy = false
        }
    }

    /// Confere o resultado em duas leituras: logo depois e uns segundos mais tarde.
    private func scheduleFollowUpRefresh() {
        followUpTask?.cancel()
        followUpTask = Task { [weak self] in
            for delay: UInt64 in [2, 8] {
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.refresh(askDevice: true)
            }
        }
    }

    private func handle(_ error: Error) {
        isConnected = auth.isConfigured
        if let st = error as? SmartThingsError, st.needsReauthorization { showSettings = true }
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
