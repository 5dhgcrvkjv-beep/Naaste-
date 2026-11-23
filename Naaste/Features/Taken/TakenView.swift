import CoreData
import NaasteKit
import SwiftUI

/// Tabblad Taken: wie doet wat (gratis) en het urenlogboek (Plus).
struct TakenView: View {
    enum Weergave: String, Hashable {
        case taken, uren
    }

    @State private var weergave: Weergave = Self.startWeergave

    /// Alleen in DEBUG: `-takenWeergave uren` opent direct het urenlogboek (voor screenshots).
    private static var startWeergave: Weergave {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-takenWeergave"), i + 1 < args.count, let w = Weergave(rawValue: args[i + 1]) {
            return w
        }
        #endif
        return .taken
    }

    var body: some View {
        NavigationStack {
            MetGeselecteerdeNaaste { naaste in
                Group {
                    switch weergave {
                    case .taken: TakenLijst(naaste: naaste)
                    case .uren: UrenView(naaste: naaste)
                    }
                }
                .id(naaste.objectID)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("Weergave", selection: $weergave) {
                            Text("Taken").tag(Weergave.taken)
                            Text("Uren").tag(Weergave.uren)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 220)
                    }
                }
            }
            .navigationTitle(weergave == .taken ? "Taken" : "Uren")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct TakenLijst: View {
    enum Filter: String, CaseIterable, Identifiable {
        case iedereen, mij, nietToegewezen
        var id: String { rawValue }

        var titel: String {
            switch self {
            case .iedereen: String(localized: "Iedereen")
            case .mij: String(localized: "Van mij")
            case .nietToegewezen: String(localized: "Niet toegewezen")
            }
        }
    }

    @ObservedObject var naaste: Naaste
    @Environment(AppModel.self) private var app
    @FetchRequest private var taken: FetchedResults<Taak>

    @State private var nieuweTitel = ""
    @State private var filter: Filter = .iedereen
    @State private var bewerken: Taak?
    @State private var nieuwMetDetails = false
    @State private var toonAfgerond = false
    @FocusState private var invoerActief: Bool

    init(naaste: Naaste) {
        self.naaste = naaste
        _taken = FetchRequest(fetchRequest: Taak.alle(voor: naaste))
    }

    var body: some View {
        let ik = app.ik(bij: naaste)
        let gefilterd = taken.filter { taak in
            switch filter {
            case .iedereen: true
            case .mij: ik != nil && taak.toegewezenAan == ik
            case .nietToegewezen: taak.toegewezenAan == nil
            }
        }
        let open = gefilterd.filter { !$0.afgerond }.sorted(by: Taak.sorteer)
        let afgerond = gefilterd.filter(\.afgerond)
            .sorted { ($0.afgerondOp ?? .distantPast) > ($1.afgerondOp ?? .distantPast) }

        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                    TextField("Nieuwe taak", text: $nieuweTitel)
                        .focused($invoerActief)
                        .submitLabel(.done)
                        .onSubmit(voegSnelToe)
                }
            } footer: {
                if filter == .mij && ik == nil {
                    Text("Kies eerst wie jij bent in Instellingen → Familieleden.")
                }
            }

            Section {
                if open.isEmpty {
                    LegeRij(tekst: filter == .iedereen ? "Geen open taken. Goed bezig!" : "Geen open taken in deze selectie.")
                }
                ForEach(open) { taak in
                    TaakRij(taak: taak) { bewerken = taak }
                }
                .onDelete { verwijder(open, $0) }
            } header: {
                Text("Open")
            }

            if !afgerond.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $toonAfgerond) {
                        ForEach(afgerond) { taak in
                            TaakRij(taak: taak) { bewerken = taak }
                        }
                        .onDelete { verwijder(afgerond, $0) }
                    } label: {
                        Text("Gedaan (\(afgerond.count))")
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Toon", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.titel).tag($0) }
                    }
                } label: {
                    Label("Filter", systemImage: filter == .iedereen ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    nieuwMetDetails = true
                } label: {
                    Label("Nieuwe taak", systemImage: "plus")
                }
            }
        }
        .sheet(item: $bewerken) { taak in
            TaakBewerkenView(naaste: naaste, taak: taak)
        }
        .sheet(isPresented: $nieuwMetDetails) {
            TaakBewerkenView(naaste: naaste, taak: nil)
        }
    }

    private func voegSnelToe() {
        guard let titel = nieuweTitel.nietLeeg else { return }
        let taak = app.context.maak(Taak.self, bij: naaste)
        taak.naaste = naaste
        taak.titel = titel
        if filter == .mij { taak.toegewezenAan = app.ik(bij: naaste) }
        if app.bewaar() {
            nieuweTitel = ""
            invoerActief = true // meteen de volgende kunnen typen
        }
    }

    private func verwijder(_ lijst: [Taak], _ indexen: IndexSet) {
        indexen.map { lijst[$0] }.forEach(app.context.delete)
        app.bewaar()
    }
}

/// Rij met afvinkrondje, titel, notitie, deadline en wie het doet.
private struct TaakRij: View {
    @ObservedObject var taak: Taak
    let openen: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            TaakKorteRij(taak: taak)
            Button(action: openen) {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Details van \(taak.weergaveTitel)")
        }
    }
}

/// Nieuwe taak of bestaande wijzigen.
struct TaakBewerkenView: View {
    @ObservedObject var naaste: Naaste
    let taak: Taak?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var titel = ""
    @State private var notitie = ""
    @State private var heeftDeadline = false
    @State private var deadline = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var wie: Familielid?
    @State private var bevestigVerwijderen = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Bijv. thuiszorg bellen over nieuwe tijden", text: $titel, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Notitie", text: $notitie, axis: .vertical)
                        .lineLimit(1...6)
                }

                Section {
                    let leden = naaste.familieledenLijst.sorted { $0.weergaveNaam < $1.weergaveNaam }
                    Picker("Wie doet het", selection: $wie) {
                        Text("Niemand").tag(Familielid?.none)
                        ForEach(leden) { lid in
                            Text(lid.weergaveNaam).tag(Familielid?.some(lid))
                        }
                    }
                    Toggle("Deadline", isOn: $heeftDeadline.animation())
                    if heeftDeadline {
                        DatePicker("Datum", selection: $deadline, displayedComponents: .date)
                    }
                } footer: {
                    if naaste.familieledenLijst.isEmpty {
                        Text("Voeg familieleden toe in Instellingen om taken te verdelen.")
                    }
                }

                if taak != nil {
                    Section {
                        Button("Taak verwijderen", role: .destructive) {
                            bevestigVerwijderen = true
                        }
                    }
                }
            }
            .navigationTitle(taak == nil ? "Nieuwe taak" : "Wijzig taak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar", action: bewaar)
                        .disabled(titel.nietLeeg == nil)
                }
            }
            .confirmationDialog("Taak verwijderen?", isPresented: $bevestigVerwijderen, titleVisibility: .visible) {
                Button("Verwijder", role: .destructive) {
                    if let taak {
                        app.context.delete(taak)
                        if app.bewaar() { dismiss() }
                    }
                }
            }
            .onAppear(perform: laad)
        }
    }

    private func laad() {
        guard let taak else { return }
        titel = taak.titel ?? ""
        notitie = taak.notitie ?? ""
        heeftDeadline = taak.deadline != nil
        deadline = taak.deadline ?? deadline
        wie = taak.toegewezenAan
    }

    private func bewaar() {
        let doel = taak ?? {
            let nieuw = app.context.maak(Taak.self, bij: naaste)
            nieuw.naaste = naaste
            return nieuw
        }()
        doel.titel = titel.nietLeeg
        doel.notitie = notitie.nietLeeg
        doel.deadline = heeftDeadline ? Calendar.current.startOfDay(for: deadline) : nil
        doel.toegewezenAan = wie
        doel.gewijzigd = .now
        if app.bewaar() { dismiss() }
    }
}
