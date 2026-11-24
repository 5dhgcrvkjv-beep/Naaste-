import CoreData
import NaasteKit
import SwiftUI

/// Tabblad Zaken: aanvragen en dossiers (Wmo, Wlz, pgb …), gegroepeerd op wie er aan zet is.
struct ZakenView: View {
    @Environment(AppModel.self) private var app
    @State private var pad = NavigationPath()
    private let navigatie = Navigatie.shared

    var body: some View {
        NavigationStack(path: $pad) {
            MetGeselecteerdeNaaste { naaste in
                ZakenLijst(naaste: naaste)
                    .id(naaste.objectID)
            }
            .navigationTitle("Zaken")
        }
        .onChange(of: navigatie.open, initial: true) { _, bestemming in
            guard case let .zaak(id) = bestemming else { return }
            navigatie.open = nil
            if let zaak = Navigatie.zoek(Zaak.self, uuid: id, in: app.context) {
                var nieuwPad = NavigationPath()
                nieuwPad.append(zaak)
                pad = nieuwPad
            }
        }
    }
}

private struct ZakenLijst: View {
    @ObservedObject var naaste: Naaste
    @FetchRequest private var zaken: FetchedResults<Zaak>
    @State private var nieuweZaak = false
    @State private var toonAfgerond = false

    init(naaste: Naaste) {
        self.naaste = naaste
        _zaken = FetchRequest(fetchRequest: Zaak.alle(voor: naaste))
    }

    var body: some View {
        let lopend = zaken.filter { $0.statusWaarde.isLopend }.sorted(by: Zaak.sorteerOpVervolg)
        let actie = lopend.filter { $0.statusWaarde.vraagtActie }
        let wachten = lopend.filter { !$0.statusWaarde.vraagtActie }
        let afgerond = zaken.filter { !$0.statusWaarde.isLopend }

        List {
            if !actie.isEmpty {
                Section {
                    ForEach(actie) { ZaakLink(zaak: $0) }
                } header: {
                    Text("Wij zijn aan zet")
                } footer: {
                    Text("Voorbereiden, afgewezen of in bezwaar: hier moet de familie iets doen.")
                }
            }
            if !wachten.isEmpty {
                Section {
                    ForEach(wachten) { ZaakLink(zaak: $0) }
                } header: {
                    Text("Wachten op de instantie")
                } footer: {
                    Text("Aangevraagd, in behandeling of toegekend. Zet een vervolgdatum om na te bellen als het lang duurt.")
                }
            }
            if !afgerond.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $toonAfgerond) {
                        ForEach(afgerond) { ZaakLink(zaak: $0) }
                    } label: {
                        Text("Afgerond (\(afgerond.count))")
                    }
                }
            }
        }
        .navigationDestination(for: Zaak.self) { zaak in
            ZaakDetailView(zaak: zaak)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    nieuweZaak = true
                } label: {
                    Label("Nieuwe zaak", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $nieuweZaak) {
            ZaakBewerkenView(naaste: naaste, zaak: nil)
        }
        .overlay {
            if zaken.isEmpty {
                ContentUnavailableView {
                    Label("Nog geen zaken", systemImage: "folder")
                } description: {
                    Text("Een zaak is een aanvraag of dossier, zoals huishoudelijke hulp via de Wmo of een indicatie bij het CIZ. Houd bij wat er gebeurd is en wat de volgende stap is.")
                } actions: {
                    Button {
                        nieuweZaak = true
                    } label: {
                        Text("Zaak toevoegen")
                            .frame(minWidth: 220, minHeight: 34)
                    }
                    .hoofdknop()
                }
            }
        }
    }
}

private struct ZaakLink: View {
    let zaak: Zaak

    var body: some View {
        NavigationLink(value: zaak) {
            ZaakRij(zaak: zaak)
        }
    }
}

/// Rij met titel, status, wie het oppakt en de vervolgdatum.
struct ZaakRij: View {
    @ObservedObject var zaak: Zaak
    @Environment(\.dynamicTypeSize) private var tekstgrootte

    var body: some View {
        let groot = tekstgrootte.isAccessibilitySize
        let indeling = groot ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        indeling {
            if !groot {
                Image(systemName: zaak.categorieWaarde.symbool)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(zaak.weergaveTitel)
                // Naast elkaar als het past, anders onder elkaar (grote letters, smalle iPhone).
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { statusEnVervolg }
                    VStack(alignment: .leading, spacing: 4) { statusEnVervolg }
                }
            }
            if !groot { Spacer(minLength: 0) }
            if let lid = zaak.opgepaktDoor {
                Avatar(lid: lid, grootte: 28)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(zaak.opgepaktDoor.map { String(localized: "Opgepakt door \($0.weergaveNaam)") } ?? "")
    }

    @ViewBuilder private var statusEnVervolg: some View {
        Etiket(tekst: zaak.statusWaarde.titel, symbool: zaak.statusWaarde.symbool, kleur: zaak.statusWaarde.kleur)
        if let vervolg = zaak.vervolgdatum, zaak.statusWaarde.isLopend {
            Text("Vervolg \(vervolg.relatief)")
                .font(.caption)
                .lineLimit(tekstgrootte.isAccessibilitySize ? nil : 1)
                .foregroundStyle(vervolg < Calendar.current.startOfDay(for: .now) ? .red : .secondary)
        }
    }
}
