import Foundation

/// Versão instalada, gravada no Info.plist do app pelo build.sh: versão (manual), build (nº de commits) e
/// commit ("+" = havia mudanças não commitadas). Rodando com `swift run` não há Info.plist.
enum AppVersion {
    static var label: String {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let version = info["CFBundleShortVersionString"] as? String else {
            return tr("WindFree (desenvolvimento)", "WindFree (development)")
        }
        let build = info["CFBundleVersion"] as? String ?? "?"
        let commit = (info["WindFreeCommit"] as? String).map { " · \($0)" } ?? ""
        return "WindFree \(version) (\(build)\(commit))"
    }
}
