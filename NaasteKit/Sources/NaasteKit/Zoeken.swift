import Foundation

/// Zoeken in documenten (titel + herkende tekst), ongevoelig voor hoofdletters en accenten.
public enum Zoeken {
    private static let opties: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// Losse zoekwoorden uit de invoer (lege en dubbele spaties genegeerd).
    public static func woorden(_ zoekterm: String) -> [String] {
        zoekterm
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)
    }

    /// `true` als elk zoekwoord in minstens één van de velden voorkomt.
    /// Een lege zoekterm past altijd.
    public static func past(_ zoekterm: String, in velden: [String?]) -> Bool {
        let woorden = woorden(zoekterm)
        guard !woorden.isEmpty else { return true }
        let teksten = velden.compactMap { $0 }
        return woorden.allSatisfy { woord in
            teksten.contains { $0.range(of: woord, options: opties) != nil }
        }
    }

    /// Een kort tekstfragment rond de eerste treffer, voor in de zoekresultaten.
    /// Witruimte (regeleinden van de scan) wordt samengevoegd tot enkele spaties.
    public static func fragment(voor zoekterm: String, in tekst: String?, context: Int = 40) -> String? {
        guard let tekst, let eersteWoord = woorden(zoekterm).first else { return nil }
        let plat = tekst.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
        guard let treffer = plat.range(of: eersteWoord, options: opties) else { return nil }

        var begin = plat.index(treffer.lowerBound, offsetBy: -context, limitedBy: plat.startIndex) ?? plat.startIndex
        var eind = plat.index(treffer.upperBound, offsetBy: context, limitedBy: plat.endIndex) ?? plat.endIndex
        // Niet midden in een woord afbreken.
        if begin > plat.startIndex, let spatie = plat[begin..<treffer.lowerBound].firstIndex(of: " ") {
            begin = plat.index(after: spatie)
        }
        if eind < plat.endIndex, let spatie = plat[treffer.upperBound..<eind].lastIndex(of: " ") {
            eind = spatie
        }
        var resultaat = String(plat[begin..<eind]).trimmingCharacters(in: .whitespaces)
        if begin > plat.startIndex { resultaat = "…" + resultaat }
        if eind < plat.endIndex { resultaat += "…" }
        return resultaat
    }
}

/// Hulp voor bellen en mailen in één tik.
public enum ContactLinks {
    /// `tel:`-URL met alleen cijfers en een eventuele `+` aan het begin.
    public static func belURL(_ nummer: String?) -> URL? {
        guard let nummer else { return nil }
        // "+31 (0)30 …" → de "(0)" hoort niet bij een internationaal nummer.
        let zonderNul = nummer.replacingOccurrences(of: "(0)", with: "")
        var schoon = ""
        for teken in zonderNul.trimmingCharacters(in: .whitespacesAndNewlines) {
            if teken.isASCII, teken.isNumber {
                schoon.append(teken)
            } else if teken == "+", schoon.isEmpty {
                schoon.append(teken)
            }
        }
        let cijfers = schoon.filter(\.isNumber)
        guard cijfers.count >= 3 else { return nil }
        return URL(string: "tel:\(schoon)")
    }

    /// `mailto:`-URL als het adres er plausibel uitziet.
    public static func mailURL(_ adres: String?) -> URL? {
        guard let adres = adres?.trimmingCharacters(in: .whitespacesAndNewlines),
              !adres.isEmpty, !adres.contains(" ") else { return nil }
        let delen = adres.split(separator: "@", omittingEmptySubsequences: false)
        guard delen.count == 2, !delen[0].isEmpty, delen[1].contains("."),
              !delen[1].hasPrefix("."), !delen[1].hasSuffix(".") else { return nil }
        return URL(string: "mailto:\(adres)")
    }
}
