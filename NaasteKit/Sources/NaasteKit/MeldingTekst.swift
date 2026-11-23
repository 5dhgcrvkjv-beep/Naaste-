import Foundation

/// De tekst van een lokale melding. Kort en zonder medische details,
/// want meldingen zijn zichtbaar op het vergrendelscherm.
public struct MeldingTekst: Equatable, Sendable {
    public let titel: String
    public let tekst: String

    public init(titel: String, tekst: String) {
        self.titel = titel
        self.tekst = tekst
    }

    /// - Parameters:
    ///   - onderwerp: titel van de herinnering of zaak, bijv. "Eigen bijdrage CAK betalen".
    ///   - naaste: naam van de naaste, zodat duidelijk is om wie het gaat.
    public static func maak(
        onderwerp: String,
        naaste: String?,
        melding: GeplandeMelding,
        heeftTijd: Bool,
        calendar: Calendar = .current,
        locale: Locale = Locale(identifier: "nl_NL")
    ) -> MeldingTekst {
        let wanneer: String
        switch melding.soort {
        case let .vooraf(dagen):
            let datum = datumTekst(melding.gebeurtenis, heeftTijd: heeftTijd, calendar: calendar, locale: locale)
            wanneer = dagen == 1 ? "Morgen, \(datum)" : "Over \(dagen) dagen, \(datum)"
        case .opDeDag:
            wanneer = heeftTijd
                ? "Vandaag om \(tijdTekst(melding.gebeurtenis, calendar: calendar, locale: locale))"
                : "Vandaag"
        }
        let naam = naaste?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let tekst = naam.isEmpty ? wanneer : "\(wanneer) · \(naam)"
        return MeldingTekst(titel: onderwerp, tekst: tekst)
    }

    private static func datumTekst(_ datum: Date, heeftTijd: Bool, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(heeftTijd ? "EEEdMMMMHHmm" : "EEEdMMMM")
        return formatter.string(from: datum)
    }

    private static func tijdTekst(_ datum: Date, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("HHmm")
        return formatter.string(from: datum)
    }
}
