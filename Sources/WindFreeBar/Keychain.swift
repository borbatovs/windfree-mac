import Foundation
import Security

/// Guarda as credenciais da SmartThings no Keychain do macOS.
enum Keychain {
    private static let service = "WindFreeBar"
    private static let oauthAccount = "smartthings-oauth"
    private static let legacyTokenAccount = "smartthings-token"

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func readData(_ account: String) -> Data? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func save(_ data: Data, account: String) {
        delete(account)
        var q = query(account)
        q[kSecValueData as String] = data
        SecItemAdd(q as CFDictionary, nil)
    }

    static func delete(_ account: String) {
        SecItemDelete(query(account) as CFDictionary)
    }

    // MARK: OAuth

    static func loadCredentials() -> OAuthCredentials? {
        guard let data = readData(oauthAccount) else { return nil }
        return try? JSONDecoder().decode(OAuthCredentials.self, from: data)
    }

    static func saveCredentials(_ credentials: OAuthCredentials) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        save(data, account: oauthAccount)
        delete(legacyTokenAccount)   // remove o token pessoal antigo, se existir
    }

    static func deleteCredentials() {
        delete(oauthAccount)
    }
}
