import Foundation

/// Titels en bestandsnamen voor documenten in de kluis.
public enum DocumentNamen {
    /// Een leesbare titel uit een bestandsnaam: "beschikking_wmo-2026.pdf" → "Beschikking wmo 2026".
    public static func titel(uitBestandsnaam naam: String) -> String {
        var basis = naam
        if let punt = basis.lastIndex(of: "."), basis.distance(from: punt, to: basis.endIndex) <= 5, punt != basis.startIndex {
            basis = String(basis[..<punt])
        }
        let woorden = basis
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
        guard let eerste = woorden.first else { return "" }
        let zin = woorden.joined(separator: " ")
        return eerste.first.map { String($0).uppercased() + zin.dropFirst() } ?? zin
    }

    /// Titel voor een nieuwe scan: "Scan 23 nov 2026".
    public static func scanTitel(op datum: Date, locale: Locale = Locale(identifier: "nl_NL")) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return "Scan \(formatter.string(from: datum))"
    }

    /// Veilige bestandsnaam voor delen/exporteren: geen tekens die bestandssystemen weigeren.
    public static func bestandsnaam(voorTitel titel: String, extensie: String = "pdf") -> String {
        let verboden = CharacterSet(charactersIn: "/\\:?%*|\"<>")
            .union(.newlines)
            .union(.controlCharacters)
        let schoon = titel.unicodeScalars
            .map { verboden.contains($0) ? " " : String($0) }
            .joined()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let basis = schoon.isEmpty ? "Document" : String(schoon.prefix(100))
        return "\(basis).\(extensie)"
    }
}
