import Foundation

struct OAuthCredentials: Codable {
    var clientId: String
    var clientSecret: String
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

enum OAuthConfig {
    /// Mesmo endereço cadastrado como Redirect URI no app OAuth-In da SmartThings.
    static let redirectURI = "https://httpbin.org/get"
    static let scopes = "r:devices:* w:devices:* x:devices:*"
    static let tokenURL = URL(string: "https://api.smartthings.com/oauth/token")!

    static func authorizeURL(clientId: String) -> URL {
        var c = URLComponents(string: "https://api.smartthings.com/oauth/authorize")!
        c.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
        ]
        return c.url!
    }
}

/// Mantém um access token válido: renova sozinho com o refresh token antes de expirar.
@MainActor
final class AuthManager {
    private(set) var credentials: OAuthCredentials?
    private var refreshTask: Task<OAuthCredentials, Error>?

    /// - Parameter credentials: na pré-visualização passa `nil` para não ler o Keychain.
    init(credentials: OAuthCredentials? = Keychain.loadCredentials()) {
        self.credentials = credentials
    }

    var isConfigured: Bool { credentials != nil }

    /// Token pronto para uso. Renova se faltarem menos de 5 minutos para expirar.
    func accessToken() async throws -> String {
        guard let c = credentials else { throw SmartThingsError.unauthorized }
        if c.expiresAt.timeIntervalSinceNow > 300 { return c.accessToken }
        return try await refresh().accessToken
    }

    /// Troca o refresh token por um novo par de tokens. Chamadas simultâneas compartilham a mesma renovação.
    @discardableResult
    func refresh() async throws -> OAuthCredentials {
        if let running = refreshTask { return try await running.value }
        guard let c = credentials else { throw SmartThingsError.unauthorized }

        let task = Task {
            try await Self.requestToken(clientId: c.clientId, clientSecret: c.clientSecret, params: [
                "grant_type": "refresh_token",
                "refresh_token": c.refreshToken,
                "client_id": c.clientId,
            ])
        }
        refreshTask = task
        defer { refreshTask = nil }

        do {
            let new = try await task.value
            store(new)
            return new
        } catch SmartThingsError.oauthRejected(_) {
            // Refresh token inválido ou vencido: é preciso autorizar de novo.
            disconnect()
            throw SmartThingsError.sessionExpired
        }
    }

    /// Primeira conexão: troca o código de autorização pelos tokens.
    func connect(clientId: String, clientSecret: String, codeInput: String) async throws {
        let code = Self.extractCode(codeInput)
        let new = try await Self.requestToken(clientId: clientId, clientSecret: clientSecret, params: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": OAuthConfig.redirectURI,
            "client_id": clientId,
        ])
        store(new)
    }

    func disconnect() {
        credentials = nil
        Keychain.deleteCredentials()
    }

    private func store(_ new: OAuthCredentials) {
        credentials = new
        Keychain.saveCredentials(new)
    }

    // MARK: - Helpers

    /// Aceita o código puro, o endereço da página do httpbin ou o JSON que ela mostra.
    nonisolated static func extractCode(_ input: String) -> String {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Qualquer texto com "code=…" (endereço, linha do JSON, página inteira).
        if let range = text.range(of: #"code=([^&"'\s,}]+)"#, options: .regularExpression) {
            return String(text[range].dropFirst("code=".count))
        }
        // Linha do JSON do httpbin: "code": "xxxx"
        if let range = text.range(of: #""code"\s*:\s*"([^"]+)""#, options: .regularExpression) {
            let match = String(text[range])
            if let value = match.split(separator: "\"").dropFirst(2).first(where: { !$0.contains(":") }) {
                return String(value)
            }
        }
        if let items = URLComponents(string: text)?.queryItems,
           let code = items.first(where: { $0.name == "code" })?.value {
            return code
        }
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let args = json["args"] as? [String: Any],
           let code = args["code"] as? String {
            return code
        }
        return text
    }

    nonisolated private static func requestToken(clientId: String, clientSecret: String,
                                                 params: [String: String]) async throws -> OAuthCredentials {
        var req = URLRequest(url: OAuthConfig.tokenURL)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        let basic = Data("\(clientId):\(clientSecret)".utf8).base64EncodedString()
        req.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data(formEncode(params).utf8)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw SmartThingsError.unexpectedResponse }
        let body = String(data: data, encoding: .utf8) ?? ""
        switch http.statusCode {
        case 200..<300: break
        case 400, 401: throw SmartThingsError.oauthRejected(body.isEmpty ? tr("código inválido ou já usado (HTTP \(http.statusCode)). Autorize de novo.", "invalid or already used code (HTTP \(http.statusCode)). Authorize again.") : body)
        default: throw SmartThingsError.http(http.statusCode, body)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let access = json["access_token"] as? String,
            let refresh = json["refresh_token"] as? String
        else { throw SmartThingsError.unexpectedResponse }
        let expiresIn = (json["expires_in"] as? NSNumber)?.doubleValue ?? 86_400

        return OAuthCredentials(clientId: clientId, clientSecret: clientSecret,
                                accessToken: access, refreshToken: refresh,
                                expiresAt: Date().addingTimeInterval(expiresIn))
    }

    nonisolated private static func formEncode(_ params: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return params.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
    }
}
