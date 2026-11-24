import CoreData
import NaasteKit
import SwiftUI

/// Urenlogboek (Plus): wie besteedt hoeveel tijd aan de zorg.
///
/// Zonder Plus blijven bestaande uren zichtbaar (alleen lezen); nieuwe uren
/// toevoegen vraagt om Plus.
struct UrenView: View {
    @ObservedObject var naaste: Naaste
    @Environment(AppModel.self) private var app
    @FetchRequest private var regels: FetchedResults<Urenregel>

    @AppStorage("urenPeriode") private var periode: UrenPeriode = .dezeMaand
    @State private var nieuw = false
    @State private var bewerken: Urenregel?
    @State private var exportPDF: Data?

    init(naaste: Naaste) {
        self.naaste = naaste
        _regels = FetchRequest(fetchRequest: Urenregel.alle(voor: naaste))
    }

    private var magToevoegen: Bool { app.heeftToegang(tot: .urenlogboek, bij: naaste) }

    var body: some View {
        if !magToevoegen && regels.isEmpty {
            uitleg
        } else {
            overzicht
        }
    }

    // MARK: Zonder Plus en zonder uren

    private var uitleg: some View {
        ContentUnavailableView {
            Label("Urenlogboek", systemImage: "clock")
        } description: {
            Text("Houd bij wie hoeveel tijd besteedt aan de zorg: administratie, vervoer, boodschappen. Handig om het werk eerlijk te verdelen en voor de mantelzorgwaardering van de gemeente.")
        } actions: {
            Button {
                _ = app.vraagToegang(tot: .urenlogboek, bij: naaste)
            } label: {
                Text("Bekijk Naaste Plus")
                    .frame(minWidth: 220, minHeight: 34)
            }
            .hoofdknop()
        }
    }

    // MARK: Overzicht

    private var overzicht: some View {
        let nu = Date.now
        let interval = periode.interval(nu: nu)
        let data = regels.map(\.data)
        let totaal = UrenRekenaar.totaal(data, periode: interval)
        let perPersoon = UrenRekenaar.perPersoon(data, periode: interval)
        let perCategorie = UrenRekenaar.perCategorie(data, periode: interval)
        let inPeriode = regels.filter { regel in
            interval.map { $0.contains(regel.data.datum) && regel.data.datum < $0.end } ?? true
        }

        return List {
            if !magToevoegen {
                Section {
                    Label("Je kunt je uren bekijken. Nieuwe uren toevoegen kan met Naaste Plus.", systemImage: "lock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("Periode", selection: $periode) {
                    ForEach(UrenPeriode.allCases) { Text($0.titel).tag($0) }
                }
                // Als losse lijst: leesbaar bij elke tekstgrootte (een menu kapt "Deze maand" af).
                .pickerStyle(.navigationLink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Duur.tekst(minuten: totaal))
                        .font(.largeTitle.weight(.semibold))
                        .monospacedDigit()
                    Text("in totaal, \(periode.titel.lowercased())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Duur.tekst(minuten: totaal, kort: false)) in totaal, \(periode.titel.lowercased())")
            }

            if !perPersoon.isEmpty {
                Section("Per persoon") {
                    ForEach(perPersoon) { rij in
                        PersoonBalk(totaal: rij, kleur: kleur(voor: rij.id))
                    }
                }
            }

            if !perCategorie.isEmpty {
                Section("Waaraan") {
                    ForEach(perCategorie, id: \.categorie) { rij in
                        LabeledContent {
                            Text(Duur.tekst(minuten: rij.minuten))
                                .monospacedDigit()
                        } label: {
                            Label(rij.categorie.titel, systemImage: rij.categorie.symbool)
                        }
                    }
                }
            }

            Section {
                if inPeriode.isEmpty {
                    LegeRij(tekst: "Nog geen uren in deze periode.")
                }
                ForEach(inPeriode) { regel in
                    Button {
                        bewerken = regel
                    } label: {
                        UrenregelRij(regel: regel)
                    }
                    .tint(.primary)
                }
                .onDelete { indexen in
                    indexen.map { inPeriode[$0] }.forEach(app.context.delete)
                    app.bewaar()
                }
            } header: {
                Text("Logboek")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if app.vraagToegang(tot: .urenExport, bij: naaste) {
                        exportPDF = Exports.uren(naaste, periode: periode)
                    }
                } label: {
                    Label("Exporteer als PDF", systemImage: "square.and.arrow.up")
                }
                .disabled(regels.isEmpty)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if app.vraagToegang(tot: .urenlogboek, bij: naaste) { nieuw = true }
                } label: {
                    Label("Uren toevoegen", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $nieuw) {
            UrenregelBewerkenView(naaste: naaste, regel: nil)
        }
        .sheet(isPresented: Binding(get: { exportPDF != nil }, set: { if !$0 { exportPDF = nil } })) {
            if let exportPDF {
                PDFVoorbeeldView(
                    titel: String(localized: "Urenoverzicht"),
                    data: exportPDF,
                    bestandsnaam: DocumentNamen.bestandsnaam(voorTitel: String(localized: "Uren \(naaste.weergaveNaam) \(Exports.periodeTekst(periode, interval: periode.interval(nu: .now), regels: regels.map(\.data)))"))
                )
            }
        }
        .sheet(item: $bewerken) { regel in
            UrenregelBewerkenView(naaste: naaste, regel: regel)
        }
    }

    private func kleur(voor persoonID: String) -> Color {
        naaste.familieledenLijst.first { $0.uuid?.uuidString == persoonID }?.kleurWaarde.kleur ?? .gray
    }
}

extension UrenPeriode {
    var titel: String {
        switch self {
        case .dezeMaand: String(localized: "Deze maand")
        case .vorigeMaand: String(localized: "Vorige maand")
        case .ditJaar: String(localized: "Dit jaar")
        case .alles: String(localized: "Alles")
        }
    }
}

private struct PersoonBalk: View {
    let totaal: UrenTotaal
    let kleur: Color

    private var tijdEnAandeel: some View {
        HStack(spacing: 8) {
            Text(Duur.tekst(minuten: totaal.minuten))
                .monospacedDigit()
            Text(totaal.aandeel, format: .percent.precision(.fractionLength(0)))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 44, alignment: .trailing)
        }
        .lineLimit(1)
        .fixedSize()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(totaal.naam)
                    Spacer()
                    tijdEnAandeel
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(totaal.naam)
                    tijdEnAandeel
                }
            }
            GeometryReader { geo in
                Capsule()
                    .fill(.quaternary)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(kleur)
                            .frame(width: max(geo.size.width * totaal.aandeel, 6))
                    }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(totaal.naam): \(Duur.tekst(minuten: totaal.minuten, kort: false)), \(Int((totaal.aandeel * 100).rounded())) procent")
    }
}

private struct UrenregelRij: View {
    @ObservedObject var regel: Urenregel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let lid = regel.familielid {
                Avatar(lid: lid, grootte: 32)
            } else {
                Image(systemName: regel.categorieWaarde.symbool)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(regel.omschrijving?.nietLeeg ?? regel.categorieWaarde.titel)
                Text(onderregel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Duur.tekst(minuten: Int(regel.minuten)))
                .monospacedDigit()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var onderregel: String {
        var delen: [String] = []
        if let datum = regel.datum { delen.append(datum.kort) }
        if let lid = regel.familielid { delen.append(lid.weergaveNaam) }
        if regel.omschrijving?.nietLeeg != nil { delen.append(regel.categorieWaarde.titel) }
        return delen.joined(separator: " · ")
    }
}

/// Uren toevoegen of wijzigen. Duur in stappen van 5 minuten.
struct UrenregelBewerkenView: View {
    @ObservedObject var naaste: Naaste
    let regel: Urenregel?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var datum = Date.now
    @State private var uren = 1
    @State private var minuten = 0
    @State private var categorie: UrenCategorie = .administratie
    @State private var wie: Familielid?
    @State private var omschrijving = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Datum", selection: $datum, in: ...Date.now, displayedComponents: .date)
                    HStack {
                        Text("Duur")
                        Spacer()
                        Picker("Uren", selection: $uren) {
                            ForEach(0..<25) { Text("\($0) u").tag($0) }
                        }
                        .labelsHidden()
                        Picker("Minuten", selection: $minuten) {
                            ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) min").tag($0) }
                        }
                        .labelsHidden()
                    }
                }

                Section {
                    Picker("Waaraan", selection: $categorie) {
                        ForEach(UrenCategorie.allCases) { categorie in
                            Label(categorie.titel, systemImage: categorie.symbool).tag(categorie)
                        }
                    }
                    let leden = naaste.familieledenLijst.sorted { $0.weergaveNaam < $1.weergaveNaam }
                    Picker("Wie", selection: $wie) {
                        Text("Niet toegewezen").tag(Familielid?.none)
                        ForEach(leden) { lid in
                            Text(lid.weergaveNaam).tag(Familielid?.some(lid))
                        }
                    }
                    TextField("Omschrijving, bijv. mee naar het ziekenhuis", text: $omschrijving, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle(regel == nil ? "Uren toevoegen" : "Wijzig uren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar", action: bewaar)
                        .disabled(uren * 60 + minuten == 0)
                }
            }
            .onAppear(perform: laad)
        }
        .presentationDetents([.large])
    }

    private func laad() {
        guard let regel else {
            wie = app.ik(bij: naaste)
            return
        }
        datum = regel.datum ?? .now
        let (u, m) = UrenRekenaar.urenEnMinuten(Int(regel.minuten))
        uren = min(u, 24)
        minuten = m - m % 5
        categorie = regel.categorieWaarde
        wie = regel.familielid
        omschrijving = regel.omschrijving ?? ""
    }

    private func bewaar() {
        let doel = regel ?? {
            let nieuw = app.context.maak(Urenregel.self, bij: naaste)
            nieuw.naaste = naaste
            return nieuw
        }()
        doel.datum = datum
        doel.minuten = Int32(uren * 60 + minuten)
        doel.categorieWaarde = categorie
        doel.familielid = wie
        doel.omschrijving = omschrijving.nietLeeg
        doel.gewijzigd = .now
        if app.bewaar() { dismiss() }
    }
}
