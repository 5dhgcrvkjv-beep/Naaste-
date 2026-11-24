import EventKit
import EventKitUI
import NaasteKit
import SwiftUI

/// Een afspraak of deadline die je in de Agenda-app wilt zetten.
///
/// Naaste toont het standaardscherm van iOS. Daarvoor is geen toegang tot je agenda
/// nodig: jij kiest zelf de agenda en tikt op "Voeg toe". Naaste leest je agenda niet.
struct AgendaItem: Identifiable {
    let id = UUID()
    var titel: String
    var start: Date
    var heleDag: Bool
    var notitie: String?
    var herhaling: Herhaling = .geen

    init(titel: String, start: Date, heleDag: Bool, notitie: String? = nil, herhaling: Herhaling = .geen) {
        self.titel = titel
        self.start = start
        self.heleDag = heleDag
        self.notitie = notitie
        self.herhaling = herhaling
    }

    /// De herhaling als agendaregel, of `nil` als het eenmalig is.
    var herhaalregel: EKRecurrenceRule? {
        let (frequentie, interval): (EKRecurrenceFrequency, Int)
        switch herhaling {
        case .geen: return nil
        case .wekelijks: (frequentie, interval) = (.weekly, 1)
        case .maandelijks: (frequentie, interval) = (.monthly, 1)
        case .perKwartaal: (frequentie, interval) = (.monthly, 3)
        case .jaarlijks: (frequentie, interval) = (.yearly, 1)
        }
        return EKRecurrenceRule(recurrenceWith: frequentie, interval: interval, end: nil)
    }

    init?(herinnering: Herinnering) {
        guard let datum = herinnering.volgendeDatum() ?? herinnering.datum else { return nil }
        let naam = herinnering.naaste.map { " (\($0.weergaveNaam))" } ?? ""
        self.init(
            titel: herinnering.weergaveTitel + naam,
            start: datum,
            heleDag: !herinnering.heeftTijd,
            notitie: herinnering.notitie?.nietLeeg,
            herhaling: herinnering.herhalingWaarde
        )
    }

    init?(vervolgVan zaak: Zaak) {
        guard let datum = zaak.vervolgdatum else { return nil }
        let naam = zaak.naaste.map { " (\($0.weergaveNaam))" } ?? ""
        self.init(
            titel: String(localized: "Vervolg: \(zaak.weergaveTitel)") + naam,
            start: datum,
            heleDag: true,
            notitie: zaak.notities?.nietLeeg
        )
    }

    init?(deadlineVan taak: Taak) {
        guard let datum = taak.deadline else { return nil }
        let naam = taak.naaste.map { " (\($0.weergaveNaam))" } ?? ""
        self.init(titel: taak.weergaveTitel + naam, start: datum, heleDag: true, notitie: taak.notitie?.nietLeeg)
    }
}

extension View {
    /// Toont het iOS-scherm "Nieuwe activiteit", ingevuld met `item`.
    func agendaScherm(_ item: Binding<AgendaItem?>) -> some View {
        sheet(item: item) { agendaItem in
            AgendaScherm(item: agendaItem) { item.wrappedValue = nil }
                .ignoresSafeArea()
        }
    }
}

private struct AgendaScherm: UIViewControllerRepresentable {
    let item: AgendaItem
    let klaar: () -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let opslag = EKEventStore()
        let activiteit = EKEvent(eventStore: opslag)
        activiteit.title = item.titel
        activiteit.notes = item.notitie
        activiteit.isAllDay = item.heleDag
        if item.heleDag {
            let dag = Calendar.current.startOfDay(for: item.start)
            activiteit.startDate = dag
            activiteit.endDate = dag
        } else {
            activiteit.startDate = item.start
            activiteit.endDate = item.start.addingTimeInterval(3600)
        }
        if let regel = item.herhaalregel { activiteit.addRecurrenceRule(regel) }
        let scherm = EKEventEditViewController()
        scherm.eventStore = opslag
        scherm.event = activiteit
        scherm.editViewDelegate = context.coordinator
        return scherm
    }

    func updateUIViewController(_ scherm: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(klaar: klaar) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let klaar: () -> Void
        init(klaar: @escaping () -> Void) { self.klaar = klaar }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            klaar()
        }
    }
}
