import CoreData
import NaasteKit
import SwiftUI

/// Nieuwe zaak of bestaande wijzigen. Een andere status komt ook in de tijdlijn.
struct ZaakBewerkenView: View {
    @ObservedObject var naaste: Naaste
    let zaak: Zaak?
    /// Aangeroepen na verwijderen, zodat het detailscherm ook kan sluiten.
    var naVerwijderen: (() -> Void)?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var titel = ""
    @State private var categorie: DocumentCategorie = .wmo
    @State private var status: ZaakStatus = .voorbereiden
    @State private var oppakker: Familielid?
    @State private var heeftAanvraagdatum = false
    @State private var aanvraagdatum = Date.now
    @State private var heeftVervolg = false
    @State private var vervolgdatum = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    @State private var vervolgHerinneren = true
    @State private var notities = ""
    @State private var bevestigVerwijderen = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Bijv. Wmo-aanvraag huishoudelijke hulp", text: $titel, axis: .vertical)
                        .lineLimit(1...3)
                    Picker("Soort", selection: $categorie) {
                        ForEach(DocumentCategorie.allCases) { categorie in
                            Label(categorie.titel, systemImage: categorie.symbool).tag(categorie)
                        }
                    }
                    Picker("Status", selection: $status) {
                        ForEach(ZaakStatus.allCases) { status in
                            Label(status.titel, systemImage: status.symbool).tag(status)
                        }
                    }
                }

                let leden = naaste.familieledenLijst.sorted { $0.weergaveNaam < $1.weergaveNaam }
                if !leden.isEmpty {
                    Section {
                        Picker("Pakt het op", selection: $oppakker) {
                            Text("Niemand").tag(Familielid?.none)
                            ForEach(leden) { lid in
                                Text(lid.weergaveNaam).tag(Familielid?.some(lid))
                            }
                        }
                    }
                }

                Section {
                    Toggle("Aanvraag is verstuurd", isOn: $heeftAanvraagdatum.animation())
                    if heeftAanvraagdatum {
                        DatePicker("Verstuurd op", selection: $aanvraagdatum, in: ...Date.now, displayedComponents: .date)
                    }
                } footer: {
                    Text("Handig voor termijnen: de gemeente beslist bij de Wmo meestal binnen 8 weken.")
                }

                Section {
                    Toggle("Vervolgdatum", isOn: $heeftVervolg.animation())
                    if heeftVervolg {
                        DatePicker("Datum", selection: $vervolgdatum, displayedComponents: .date)
                        Toggle("Melding op die dag", isOn: $vervolgHerinneren)
                    }
                } footer: {
                    Text("Wanneer moet er weer iets gebeuren? Bijv. nabellen als er na 6 weken nog geen bericht is.")
                }

                Section("Notities") {
                    TextField("Bijv. naam van de consulent, wat er is afgesproken", text: $notities, axis: .vertical)
                        .lineLimit(3...10)
                }

                if zaak != nil {
                    Section {
                        Button("Zaak verwijderen", role: .destructive) {
                            bevestigVerwijderen = true
                        }
                    }
                }
            }
            .navigationTitle(zaak == nil ? "Nieuwe zaak" : "Wijzig zaak")
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
            .confirmationDialog("Zaak verwijderen?", isPresented: $bevestigVerwijderen, titleVisibility: .visible) {
                Button("Verwijder", role: .destructive, action: verwijder)
            } message: {
                Text("De tijdlijn verdwijnt ook. Gekoppelde documenten blijven bewaard in Documenten.")
            }
            .onAppear(perform: laad)
        }
        .interactiveDismissDisabled()
    }

    private func laad() {
        guard let zaak else {
            oppakker = app.ik(bij: naaste)
            return
        }
        titel = zaak.titel ?? ""
        categorie = zaak.categorieWaarde
        status = zaak.statusWaarde
        oppakker = zaak.opgepaktDoor
        heeftAanvraagdatum = zaak.datumAangevraagd != nil
        aanvraagdatum = zaak.datumAangevraagd ?? .now
        heeftVervolg = zaak.vervolgdatum != nil
        vervolgdatum = zaak.vervolgdatum ?? vervolgdatum
        vervolgHerinneren = zaak.vervolgdatum == nil ? true : zaak.vervolgHerinneren
        notities = zaak.notities ?? ""
    }

    private func bewaar() {
        let doel: Zaak
        if let zaak {
            doel = zaak
        } else {
            doel = app.context.maak(Zaak.self, bij: naaste)
            doel.naaste = naaste
            doel.statusWaarde = .voorbereiden
        }
        doel.titel = titel.nietLeeg
        doel.categorieWaarde = categorie
        doel.opgepaktDoor = oppakker
        doel.datumAangevraagd = heeftAanvraagdatum ? Calendar.current.startOfDay(for: aanvraagdatum) : nil
        doel.vervolgdatum = heeftVervolg ? Calendar.current.startOfDay(for: vervolgdatum) : nil
        doel.vervolgHerinneren = heeftVervolg && vervolgHerinneren
        doel.notities = notities.nietLeeg
        // Via zetStatus, zodat de wijziging in de tijdlijn komt.
        doel.zetStatus(status, op: heeftAanvraagdatum && status == .aangevraagd ? aanvraagdatum : .now, door: app.auteur(bij: naaste))
        doel.gewijzigd = .now

        guard app.bewaar() else { return }
        if doel.vervolgHerinneren { app.vraagMeldingenToestemmingEnPlan() }
        dismiss()
    }

    private func verwijder() {
        guard let zaak else { return }
        app.context.delete(zaak)
        if app.bewaar() {
            dismiss()
            naVerwijderen?()
        }
    }
}
