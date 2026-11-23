import Foundation

/// Invoer voor de planner: een herinnering zoals hij in de database staat.
public struct PlanbareHerinnering: Equatable, Sendable {
    public let id: UUID
    public let datum: Date
    /// `true` als de herinnering een tijdstip heeft (bijv. een afspraak om 14:00).
    public let heeftTijd: Bool
    public let herhaling: Herhaling
    public let dagenVooraf: Int
    public let afgerond: Bool

    public init(id: UUID, datum: Date, heeftTijd: Bool = false, herhaling: Herhaling = .geen, dagenVooraf: Int = 0, afgerond: Bool = false) {
        self.id = id
        self.datum = datum
        self.heeftTijd = heeftTijd
        self.herhaling = herhaling
        self.dagenVooraf = dagenVooraf
        self.afgerond = afgerond
    }
}

/// Uitvoer: één lokale notificatie die gepland moet worden.
public struct GeplandeMelding: Equatable, Sendable, Identifiable {
    public enum Soort: Equatable, Sendable {
        /// `dagen` dagen voor de datum, om `meldUur`.
        case vooraf(dagen: Int)
        /// Op de dag zelf (of een uur ervoor bij een tijdstip).
        case opDeDag
    }

    /// Deterministisch, zodat opnieuw plannen dezelfde ID's geeft.
    public let id: String
    public let herinneringID: UUID
    /// De datum van de (herhaalde) gebeurtenis zelf.
    public let gebeurtenis: Date
    /// Wanneer de melding afgaat.
    public let moment: Date
    public let soort: Soort
}

/// Rekent uit welke lokale notificaties gepland moeten worden.
///
/// iOS staat maximaal 64 wachtende lokale notificaties per app toe; we plannen
/// er standaard 50 (de eerstvolgende) en vullen aan bij elke wijziging of start.
public struct ReminderPlanner: Sendable {
    public var calendar: Calendar
    /// Uur van de dag voor meldingen zonder tijdstip.
    public var meldUur: Int
    public var maxMeldingen: Int
    /// Hoeveel toekomstige herhalingen per herinnering maximaal worden gepland.
    public var herhalingenPerHerinnering: Int

    public init(calendar: Calendar = .current, meldUur: Int = 9, maxMeldingen: Int = 50, herhalingenPerHerinnering: Int = 3) {
        self.calendar = calendar
        self.meldUur = meldUur
        self.maxMeldingen = maxMeldingen
        self.herhalingenPerHerinnering = herhalingenPerHerinnering
    }

    public func plan(_ herinneringen: [PlanbareHerinnering], nu: Date) -> [GeplandeMelding] {
        var meldingen: [GeplandeMelding] = []
        for herinnering in herinneringen where !herinnering.afgerond {
            for gebeurtenis in toekomstigeGebeurtenissen(van: herinnering, nu: nu) {
                meldingen += meldingenVoor(herinnering, gebeurtenis: gebeurtenis, nu: nu)
            }
        }
        return Array(meldingen.sorted { ($0.moment, $0.id) < ($1.moment, $1.id) }.prefix(maxMeldingen))
    }

    /// Volgende datum van een (herhalende) herinnering na `nu`, voor weergave ("volgende keer").
    public func volgendeGebeurtenis(van herinnering: PlanbareHerinnering, nu: Date) -> Date? {
        guard let stap = herinnering.herhaling.stap else { return herinnering.datum }
        var k = 0
        while k < 2000 {
            guard let datum = calendar.date(byAdding: stap.component, value: stap.aantal * k, to: herinnering.datum) else { return nil }
            if eindeVanGebeurtenis(datum, heeftTijd: herinnering.heeftTijd) > nu { return datum }
            k += 1
        }
        return nil
    }

    // MARK: - Intern

    private func toekomstigeGebeurtenissen(van herinnering: PlanbareHerinnering, nu: Date) -> [Date] {
        guard let stap = herinnering.herhaling.stap else {
            return [herinnering.datum]
        }
        var resultaat: [Date] = []
        var k = 0
        // Altijd vanaf de oorspronkelijke datum rekenen (k × stap), zodat bijv. de 31e
        // in februari niet blijvend naar de 28e verschuift.
        while resultaat.count < herhalingenPerHerinnering && k < 2000 {
            if let datum = calendar.date(byAdding: stap.component, value: stap.aantal * k, to: herinnering.datum),
               eindeVanGebeurtenis(datum, heeftTijd: herinnering.heeftTijd) > nu {
                resultaat.append(datum)
            }
            k += 1
        }
        return resultaat
    }

    private func eindeVanGebeurtenis(_ datum: Date, heeftTijd: Bool) -> Date {
        if heeftTijd { return datum }
        let begin = calendar.startOfDay(for: datum)
        return calendar.date(byAdding: .day, value: 1, to: begin) ?? datum
    }

    private func meldingenVoor(_ herinnering: PlanbareHerinnering, gebeurtenis: Date, nu: Date) -> [GeplandeMelding] {
        var resultaat: [GeplandeMelding] = []
        let sleutel = datumSleutel(gebeurtenis)

        if herinnering.dagenVooraf > 0,
           let dag = calendar.date(byAdding: .day, value: -herinnering.dagenVooraf, to: gebeurtenis),
           let moment = opMeldUur(dag), moment > nu {
            resultaat.append(GeplandeMelding(
                id: "\(herinnering.id.uuidString)-\(sleutel)-vooraf",
                herinneringID: herinnering.id,
                gebeurtenis: gebeurtenis,
                moment: moment,
                soort: .vooraf(dagen: herinnering.dagenVooraf)
            ))
        }

        let opDeDag: Date?
        if herinnering.heeftTijd {
            opDeDag = calendar.date(byAdding: .hour, value: -1, to: gebeurtenis)
        } else {
            opDeDag = opMeldUur(gebeurtenis)
        }
        if let moment = opDeDag, moment > nu {
            resultaat.append(GeplandeMelding(
                id: "\(herinnering.id.uuidString)-\(sleutel)-dag",
                herinneringID: herinnering.id,
                gebeurtenis: gebeurtenis,
                moment: moment,
                soort: .opDeDag
            ))
        }
        return resultaat
    }

    private func opMeldUur(_ datum: Date) -> Date? {
        calendar.date(bySettingHour: meldUur, minute: 0, second: 0, of: datum)
    }

    private func datumSleutel(_ datum: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: datum)
        let j = c.year ?? 0, m = c.month ?? 0, d = c.day ?? 0
        return "\(j)" + (m < 10 ? "0\(m)" : "\(m)") + (d < 10 ? "0\(d)" : "\(d)")
    }
}
