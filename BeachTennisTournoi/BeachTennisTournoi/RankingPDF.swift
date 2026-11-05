import Foundation
import PDFKit

/// Lecture locale des classements beach tennis publiés par la FFT (PDF « Dames » et « Messieurs »).
/// Seuls le numéro de licence et le rang sont conservés : les noms et les clubs sont ignorés.
enum RankingPDF {
    struct Result {
        let sex: String?      // "M" (messieurs), "D" (dames) ou nil si le nom du fichier ne le dit pas
        let month: String?    // par exemple « Octobre 2026 », lu dans le nom du fichier
        let rows: [[Int]]     // [numéro de licence sans zéros initiaux ni lettre, rang]
    }

    private static let months = ["janvier", "fevrier", "mars", "avril", "mai", "juin", "juillet",
                                 "aout", "septembre", "octobre", "novembre", "decembre"]

    static func parse(url: URL, displayName: String? = nil) -> Result? {
        guard let doc = PDFDocument(url: url) else { return nil }
        var rows: [[Int]] = []
        var seen = Set<Int>()
        for i in 0..<doc.pageCount {
            guard let text = doc.page(at: i)?.string else { continue }
            text.enumerateLines { line, _ in
                // Colonnes : Rang, Points, Nom, Prénom, N° licence, Club (code), Nom club, Nom ligue, Nb de tournois
                let c = line.split(whereSeparator: { $0.isWhitespace })
                guard c.count >= 7, let rank = Int(c[0]), Double(c[1]) != nil else { return }
                guard let tok = c.dropFirst(2).first(where: { $0.count >= 5 && $0.count <= 7 && $0.allSatisfy(\.isNumber) }),
                      let lic = Int(tok) else { return }
                if seen.insert(lic).inserted { rows.append([lic, rank]) }   // en cas de doublon, on garde le meilleur rang (premier)
            }
        }
        guard rows.count >= 50 else { return nil }   // ce n'est pas un classement
        let name = (displayName ?? url.lastPathComponent)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
        let sex: String? = name.contains("dames") ? "D" : (name.contains("messieurs") ? "M" : nil)
        var month: String?
        for m in months where name.contains(m) {
            if let r = name.range(of: m + "[^0-9]{0,3}(20[0-9]{2})", options: .regularExpression) {
                let year = String(name[r].suffix(4))
                month = (m == "fevrier" ? "Février" : m == "aout" ? "Août" : m == "decembre" ? "Décembre" : m.capitalized) + " " + year
            }
        }
        return Result(sex: sex, month: month, rows: rows)
    }

    /// JSON transmis à la page : [{"name","sex","month","rows":[[licence,rang],…]}, …]
    static func json(for results: [(name: String, result: Result)]) -> String {
        let arr: [[String: Any]] = results.map { r in
            ["name": r.name, "sex": r.result.sex as Any? ?? NSNull(), "month": r.result.month as Any? ?? NSNull(), "rows": r.result.rows]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: arr), let s = String(data: data, encoding: .utf8) else { return "[]" }
        return s
    }
}
