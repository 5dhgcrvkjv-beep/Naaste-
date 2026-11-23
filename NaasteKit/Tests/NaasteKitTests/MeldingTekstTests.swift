import Foundation
import Testing
@testable import NaasteKit

@Suite("Meldingtekst")
struct MeldingTekstTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return c
    }

    private func datum(_ dag: Int, _ uur: Int = 0, _ minuut: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 12, day: dag, hour: uur, minute: minuut))!
    }

    private func melding(_ soort: GeplandeMelding.Soort, gebeurtenis: Date) -> GeplandeMelding {
        GeplandeMelding(id: "x", herinneringID: UUID(), gebeurtenis: gebeurtenis, moment: gebeurtenis, soort: soort)
    }

    @Test func voorafZonderTijd() {
        let t = MeldingTekst.maak(onderwerp: "CAK betalen", naaste: "Riet", melding: melding(.vooraf(dagen: 3), gebeurtenis: datum(1)), heeftTijd: false, calendar: calendar)
        #expect(t.titel == "CAK betalen")
        #expect(t.tekst == "Over 3 dagen, di 1 december · Riet")
    }

    @Test func morgenMetTijd() {
        let t = MeldingTekst.maak(onderwerp: "Huisarts", naaste: nil, melding: melding(.vooraf(dagen: 1), gebeurtenis: datum(4, 10, 30)), heeftTijd: true, calendar: calendar)
        #expect(t.tekst.hasPrefix("Morgen, vr 4 december"))
        #expect(t.tekst.contains("10:30"))
        #expect(!t.tekst.contains("·"))
    }

    @Test func opDeDag() {
        let metTijd = MeldingTekst.maak(onderwerp: "Huisarts", naaste: "Riet", melding: melding(.opDeDag, gebeurtenis: datum(4, 10, 30)), heeftTijd: true, calendar: calendar)
        #expect(metTijd.tekst == "Vandaag om 10:30 · Riet")
        let zonder = MeldingTekst.maak(onderwerp: "Wmo", naaste: "  ", melding: melding(.opDeDag, gebeurtenis: datum(4)), heeftTijd: false, calendar: calendar)
        #expect(zonder.tekst == "Vandaag")
    }
}
