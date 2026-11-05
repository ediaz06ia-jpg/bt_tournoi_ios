import Foundation

/// Sauvegarde native des tournois (copie du localStorage de la page dans Application Support).
/// Le WebView peut purger son localStorage ; ce fichier fait foi et est réinjecté à chaque lancement.
enum TournamentStore {
    static let storageKey = "bt-tournoi-v2"

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("tournois.json")
    }

    static func load() -> String? {
        try? String(contentsOf: fileURL, encoding: .utf8)
    }

    static func save(_ json: String) {
        try? json.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Fichier temporaire partageable (Fichiers, AirDrop, mail) pour la sauvegarde.
    static func exportFile(_ json: String) -> URL? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmm"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tournois-beach-tennis_\(f.string(from: Date())).json")
        do {
            try json.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
