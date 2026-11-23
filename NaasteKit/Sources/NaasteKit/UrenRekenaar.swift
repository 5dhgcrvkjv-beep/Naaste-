import Foundation

/// Eén regel uit het urenlogboek, los van Core Data.
public struct UrenRegelData: Equatable, Sendable {
    public let datum: Date
    public let minuten: Int
    /// Stabiele sleutel van het familielid (UUID-string), of `nil` als niemand gekoppeld is.
    public let persoonID: String?
    public let persoonNaam: String
    public let categorie: UrenCategorie

    public init(datum: Date, minuten: Int, persoonID: String?, persoonNaam: String, categorie: UrenCategorie) {
        self.datum = datum
        self.minuten = minuten
        self.persoonID = persoonID
        self.persoonNaam = persoonNaam
        self.categorie = categorie
    }
}

public struct UrenTotaal: Equatable, Sendable, Identifiable {
    public let id: String
    public let naam: String
    public let minuten: Int
    /// Aandeel in het totaal, 0...1.
    public let aandeel: Double
}

public enum UrenRekenaar {
    public static let zonderPersoonID = "—"

    public static func filter(_ regels: [UrenRegelData], periode: DateInterval?) -> [UrenRegelData] {
        guard let periode else { return regels }
        // Einde exclusief, zodat aansluitende periodes (maanden) elkaar niet overlappen.
        return regels.filter { $0.datum >= periode.start && $0.datum < periode.end }
    }

    public static func totaal(_ regels: [UrenRegelData], periode: DateInterval? = nil) -> Int {
        filter(regels, periode: periode).reduce(0) { $0 + max($1.minuten, 0) }
    }

    /// Totaal per persoon, grootste eerst (bij gelijk: op naam).
    public static func perPersoon(_ regels: [UrenRegelData], periode: DateInterval? = nil) -> [UrenTotaal] {
        let gefilterd = filter(regels, periode: periode)
        let totaal = max(Self.totaal(gefilterd), 0)
        var minutenPer: [String: Int] = [:]
        var naamPer: [String: String] = [:]
        for regel in gefilterd {
            let sleutel = regel.persoonID ?? zonderPersoonID
            minutenPer[sleutel, default: 0] += max(regel.minuten, 0)
            naamPer[sleutel] = regel.persoonNaam
        }
        return minutenPer
            .map { sleutel, minuten in
                UrenTotaal(
                    id: sleutel,
                    naam: naamPer[sleutel] ?? "",
                    minuten: minuten,
                    aandeel: totaal > 0 ? Double(minuten) / Double(totaal) : 0
                )
            }
            .sorted { ($0.minuten, $1.naam) > ($1.minuten, $0.naam) }
    }

    /// Totaal per categorie, alleen categorieën met tijd, in vaste volgorde.
    public static func perCategorie(_ regels: [UrenRegelData], periode: DateInterval? = nil) -> [(categorie: UrenCategorie, minuten: Int)] {
        let gefilterd = filter(regels, periode: periode)
        return UrenCategorie.allCases.compactMap { categorie in
            let minuten = gefilterd.filter { $0.categorie == categorie }.reduce(0) { $0 + max($1.minuten, 0) }
            return minuten > 0 ? (categorie, minuten) : nil
        }
    }

    /// Uren en minuten, voor weergave.
    public static func urenEnMinuten(_ minuten: Int) -> (uren: Int, minuten: Int) {
        let m = max(minuten, 0)
        return (m / 60, m % 60)
    }
}

/// Periode voor het urenoverzicht.
public enum UrenPeriode: String, CaseIterable, Sendable, Identifiable {
    case dezeMaand
    case vorigeMaand
    case ditJaar
    case alles

    public var id: String { rawValue }

    /// Het tijdvak, einde exclusief. `nil` = geen filter.
    public func interval(nu: Date, calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .dezeMaand:
            return calendar.dateInterval(of: .month, for: nu)
        case .vorigeMaand:
            guard let vorige = calendar.date(byAdding: .month, value: -1, to: nu) else { return nil }
            return calendar.dateInterval(of: .month, for: vorige)
        case .ditJaar:
            return calendar.dateInterval(of: .year, for: nu)
        case .alles:
            return nil
        }
    }
}
