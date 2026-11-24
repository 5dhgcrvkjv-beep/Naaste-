import CoreData
import NaasteKit
import SwiftUI
import UIKit

/// Alle herinneringen van een naaste: herindicaties, betalingen, afspraken, verlengingen.
struct HerinneringenView: View {
    @ObservedObject var naaste: Naaste
    @Environment(AppModel.self) private var app
    @FetchRequest private var herinneringen: FetchedResults<Herinnering>

    @State private var nieuw = false
    @State private var agenda: AgendaItem?
    @State private var bewerken: Herinnering?
    @State private var toonAfgerond = false

    init(naaste: Naaste) {
        self.naaste = naaste
        let request = Herinnering.fetchRequest()
        request.predicate = NSPredicate(format: "naaste == %@", naaste)
        request.sortDescriptors = [NSSortDescriptor(key: "datum", ascending: true)]
        _herinneringen = FetchRequest(fetchRequest: request)
    }

    var body: some View {
        let open = herinneringen.filter { !$0.afgerond }
            .sorted { ($0.volgendeDatum() ?? .distantFuture) < ($1.volgendeDatum() ?? .distantFuture) }
        let afgerond = herinneringen.filter(\.afgerond)

        List {
            MeldingenStatus(isVoorbeeld: naaste.isVoorbeeld)

            if !open.isEmpty {
                Section("Komend") {
                    ForEach(open) { herinnering in
                        Button {
                            bewerken = herinnering
                        } label: {
                            HerinneringRij(herinnering: herinnering)
                        }
                        .tint(.primary)
                        .swipeActions(edge: .leading) {
                            Button {
                                herinnering.afgerond = true
                                herinnering.gewijzigd = .now
                                app.bewaar()
                            } label: {
                                Label(herinnering.herhalingWaarde == .geen ? "Klaar" : "Stop", systemImage: "checkmark")
                            }
                            .tint(.accentColor)
                        }
                        .contextMenu {
                            Button {
                                agenda = AgendaItem(herinnering: herinnering)
                            } label: {
                                Label("Zet in agenda", systemImage: "calendar.badge.plus")
                            }
                        }
                    }
                }
            }

            if !afgerond.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $toonAfgerond) {
                        ForEach(afgerond) { herinnering in
                            Button {
                                bewerken = herinnering
                            } label: {
                                HerinneringRij(herinnering: herinnering)
                            }
                            .tint(.secondary)
                        }
                    } label: {
                        Text("Afgerond (\(afgerond.count))")
                    }
                }
            }
        }
        .navigationTitle("Herinneringen")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    nieuw = true
                } label: {
                    Label("Nieuwe herinnering", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $nieuw) {
            HerinneringBewerkenView(naaste: naaste, herinnering: nil, zaak: nil)
        }
        .sheet(item: $bewerken) { herinnering in
            HerinneringBewerkenView(naaste: naaste, herinnering: herinnering, zaak: herinnering.zaak)
        }
        .agendaScherm($agenda)
        .overlay {
            if herinneringen.isEmpty {
                ContentUnavailableView {
                    Label("Geen herinneringen", systemImage: "bell")
                } description: {
                    Text("Bijvoorbeeld de herindicatie van de Wmo, de maandelijkse eigen bijdrage van het CAK of een afspraak bij de huisarts.")
                } actions: {
                    Button {
                        nieuw = true
                    } label: {
                        Text("Herinnering toevoegen")
                            .frame(minWidth: 220, minHeight: 34)
                    }
                    .hoofdknop()
                }
            }
        }
        .task { await app.meldingen.werkToestemmingBij() }
    }
}

/// Uitleg als meldingen uit staan, met een knop naar de iOS-instellingen.
private struct MeldingenStatus: View {
    let isVoorbeeld: Bool
    @Environment(AppModel.self) private var app

    var body: some View {
        if isVoorbeeld {
            Section {
                Label("Bij de voorbeeld-naaste komen geen meldingen.", systemImage: "bell.slash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else if app.meldingen.toestemming == .geweigerd {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Meldingen staan uit", systemImage: "bell.slash")
                        .font(.subheadline.weight(.semibold))
                    Text("Je ziet herinneringen hier wel, maar je iPhone waarschuwt niet. Zet meldingen aan voor Naaste in Instellingen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        Link("Open Instellingen", destination: url)
                            .font(.subheadline.weight(.medium))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

/// Rij met soort, titel, eerstvolgende datum en herhaling.
struct HerinneringRij: View {
    @ObservedObject var herinnering: Herinnering

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: herinnering.soortWaarde.symbool)
                .foregroundStyle(herinnering.afgerond ? .secondary : Color.accentColor)
                .frame(width: 28)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(herinnering.weergaveTitel)
                    .strikethrough(herinnering.afgerond)
                Text(onderregel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var onderregel: String {
        guard let datum = herinnering.afgerond ? herinnering.datum : herinnering.volgendeDatum() else {
            return herinnering.soortWaarde.titel
        }
        var delen = [
            herinnering.heeftTijd
                ? datum.formatted(date: .abbreviated, time: .shortened)
                : datum.formatted(date: .abbreviated, time: .omitted)
        ]
        if !herinnering.afgerond { delen.append(datum.relatief) }
        if herinnering.herhalingWaarde != .geen { delen.append(herinnering.herhalingWaarde.titel.lowercased()) }
        return delen.joined(separator: " · ")
    }
}

/// Nieuwe herinnering of bestaande wijzigen.
struct HerinneringBewerkenView: View {
    @ObservedObject var naaste: Naaste
    let herinnering: Herinnering?
    /// Vooraf gekozen zaak (bij toevoegen vanuit een zaak).
    let zaak: Zaak?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @FetchRequest private var lopendeZaken: FetchedResults<Zaak>

    @State private var titel = ""
    @State private var soort: HerinneringSoort = .overig
    @State private var datum = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: .now))?.addingTimeInterval(10 * 3600) ?? .now
    @State private var heeftTijd = false
    @State private var herhaling: Herhaling = .geen
    @State private var dagenVooraf = 7
    @State private var gekoppeldeZaak: Zaak?
    @State private var notitie = ""
    @State private var afgerond = false
    @State private var bevestigVerwijderen = false
    @State private var agenda: AgendaItem?

    static let voorafKeuzes = [0, 1, 2, 3, 7, 14, 30, 60]

    init(naaste: Naaste, herinnering: Herinnering?, zaak: Zaak?) {
        self.naaste = naaste
        self.herinnering = herinnering
        self.zaak = zaak
        _lopendeZaken = FetchRequest(fetchRequest: Zaak.lopend(voor: naaste))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Soort", selection: $soort) {
                        ForEach(HerinneringSoort.allCases) { soort in
                            Label(soort.titel, systemImage: soort.symbool).tag(soort)
                        }
                    }
                    TextField(soort.voorbeeldTitel, text: $titel, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section {
                    DatePicker("Datum", selection: $datum, displayedComponents: heeftTijd ? [.date, .hourAndMinute] : [.date])
                    Toggle("Met tijdstip", isOn: $heeftTijd.animation())
                    Picker("Herhalen", selection: $herhaling) {
                        ForEach(Herhaling.allCases) { herhaling in
                            Text(herhaling.titel).tag(herhaling)
                        }
                    }
                }

                Section {
                    Picker("Vooraf waarschuwen", selection: $dagenVooraf) {
                        ForEach(Self.voorafKeuzes, id: \.self) { dagen in
                            Text(Self.voorafTekst(dagen)).tag(dagen)
                        }
                    }
                } footer: {
                    Text(heeftTijd
                         ? "Je krijgt ook een melding een uur van tevoren."
                         : "Je krijgt ook een melding op de dag zelf, om 9:00.")
                }

                Section {
                    Picker("Zaak", selection: $gekoppeldeZaak) {
                        Text("Geen").tag(Zaak?.none)
                        ForEach(zaakKeuzes) { zaak in
                            Text(zaak.weergaveTitel).tag(Zaak?.some(zaak))
                        }
                    }
                    TextField("Notitie", text: $notitie, axis: .vertical)
                        .lineLimit(1...5)
                }

                if let herinnering {
                    Section {
                        Button {
                            agenda = AgendaItem(herinnering: herinnering)
                        } label: {
                            Label("Zet in agenda", systemImage: "calendar.badge.plus")
                        }
                    } footer: {
                        Text("Bewaar eerst als je de datum net hebt gewijzigd.")
                    }
                    Section {
                        Toggle(herhaling == .geen ? "Afgerond" : "Gestopt", isOn: $afgerond)
                        Button("Herinnering verwijderen", role: .destructive) {
                            bevestigVerwijderen = true
                        }
                    }
                }
            }
            .navigationTitle(herinnering == nil ? "Nieuwe herinnering" : "Wijzig herinnering")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar", action: bewaar)
                }
            }
            .confirmationDialog("Herinnering verwijderen?", isPresented: $bevestigVerwijderen, titleVisibility: .visible) {
                Button("Verwijder", role: .destructive) {
                    if let herinnering {
                        app.context.delete(herinnering)
                        if app.bewaar() { dismiss() }
                    }
                }
            }
            .onAppear(perform: laad)
            .agendaScherm($agenda)
        }
        .interactiveDismissDisabled()
    }

    /// Lopende zaken, plus de huidige koppeling als die zaak al is afgerond.
    private var zaakKeuzes: [Zaak] {
        var keuzes = Array(lopendeZaken)
        if let gekoppeldeZaak, !keuzes.contains(gekoppeldeZaak) { keuzes.append(gekoppeldeZaak) }
        return keuzes
    }

    static func voorafTekst(_ dagen: Int) -> String {
        switch dagen {
        case 0: String(localized: "Alleen op de dag")
        case 1: String(localized: "1 dag van tevoren")
        case 7: String(localized: "1 week van tevoren")
        case 14: String(localized: "2 weken van tevoren")
        case 30: String(localized: "1 maand van tevoren")
        case 60: String(localized: "2 maanden van tevoren")
        default: String(localized: "\(dagen) dagen van tevoren")
        }
    }

    private func laad() {
        gekoppeldeZaak = zaak
        guard let herinnering else {
            if let zaak { soort = .vervolg; titel = zaak.weergaveTitel }
            return
        }
        titel = herinnering.titel ?? ""
        soort = herinnering.soortWaarde
        datum = herinnering.datum ?? datum
        heeftTijd = herinnering.heeftTijd
        herhaling = herinnering.herhalingWaarde
        let vooraf = Int(herinnering.dagenVooraf)
        dagenVooraf = Self.voorafKeuzes.contains(vooraf) ? vooraf : 7
        gekoppeldeZaak = herinnering.zaak
        notitie = herinnering.notitie ?? ""
        afgerond = herinnering.afgerond
    }

    private func bewaar() {
        let doel = herinnering ?? {
            let nieuw = app.context.maak(Herinnering.self, bij: naaste)
            nieuw.naaste = naaste
            return nieuw
        }()
        doel.titel = titel.nietLeeg
        doel.soortWaarde = soort
        doel.datum = heeftTijd ? datum : Calendar.current.startOfDay(for: datum)
        doel.heeftTijd = heeftTijd
        doel.herhalingWaarde = herhaling
        doel.dagenVooraf = Int16(dagenVooraf)
        doel.zaak = gekoppeldeZaak
        doel.notitie = notitie.nietLeeg
        doel.afgerond = afgerond
        doel.gewijzigd = .now
        guard app.bewaar() else { return }
        if !afgerond && !naaste.isVoorbeeld { app.vraagMeldingenToestemmingEnPlan() }
        dismiss()
    }
}

extension HerinneringSoort {
    var voorbeeldTitel: String {
        switch self {
        case .herindicatie: String(localized: "Bijv. herindicatie huishoudelijke hulp")
        case .verlenging: String(localized: "Bijv. gehandicaptenparkeerkaart verlengen")
        case .betaling: String(localized: "Bijv. eigen bijdrage CAK betalen")
        case .afspraak: String(localized: "Bijv. afspraak huisarts")
        case .vervolg: String(localized: "Bijv. gemeente nabellen")
        case .overig: String(localized: "Waar moet je aan denken?")
        }
    }
}
