import Foundation

enum SmartThingsError: LocalizedError {
    case unauthorized
    case sessionExpired
    case forbidden
    case oauthRejected(String)
    case noAirConditioner
    case unexpectedResponse
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return tr("Não conectado à SmartThings. Conecte nas configurações.", "Not connected to SmartThings. Connect in Settings.")
        case .sessionExpired: return tr("A autorização expirou. Conecte de novo nas configurações.", "Authorization expired. Connect again in Settings.")
        case .forbidden: return tr("Sem permissão. Confira se o app OAuth tem os escopos r, w e x de devices.", "Permission denied. Check that the OAuth app has the r, w and x device scopes.")
        case .oauthRejected(let body): return tr("A SmartThings recusou a autorização: ", "SmartThings rejected the authorization: ") + body.prefix(160)
        case .noAirConditioner: return tr("Nenhum ar-condicionado encontrado na conta SmartThings.", "No air conditioner found in the SmartThings account.")
        case .unexpectedResponse: return tr("Resposta inesperada da SmartThings.", "Unexpected response from SmartThings.")
        case .http(429, _): return tr("Muitas requisições seguidas. Aguarde um pouco e tente de novo.", "Too many requests. Wait a moment and try again.")
        case .http(let code, _) where code >= 500:
            return tr("A SmartThings está com instabilidade (erro \(code)). Tente de novo mais tarde.", "SmartThings is having problems (error \(code)). Try again later.")
        case .http(let code, let body): return tr("Erro \(code) da SmartThings: ", "SmartThings error \(code): ") + body.prefix(160)
        }
    }

    /// Mensagem em português para qualquer erro. Os erros do sistema (rede, JSON) viriam no idioma do Mac.
    static func message(for error: Error) -> String {
        if let st = error as? SmartThingsError { return st.errorDescription ?? "" }
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return tr("Sem conexão com a internet. O app tenta de novo sozinho a cada minuto.", "No internet connection. The app retries every minute.")
            case .timedOut:
                return tr("A SmartThings demorou para responder. Tente de novo em instantes.", "SmartThings took too long to respond. Try again shortly.")
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return tr("Não foi possível alcançar a SmartThings. Confira a internet.", "Couldn't reach SmartThings. Check your internet connection.")
            case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
                 .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot:
                return tr("Falha na conexão segura com a SmartThings.", "Secure connection to SmartThings failed.")
            default:
                return tr("Erro de rede (código \(url.code.rawValue)). Tente de novo.", "Network error (code \(url.code.rawValue)). Try again.")
            }
        }
        let ns = error as NSError
        return tr("Erro inesperado (\(ns.domain) \(ns.code)). Tente atualizar.", "Unexpected error (\(ns.domain) \(ns.code)). Try refreshing.")
    }

    var needsReauthorization: Bool {
        switch self {
        case .unauthorized, .sessionExpired: return true
        default: return false
        }
    }
}

/// Cliente mínimo da API REST da SmartThings (https://api.smartthings.com/v1).
struct SmartThingsClient {
    let auth: AuthManager
    private let base = "https://api.smartthings.com/v1"

    private func request(_ path: String, method: String = "GET", body: Data? = nil,
                         retryOnUnauthorized: Bool = true) async throws -> Data {
        let token = try await auth.accessToken()
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = method
        req.timeoutInterval = 15
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw SmartThingsError.unexpectedResponse }
        switch http.statusCode {
        case 200..<300:
            return data
        case 401:
            // Token recusado antes da hora: renova uma vez e tenta de novo.
            guard retryOnUnauthorized else { throw SmartThingsError.unauthorized }
            try await auth.refresh()
            return try await request(path, method: method, body: body, retryOnUnauthorized: false)
        case 403:
            throw SmartThingsError.forbidden
        default:
            throw SmartThingsError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }

    /// Procura o primeiro dispositivo que tenha a capability airConditionerMode.
    func findAirConditioner() async throws -> (id: String, label: String) {
        let data = try await request("/devices")
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = root["items"] as? [[String: Any]]
        else { throw SmartThingsError.unexpectedResponse }

        for item in items {
            let components = item["components"] as? [[String: Any]] ?? []
            let capabilities = components
                .flatMap { $0["capabilities"] as? [[String: Any]] ?? [] }
                .compactMap { $0["id"] as? String }
            if capabilities.contains("airConditionerMode"), let id = item["deviceId"] as? String {
                return (id, Self.label(of: item))
            }
        }
        throw SmartThingsError.noAirConditioner
    }

    /// Nome atual do aparelho (muda quando o usuário renomeia no app SmartThings).
    func label(deviceId: String) async throws -> String {
        let data = try await request("/devices/\(deviceId)")
        guard let item = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw SmartThingsError.unexpectedResponse }
        return Self.label(of: item)
    }

    private static func label(of item: [String: Any]) -> String {
        (item["label"] as? String) ?? (item["name"] as? String) ?? tr("Ar-condicionado", "Air conditioner")
    }

    func status(deviceId: String) async throws -> ACState {
        try ACState.parse(try await request("/devices/\(deviceId)/status"))
    }

    /// POST /devices/{id}/commands — um comando no componente "main".
    func send(deviceId: String, capability: String, command: String, arguments: [Any] = []) async throws {
        var cmd: [String: Any] = ["component": "main", "capability": capability, "command": command]
        if !arguments.isEmpty { cmd["arguments"] = arguments }
        let body = try JSONSerialization.data(withJSONObject: ["commands": [cmd]])
        _ = try await request("/devices/\(deviceId)/commands", method: "POST", body: body)
    }
}
