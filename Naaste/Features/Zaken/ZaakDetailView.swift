import CoreData
import NaasteKit
import SwiftUI

/// Eén zaak: status met snelle vervolgstappen, wie het oppakt, documenten,
/// herinneringen en de tijdlijn van wat er gebeurd is.
struct ZaakDetailView: View {
    @ObservedObject var zaak: Zaak
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var bewerken = false
    @State private var nieuweGebeurtenis = false
    @State private var documentKiezen = false
    @State private var nieuweHerinnering = false
    @State private var herinneringBewerken: Herinnering?
    @State private var statusMetNotitie: ZaakStatus?

    var body: some View {
        if zaak.isDeleted || zaak.managedObjectContext == nil {
            ContentUnavailableView("Zaak verwijderd", systemImage: "folder")
        } else {
            inhoud
        }
    }

    private var inhoud: some View {
        List {
            kop
            volgendeStap
            if let notities = zaak.notities?.nietLeeg {
                Section("Notities") {
                    Text(notities)
                        .textSelection(.enabled)
                }
            }
            documenten
            herinneringen
            tijdlijn
        }
        .navigationTitle(zaak.weergaveTitel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Wijzig") { bewerken = true }
            }
        }
        .sheet(isPresented: $bewerken) {
            if let naaste = zaak.naaste {
                ZaakBewerkenView(naaste: naaste, zaak: zaak, naVerwijderen: { dismiss() })
            }
        }
        .sheet(isPresented: $nieuweGebeurtenis) {
            GebeurtenisToevoegenView(zaak: zaak)
        }
        .sheet(item: $statusMetNotitie) { status in
            StatusWijzigenView(zaak: zaak, nieuweStatus: status)
        }
        .sheet(isPresented: $documentKiezen) {
            DocumentKiezer(zaak: zaak)
        }
        .sheet(isPresented: $nieuweHerinnering) {
            if let naaste = zaak.naaste {
                HerinneringBewerkenView(naaste: naaste, herinnering: nil, zaak: zaak)
            }
        }
        .sheet(item: $herinneringBewerken) { herinnering in
            if let naaste = zaak.naaste {
                HerinneringBewerkenView(naaste: naaste, herinnering: herinnering, zaak: zaak)
            }
        }
    }

    // MARK: Secties

    private var kop: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label(zaak.categorieWaarde.titel, systemImage: zaak.categorieWaarde.symbool)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(zaak.weergaveTitel)
                    .font(.title3.weight(.semibold))
                Etiket(tekst: zaak.statusWaarde.titel, symbool: zaak.statusWaarde.symbool, kleur: zaak.statusWaarde.kleur)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)

            OppakkerKiezer(zaak: zaak)

            if let aangevraagd = zaak.datumAangevraagd {
                LabeledContent("Aangevraagd", value: aangevraagd.formatted(date: .long, time: .omitted))
            }
            if let vervolg = zaak.vervolgdatum, zaak.statusWaarde.isLopend {
                LabeledContent {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(vervolg.formatted(date: .long, time: .omitted))
                        Text(zaak.vervolgHerinneren ? String(localized: "met melding") : vervolg.relatief)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Text("Vervolg")
                }
            }
        }
    }

    @ViewBuilder private var volgendeStap: some View {
        let stappen = zaak.statusWaarde.vervolgStatussen
        if !stappen.isEmpty {
            Section {
                ForEach(stappen) { status in
                    Button {
                        statusMetNotitie = status
                    } label: {
                        Label(status.knopTitel, systemImage: status.symbool)
                    }
                }
            } header: {
                Text("Volgende stap")
            } footer: {
                Text("De wijziging komt in de tijdlijn, met datum en wie het deed.")
            }
        }
    }

    private var documenten: some View {
        Section("Documenten") {
            ForEach(zaak.documentenLijst.sorted { ($0.documentDatum ?? .distantPast) > ($1.documentDatum ?? .distantPast) }) { document in
                NavigationLink {
                    DocumentDetailView(document: document)
                } label: {
                    DocumentRij(document: document)
                }
                .swipeActions {
                    Button("Ontkoppel", role: .destructive) {
                        app.ontkoppel(document, van: zaak)
                        app.bewaar()
                    }
                }
            }
            Button {
                documentKiezen = true
            } label: {
                Label("Document koppelen", systemImage: "paperclip")
            }
        }
    }

    private var herinneringen: some View {
        Section("Herinneringen") {
            ForEach(zaak.herinneringenLijst.filter { !$0.afgerond }.sorted { ($0.volgendeDatum() ?? .distantFuture) < ($1.volgendeDatum() ?? .distantFuture) }) { herinnering in
                Button {
                    herinneringBewerken = herinnering
                } label: {
                    HerinneringRij(herinnering: herinnering)
                }
                .tint(.primary)
            }
            Button {
                nieuweHerinnering = true
            } label: {
                Label("Herinnering toevoegen", systemImage: "bell.badge")
            }
        }
    }

    private var tijdlijn: some View {
        Section {
            Button {
                nieuweGebeurtenis = true
            } label: {
                Label("Notitie of contactmoment toevoegen", systemImage: "plus.bubble")
            }
            ForEach(zaak.tijdlijn) { gebeurtenis in
                GebeurtenisRij(gebeurtenis: gebeurtenis)
            }
            .onDelete { indexen in
                let lijst = zaak.tijdlijn
                indexen.map { lijst[$0] }.forEach(app.context.delete)
                app.bewaar()
            }
        } header: {
            Text("Tijdlijn")
        }
    }
}

extension ZaakStatus {
    /// Tekst op de knop voor de volgende stap: "Markeer als aangevraagd".
    var knopTitel: String {
        switch self {
        case .voorbereiden: String(localized: "Terug naar voorbereiden")
        case .aangevraagd: String(localized: "Aanvraag is verstuurd")
        case .inBehandeling: String(localized: "Is in behandeling")
        case .toegekend: String(localized: "Is toegekend")
        case .afgewezen: String(localized: "Is afgewezen")
        case .bezwaar: String(localized: "Bezwaar ingediend")
        case .afgerond: String(localized: "Zaak afronden")
        }
    }
}

/// Menu om te kiezen welk familielid de zaak oppakt.
private struct OppakkerKiezer: View {
    @ObservedObject var zaak: Zaak
    @Environment(AppModel.self) private var app

    var body: some View {
        let leden = (zaak.naaste?.familieledenLijst ?? []).sorted { $0.weergaveNaam < $1.weergaveNaam }
        Menu {
            Button("Niemand") { zet(nil) }
            ForEach(leden) { lid in
                Button(lid.weergaveNaam) { zet(lid) }
            }
        } label: {
            LabeledContent("Pakt het op") {
                HStack(spacing: 6) {
                    if let lid = zaak.opgepaktDoor {
                        Avatar(lid: lid, grootte: 24)
                        Text(lid.weergaveNaam)
                    } else {
                        Text("Niemand")
                    }
                }
                .foregroundStyle(Color.accentColor)
            }
        }
        .disabled(leden.isEmpty)
    }

    private func zet(_ lid: Familielid?) {
        zaak.opgepaktDoor = lid
        zaak.gewijzigd = .now
        app.bewaar()
    }
}

struct GebeurtenisRij: View {
    @ObservedObject var gebeurtenis: ZaakGebeurtenis

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbool)
                .foregroundStyle(kleur)
                .frame(width: 24)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(kopregel)
                    .font(.subheadline.weight(.medium))
                if let tekst = gebeurtenis.tekst?.nietLeeg {
                    Text(tekst)
                        .font(.subheadline)
                }
                Text(onderregel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var symbool: String {
        gebeurtenis.nieuweStatusWaarde?.symbool ?? gebeurtenis.soortWaarde.symbool
    }

    private var kleur: Color {
        gebeurtenis.nieuweStatusWaarde?.kleur ?? .secondary
    }

    private var kopregel: String {
        if let status = gebeurtenis.nieuweStatusWaarde {
            return String(localized: "Status: \(status.titel)")
        }
        return gebeurtenis.soortWaarde.titel
    }

    private var onderregel: String {
        let datum = gebeurtenis.datum?.formatted(date: .abbreviated, time: .omitted) ?? ""
        if let auteur = gebeurtenis.auteur?.nietLeeg {
            return "\(datum) · \(auteur)"
        }
        return datum
    }
}

/// Status wijzigen met een optionele notitie en datum (bijv. "beschikking ontvangen op 3 maart").
private struct StatusWijzigenView: View {
    @ObservedObject var zaak: Zaak
    let nieuweStatus: ZaakStatus
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var notitie = ""
    @State private var datum = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(nieuweStatus.titel, systemImage: nieuweStatus.symbool)
                        .foregroundStyle(nieuweStatus.kleur)
                    DatePicker("Datum", selection: $datum, in: ...Date.now, displayedComponents: .date)
                }
                Section("Notitie (niet verplicht)") {
                    TextField(voorbeeld, text: $notitie, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(nieuweStatus.knopTitel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") {
                        zaak.zetStatus(nieuweStatus, op: datum, door: app.auteur(bij: zaak.naaste), notitie: notitie)
                        if app.bewaar() { dismiss() }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var voorbeeld: String {
        switch nieuweStatus {
        case .aangevraagd: String(localized: "Bijv. formulier ingestuurd via het Wmo-loket")
        case .toegekend: String(localized: "Bijv. beschikking ontvangen, 4 uur per week")
        case .afgewezen: String(localized: "Bijv. reden van afwijzing, termijn voor bezwaar")
        case .bezwaar: String(localized: "Bijv. bezwaarschrift verstuurd, ontvangstbevestiging gekregen")
        default: String(localized: "Wat is er gebeurd?")
        }
    }
}

/// Notitie of contactmoment ("gemeente gebeld, beslissing volgt") toevoegen aan de tijdlijn.
private struct GebeurtenisToevoegenView: View {
    @ObservedObject var zaak: Zaak
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var soort: GebeurtenisSoort = .contact
    @State private var tekst = ""
    @State private var datum = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Soort", selection: $soort) {
                        Text("Contact").tag(GebeurtenisSoort.contact)
                        Text("Notitie").tag(GebeurtenisSoort.notitie)
                    }
                    .pickerStyle(.segmented)
                    TextField(
                        soort == .contact
                            ? String(localized: "Bijv. gemeente gebeld, aanvraag ligt bij de consulent")
                            : String(localized: "Wat wil je onthouden?"),
                        text: $tekst,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    DatePicker("Datum", selection: $datum, in: ...Date.now, displayedComponents: .date)
                }
            }
            .navigationTitle("Toevoegen aan tijdlijn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") {
                        app.voegGebeurtenisToe(aan: zaak, soort: soort, tekst: tekst, datum: datum)
                        if app.bewaar() { dismiss() }
                    }
                    .disabled(tekst.nietLeeg == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Kies een bestaand document van deze naaste om aan de zaak te koppelen.
private struct DocumentKiezer: View {
    @ObservedObject var zaak: Zaak
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @FetchRequest private var documenten: FetchedResults<Document>
    @State private var zoekterm = ""

    init(zaak: Zaak) {
        self.zaak = zaak
        let request = zaak.naaste.map(Document.alle(voor:)) ?? {
            let r = Document.fetchRequest()
            r.predicate = NSPredicate(value: false)
            r.sortDescriptors = []
            return r
        }()
        _documenten = FetchRequest(fetchRequest: request)
    }

    var body: some View {
        NavigationStack {
            let gekoppeld = Set(zaak.documentenLijst.map(\.objectID))
            let keuzes = documenten.filter {
                !gekoppeld.contains($0.objectID)
                    && Zoeken.past(zoekterm, in: [$0.titel, $0.ocrTekst, $0.categorieWaarde.titel])
            }
            List(keuzes) { document in
                Button {
                    app.koppel(document, aan: zaak)
                    if app.bewaar() { dismiss() }
                } label: {
                    DocumentRij(document: document)
                }
                .tint(.primary)
            }
            .overlay {
                if keuzes.isEmpty {
                    ContentUnavailableView(
                        "Geen documenten",
                        systemImage: "doc.text",
                        description: Text("Voeg eerst documenten toe in het tabblad Documenten.")
                    )
                }
            }
            .searchable(text: $zoekterm, prompt: "Zoek in documenten")
            .navigationTitle("Document koppelen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
            }
        }
    }
}
