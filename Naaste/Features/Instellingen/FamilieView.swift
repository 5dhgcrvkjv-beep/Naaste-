import CoreData
import SwiftUI

/// Familieleden van een naaste: naamkaartjes voor taken, uren en "wie pakt het op".
struct FamilieView: View {
    @ObservedObject var naaste: Naaste
    @Environment(AppModel.self) private var app
    @FetchRequest private var leden: FetchedResults<Familielid>
    @AppStorage private var ikBen: String

    @State private var nieuw = false
    @State private var bewerk: Familielid?

    init(naaste: Naaste) {
        self.naaste = naaste
        _leden = FetchRequest(fetchRequest: Familielid.alle(voor: naaste))
        _ikBen = AppStorage(wrappedValue: "", Opslagsleutel.ikBen(naaste))
    }

    var body: some View {
        List {
            Section {
                ForEach(leden) { lid in
                    Button {
                        bewerk = lid
                    } label: {
                        HStack(spacing: 12) {
                            Avatar(lid: lid, grootte: 36)
                            Text(lid.weergaveNaam)
                                .foregroundStyle(.primary)
                            if lid.uuid?.uuidString == ikBen {
                                Etiket(tekst: String(localized: "Ik"), kleur: .accentColor)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityHint("Tik om te wijzigen.")
                }
                .onDelete { offsets in
                    for index in offsets { app.context.delete(leden[index]) }
                    app.bewaar()
                }

                Button {
                    nieuw = true
                } label: {
                    Label("Familielid toevoegen", systemImage: "plus.circle")
                }
            } header: {
                Text("Familie van \(naaste.weergaveNaam)")
            } footer: {
                Text("Verwijder je iemand, dan blijven de taken en uren bestaan, maar zonder naam.")
            }

            if !leden.isEmpty {
                Section {
                    Picker("Ik ben", selection: $ikBen) {
                        Text("Niet gekozen").tag("")
                        ForEach(leden) { lid in
                            Text(lid.weergaveNaam).tag(lid.uuid?.uuidString ?? "")
                        }
                    }
                } header: {
                    Text("Op deze iPhone")
                } footer: {
                    Text("Dan zie je je eigen taken bovenaan en worden nieuwe uren aan jou toegeschreven. Dit wordt alleen op deze iPhone bewaard.")
                }
            }
        }
        .navigationTitle("Familieleden")
        .sheet(isPresented: $nieuw) {
            FamilielidBewerkenView(naaste: naaste, lid: nil)
        }
        .sheet(item: $bewerk) { lid in
            FamilielidBewerkenView(naaste: naaste, lid: lid)
        }
    }
}

struct FamilielidBewerkenView: View {
    let naaste: Naaste
    let lid: Familielid?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var naam = ""
    @State private var kleur: FamilieKleur = .groen
    @State private var geladen = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Naam", text: $naam)
                    .textContentType(.givenName)
                Picker("Kleur", selection: $kleur) {
                    ForEach(FamilieKleur.allCases) { k in
                        Label {
                            Text(k.titel)
                        } icon: {
                            Image(systemName: "circle.fill").foregroundStyle(k.kleur)
                        }
                        .tag(k)
                    }
                }
            }
            .navigationTitle(lid == nil ? "Nieuw familielid" : "Wijzig familielid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar", action: bewaar)
                        .disabled(naam.nietLeeg == nil)
                }
            }
            .onAppear {
                guard !geladen else { return }
                geladen = true
                if let lid {
                    naam = lid.naam ?? ""
                    kleur = lid.kleurWaarde
                } else {
                    kleur = FamilieKleur.volgende(na: naaste.familieledenLijst.map(\.kleurWaarde))
                }
            }
        }
    }

    private func bewaar() {
        let doel = lid ?? app.context.maak(Familielid.self, bij: naaste)
        doel.naaste = naaste
        doel.naam = naam.nietLeeg
        doel.kleurWaarde = kleur
        doel.gewijzigd = Date()
        if app.bewaar() { dismiss() }
    }
}
