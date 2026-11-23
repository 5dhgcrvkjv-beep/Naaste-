import Foundation
import Testing
@testable import NaasteKit

@Suite("Herinneringen plannen")
struct ReminderPlannerTests {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return c
    }()

    func datum(_ j: Int, _ m: Int, _ d: Int, _ u: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: j, month: m, day: d, hour: u, minute: min))!
    }

    var planner: ReminderPlanner { ReminderPlanner(calendar: calendar) }

    @Test func eenmaligMetVooraf() {
        let id = UUID()
        let h = PlanbareHerinnering(id: id, datum: datum(2026, 12, 10), dagenVooraf: 7)
        let meldingen = planner.plan([h], nu: datum(2026, 11, 23, 12))
        #expect(meldingen.count == 2)
        #expect(meldingen[0].moment == datum(2026, 12, 3, 9))
        #expect(meldingen[0].soort == .vooraf(dagen: 7))
        #expect(meldingen[1].moment == datum(2026, 12, 10, 9))
        #expect(meldingen[1].soort == .opDeDag)
        #expect(meldingen.allSatisfy { $0.herinneringID == id })
    }

    @Test func voorafAlVoorbijAlleenOpDeDag() {
        let h = PlanbareHerinnering(id: UUID(), datum: datum(2026, 11, 25), dagenVooraf: 7)
        let meldingen = planner.plan([h], nu: datum(2026, 11, 23, 12))
        #expect(meldingen.map(\.soort) == [.opDeDag])
    }

    @Test func afspraakMetTijdEenUurVooraf() {
        let h = PlanbareHerinnering(id: UUID(), datum: datum(2026, 11, 26, 14, 30), heeftTijd: true)
        let meldingen = planner.plan([h], nu: datum(2026, 11, 23, 12))
        #expect(meldingen.map(\.moment) == [datum(2026, 11, 26, 13, 30)])
    }

    @Test func verledenEnAfgerondWordenOvergeslagen() {
        let oud = PlanbareHerinnering(id: UUID(), datum: datum(2026, 1, 1))
        let klaar = PlanbareHerinnering(id: UUID(), datum: datum(2027, 1, 1), afgerond: true)
        #expect(planner.plan([oud, klaar], nu: datum(2026, 11, 23)).isEmpty)
    }

    @Test func maandelijksVanafOorspronkelijkeDatum() {
        // Startdatum 31 januari: herhalingen blijven op de laatste dag rond de 31e, niet blijvend de 28e.
        let h = PlanbareHerinnering(id: UUID(), datum: datum(2026, 1, 31), herhaling: .maandelijks)
        let meldingen = planner.plan([h], nu: datum(2026, 2, 1))
        #expect(meldingen.map(\.gebeurtenis) == [datum(2026, 2, 28), datum(2026, 3, 31), datum(2026, 4, 30)])
    }

    @Test func jaarlijksePlanning() {
        let h = PlanbareHerinnering(id: UUID(), datum: datum(2024, 3, 1), herhaling: .jaarlijks, dagenVooraf: 30)
        let meldingen = planner.plan([h], nu: datum(2026, 11, 23))
        #expect(meldingen.first?.gebeurtenis == datum(2027, 3, 1))
        #expect(meldingen.first?.moment == datum(2027, 1, 30, 9))
        #expect(meldingen.count == 6) // 3 herhalingen × (vooraf + op de dag)
    }

    @Test func opDeDagZelfNogNietVoorbij() {
        // Herinnering voor vandaag zonder tijd: na 09:00 is de melding van vandaag voorbij, maar de gebeurtenis niet.
        let h = PlanbareHerinnering(id: UUID(), datum: datum(2026, 11, 23), herhaling: .wekelijks)
        let volgende = planner.volgendeGebeurtenis(van: h, nu: datum(2026, 11, 23, 15))
        #expect(volgende == datum(2026, 11, 23))
        let meldingen = planner.plan([h], nu: datum(2026, 11, 23, 15))
        #expect(meldingen.first?.gebeurtenis == datum(2026, 11, 30))
    }

    @Test func maximaalAantal() {
        let veel = (0..<40).map { i in
            PlanbareHerinnering(id: UUID(), datum: datum(2027, 1, 1 + (i % 28)), dagenVooraf: 3)
        }
        let meldingen = planner.plan(veel, nu: datum(2026, 11, 23))
        #expect(meldingen.count == 50)
        #expect(meldingen == meldingen.sorted { $0.moment < $1.moment || ($0.moment == $1.moment && $0.id < $1.id) })
    }

    @Test func idsZijnStabiel() {
        let h = PlanbareHerinnering(id: UUID(), datum: datum(2026, 12, 10), dagenVooraf: 2)
        #expect(planner.plan([h], nu: datum(2026, 11, 1)).map(\.id) == planner.plan([h], nu: datum(2026, 11, 2)).map(\.id))
        #expect(Set(planner.plan([h], nu: datum(2026, 11, 1)).map(\.id)).count == 2)
    }
}
