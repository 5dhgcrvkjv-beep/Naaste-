import CoreData
import NaasteKit
import SwiftUI

struct OverzichtView: View {
    var body: some View {
        NavigationStack {
            MetGeselecteerdeNaaste { naaste in
                OverzichtInhoud(naaste: naaste)
            }
        }
    }
}

private struct OverzichtInhoud: View {
    @ObservedObject var naaste: Naaste

    @FetchRequest private var herinneringen: FetchedResults<Herinnering>
    @FetchRequest private var zaken: FetchedResults<Zaak>
    @FetchRequest private var taken: FetchedResults<Taak>
    @FetchRequest private var contacten: FetchedResults<Contactpersoon>
    @State private var overdracht = false

    init(naaste: Naaste) {
        self.naaste = naaste
        _herinneringen = FetchRequest(fetchRequest: Herinnering.open(voor: naaste))
        _zaken = FetchRequest(fetchRequest: Zaak.lopend(voor: naaste))
        _taken = FetchRequest(fetchRequest: Taak.open(voor: naaste))
        _contacten = FetchRequest(fetchRequest: Contactpersoon.alle(voor: naaste))
    }

    var body: some View {
        List {
            if naaste.isVoorbeeld {
                Section { VoorbeeldBanner() }
            }

            Section {
                NavigationLink {
                    ProfielView(naaste: naaste)
                } label: {
                    NaasteKop(naaste: naaste)
                }
            }

            Section("Binnenkort") {
                let items = binnenkort
                if items.isEmpty {
                    LegeRij(tekst: "Geen deadlines of afspraken in de komende 2 maanden.")
                } else {
                    ForEach(items) { item in
                        BinnenkortRij(item: item)
                    }
                }
                NavigationLink {
                    HerinneringenView(naaste: naaste)
                } label: {
                    Label("Alle herinneringen", systemImage: "bell")
                        .foregroundStyle(Color.accentColor)
                }
            }

            Section {
                if zaken.isEmpty {
                    LegeRij(tekst: "Er lopen geen zaken. Leg een aanvraag vast in het tabblad Zaken.")
                } else {
                    ForEach(zaken.sorted(by: Zaak.sorteerOpVervolg).prefix(3)) { zaak in
                        NavigationLink {
                            ZaakDetailView(zaak: zaak)
                        } label: {
                            ZaakKorteRij(zaak: zaak)
                        }
                    }
                }
            } header: {
                Text("Lopende zaken")
            } footer: {
                if zaken.count > 3 {
                    Text("En nog \(zaken.count - 3) andere in het tabblad Zaken.")
                }
            }

            Section {
                if taken.isEmpty {
                    LegeRij(tekst: "Geen open taken.")
                } else {
                    ForEach(taken.sorted(by: Taak.sorteer).prefix(4)) { taak in
                        TaakKorteRij(taak: taak)
                    }
                }
            } header: {
                Text("Open taken")
            } footer: {
                if taken.count > 4 {
                    Text("En nog \(taken.count - 4) andere in het tabblad Taken.")
                }
            }

            Section("Snel contact") {
                if let url = ContactLinks.belURL(naaste.huisartsTelefoon) {
                    SnelContactRij(
                        titel: naaste.huisartsNaam?.nietLeeg ?? String(localized: "Huisarts"),
                        ondertitel: String(localized: "Huisarts"),
                        symbool: ContactRol.huisarts.symbool,
                        belURL: url,
                        mailURL: nil
                    )
                }
                let belangrijk = contacten.sorted(by: Contactpersoon.sorteer).prefix(4)
                ForEach(Array(belangrijk)) { contact in
                    SnelContactRij(
                        titel: contact.weergaveNaam,
                        ondertitel: contact.ondertitel,
                        symbool: contact.rolWaarde.symbool,
                        belURL: ContactLinks.belURL(contact.telefoon),
                        mailURL: ContactLinks.mailURL(contact.email)
                    )
                }
                if contacten.isEmpty && ContactLinks.belURL(naaste.huisartsTelefoon) == nil {
                    LegeRij(tekst: "Voeg contactpersonen toe via het profiel hierboven.")
                }
            }

            Section {
                Button {
                    overdracht = true
                } label: {
                    Label("Overdrachtsoverzicht maken", systemImage: "doc.richtext")
                }
            } footer: {
                Text("Alles op een rij als PDF, voor wie het even overneemt.")
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $overdracht) {
            OverdrachtView(naaste: naaste)
        }
        .navigationTitle(naaste.weergaveNaam)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NaasteWisselaar()
            }
        }
    }

    /// Herinneringen en vervolgdatums van zaken in de komende 60 dagen.
    private var binnenkort: [BinnenkortItem] {
        let nu = Date()
        let grens = Calendar.current.date(byAdding: .day, value: 60, to: nu) ?? nu
        var items: [BinnenkortItem] = herinneringen.compactMap { h in
            guard let datum = h.volgendeDatum(nu: nu), datum <= grens else { return nil }
            return BinnenkortItem(
                id: h.objectID.uriRepresentation().absoluteString,
                titel: h.weergaveTitel,
                ondertitel: h.soortWaarde.titel,
                datum: datum,
                heeftTijd: h.heeftTijd,
                symbool: h.soortWaarde.symbool
            )
        }
        for zaak in zaken {
            guard let datum = zaak.vervolgdatum, datum <= grens,
                  datum >= Calendar.current.startOfDay(for: nu) else { continue }
            items.append(BinnenkortItem(
                id: zaak.objectID.uriRepresentation().absoluteString,
                titel: zaak.weergaveTitel,
                ondertitel: String(localized: "Vervolgactie zaak"),
                datum: datum,
                heeftTijd: false,
                symbool: "folder"
            ))
        }
        return Array(items.sorted { $0.datum < $1.datum }.prefix(5))
    }
}

struct BinnenkortItem: Identifiable {
    let id: String
    let titel: String
    let ondertitel: String
    let datum: Date
    let heeftTijd: Bool
    let symbool: String
}

private struct BinnenkortRij: View {
    let item: BinnenkortItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.symbool)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.titel)
                    .font(.body)
                Text(datumTekst)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var datumTekst: String {
        let datum = item.heeftTijd
            ? item.datum.formatted(date: .abbreviated, time: .shortened)
            : item.datum.formatted(date: .abbreviated, time: .omitted)
        return "\(item.ondertitel) · \(datum) (\(item.datum.relatief))"
    }
}

private struct NaasteKop: View {
    @ObservedObject var naaste: Naaste

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(naaste.weergaveNaam)
                    .font(.title3.weight(.semibold))
                if let adres = naaste.adresRegel {
                    Text(adres)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Profiel en contactpersonen")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opent het profiel met adres, huisarts, verzekering en contactpersonen.")
    }
}

struct ZaakKorteRij: View {
    @ObservedObject var zaak: Zaak

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(zaak.weergaveTitel)
            HStack(spacing: 8) {
                Etiket(tekst: zaak.statusWaarde.titel, symbool: zaak.statusWaarde.symbool, kleur: zaak.statusWaarde.kleur)
                if let vervolg = zaak.vervolgdatum {
                    Text("Vervolg \(vervolg.relatief)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct TaakKorteRij: View {
    @ObservedObject var taak: Taak
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation { taak.zetAfgerond(!taak.afgerond) }
                app.bewaar()
            } label: {
                Image(systemName: taak.afgerond ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(taak.afgerond ? Color.accentColor : .secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(taak.afgerond ? "Markeer als niet gedaan" : "Markeer als gedaan")

            VStack(alignment: .leading, spacing: 2) {
                Text(taak.weergaveTitel)
                    .strikethrough(taak.afgerond)
                HStack(spacing: 6) {
                    if let lid = taak.toegewezenAan {
                        Text(lid.weergaveNaam)
                    }
                    if let deadline = taak.deadline {
                        Text(deadline.relatief)
                            .foregroundStyle(deadline < Calendar.current.startOfDay(for: .now) ? Color.red : Color.secondary)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let lid = taak.toegewezenAan {
                Avatar(lid: lid, grootte: 28)
            }
        }
    }
}

private struct SnelContactRij: View {
    let titel: String
    let ondertitel: String
    let symbool: String
    let belURL: URL?
    let mailURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbool)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel)
                Text(ondertitel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            if let mailURL {
                RondeActie(symbool: "envelope.fill", label: String(localized: "Mail \(titel)"), url: mailURL)
            }
            if let belURL {
                RondeActie(symbool: "phone.fill", label: String(localized: "Bel \(titel)"), url: belURL)
            }
        }
    }
}

/// Menu rechtsboven om van naaste te wisselen of een naaste toe te voegen.
struct NaasteWisselaar: View {
    @Environment(AppModel.self) private var app
    @FetchRequest(fetchRequest: Naaste.alle()) private var naasten: FetchedResults<Naaste>
    @AppStorage(Opslagsleutel.geselecteerdeNaaste) private var geselecteerdeID = ""
    @State private var nieuweNaaste = false

    var body: some View {
        Menu {
            Picker("Naaste", selection: huidigeID) {
                ForEach(naasten) { naaste in
                    Text(naaste.isVoorbeeld ? String(localized: "\(naaste.weergaveNaam) (voorbeeld)") : naaste.weergaveNaam)
                        .tag(naaste.uuid?.uuidString ?? "")
                }
            }
            Divider()
            Button {
                if app.magNaasteToevoegen() { nieuweNaaste = true }
            } label: {
                Label("Naaste toevoegen", systemImage: "plus")
            }
        } label: {
            Image(systemName: "person.2.circle")
                .font(.title3)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Kies naaste")
        .sheet(isPresented: $nieuweNaaste) {
            NaasteBewerkenView(modus: .nieuw, opgeslagen: { naaste in
                geselecteerdeID = naaste.uuid?.uuidString ?? ""
            })
        }
    }

    private var huidigeID: Binding<String> {
        Binding(
            get: {
                naasten.first { $0.uuid?.uuidString == geselecteerdeID }?.uuid?.uuidString
                    ?? naasten.first?.uuid?.uuidString ?? ""
            },
            set: { geselecteerdeID = $0 }
        )
    }
}

/// Welkomstscherm zonder naaste.
struct GeenNaasteView: View {
    @Environment(AppModel.self) private var app
    @AppStorage(Opslagsleutel.geselecteerdeNaaste) private var geselecteerdeID = ""
    @State private var nieuweNaaste = false

    var body: some View {
        ContentUnavailableView {
            Label("Voeg je naaste toe", systemImage: "person.crop.circle.badge.plus")
        } description: {
            Text("Leg de gegevens vast van de persoon voor wie je zorgt. Daarna kun je documenten, aanvragen en taken bijhouden, samen met je familie.")
        } actions: {
            Button {
                if app.magNaasteToevoegen() { nieuweNaaste = true }
            } label: {
                Text("Naaste toevoegen")
                    .frame(minWidth: 220, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)

            Button {
                if let voorbeeld = app.laadVoorbeeld() {
                    geselecteerdeID = voorbeeld.uuid?.uuidString ?? ""
                }
            } label: {
                Text("Bekijk eerst een voorbeeld")
                    .frame(minWidth: 220, minHeight: 34)
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $nieuweNaaste) {
            NaasteBewerkenView(modus: .nieuw, opgeslagen: { naaste in
                geselecteerdeID = naaste.uuid?.uuidString ?? ""
            })
        }
    }
}
