import CoreData
import SwiftUI

/// Formulier voor een nieuwe of bestaande naaste. Wijzigingen worden pas bij "Bewaar" opgeslagen.
struct NaasteBewerkenView: View {
    enum Modus {
        case nieuw
        case bewerk(Naaste)
    }

    let modus: Modus
    let naVerwijderen: (() -> Void)?
    let opgeslagen: ((Naaste) -> Void)?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var concept = NaasteConcept()
    @State private var geladen = false
    @State private var bevestigVerwijderen = false

    init(modus: Modus, naVerwijderen: (() -> Void)? = nil, opgeslagen: ((Naaste) -> Void)? = nil) {
        self.modus = modus
        self.naVerwijderen = naVerwijderen
        self.opgeslagen = opgeslagen
    }

    private var bestaande: Naaste? {
        if case let .bewerk(naaste) = modus { return naaste }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Persoonlijk") {
                    TextField("Naam", text: $concept.naam)
                        .textContentType(.name)
                        .submitLabel(.next)
                    Toggle("Geboortedatum invullen", isOn: $concept.heeftGeboortedatum.animation())
                    if concept.heeftGeboortedatum {
                        DatePicker("Geboortedatum", selection: $concept.geboortedatum, in: ...Date(), displayedComponents: .date)
                    }
                    TextField("Telefoon", text: $concept.telefoon)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                Section("Adres") {
                    TextField("Straat en huisnummer", text: $concept.straat)
                        .textContentType(.fullStreetAddress)
                    TextField("Postcode", text: $concept.postcode)
                        .textContentType(.postalCode)
                        .textInputAutocapitalization(.characters)
                    TextField("Plaats", text: $concept.plaats)
                        .textContentType(.addressCity)
                }

                Section("Huisarts") {
                    TextField("Naam praktijk of huisarts", text: $concept.huisartsNaam)
                    TextField("Telefoon huisarts", text: $concept.huisartsTelefoon)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                Section("Zorgverzekering") {
                    TextField("Zorgverzekeraar", text: $concept.zorgverzekeraar)
                    TextField("Polisnummer", text: $concept.polisnummer)
                        .keyboardType(.asciiCapable)
                        .autocorrectionDisabled()
                    TextField("Telefoon verzekeraar", text: $concept.verzekeraarTelefoon)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                Section {
                    TextField("Bijvoorbeeld waar het medicijnoverzicht ligt", text: $concept.medicatieNotitie, axis: .vertical)
                        .lineLimit(2...8)
                } header: {
                    Text("Medicatie (notitie)")
                } footer: {
                    Text("Een vrije notitie voor de familie. Naaste geeft geen medisch advies en controleert niets.")
                }

                Section("Notities") {
                    TextField("Bijvoorbeeld sleutel, gewoontes, aandachtspunten", text: $concept.notities, axis: .vertical)
                        .lineLimit(2...10)
                }

                if let bestaande, !app.persistence.staatInGedeeldeOpslag(bestaande) {
                    Section {
                        Button("Naaste verwijderen", role: .destructive) {
                            bevestigVerwijderen = true
                        }
                    } footer: {
                        Text("Verwijdert ook alle documenten, zaken, taken en uren van deze naaste, op al je apparaten en voor familieleden met wie je deelt.")
                    }
                }
            }
            .navigationTitle(bestaande == nil ? "Nieuwe naaste" : "Wijzig gegevens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar", action: bewaar)
                        .disabled(concept.naam.nietLeeg == nil)
                }
            }
            .confirmationDialog(
                "Naaste verwijderen?",
                isPresented: $bevestigVerwijderen,
                titleVisibility: .visible
            ) {
                Button("Verwijder \(concept.naam.nietLeeg ?? String(localized: "naaste"))", role: .destructive, action: verwijder)
                Button("Annuleer", role: .cancel) {}
            } message: {
                Text("Dit kan niet ongedaan worden gemaakt.")
            }
            .onAppear {
                guard !geladen else { return }
                geladen = true
                if let bestaande { concept = NaasteConcept(bestaande) }
            }
        }
    }

    private func bewaar() {
        let naaste = bestaande ?? Naaste(context: app.context)
        concept.pasToe(op: naaste)
        naaste.eigenaarHeeftPlus = bestaande?.eigenaarHeeftPlus ?? app.isPlus
        if app.bewaar() {
            opgeslagen?(naaste)
            dismiss()
        }
    }

    private func verwijder() {
        guard let bestaande else { return }
        // Eerst de schermen sluiten, dan verwijderen: zo toont geen enkel scherm nog een verwijderd object.
        dismiss()
        naVerwijderen?()
        let app = app
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            app.context.delete(bestaande)
            app.bewaar()
        }
    }
}

/// Bewerkbare kopie van de velden van een naaste.
struct NaasteConcept: Equatable {
    var naam = ""
    var heeftGeboortedatum = false
    var geboortedatum = Calendar.current.date(byAdding: .year, value: -80, to: .now) ?? .now
    var telefoon = ""
    var straat = ""
    var postcode = ""
    var plaats = ""
    var huisartsNaam = ""
    var huisartsTelefoon = ""
    var zorgverzekeraar = ""
    var polisnummer = ""
    var verzekeraarTelefoon = ""
    var medicatieNotitie = ""
    var notities = ""

    init() {}

    init(_ n: Naaste) {
        naam = n.naam ?? ""
        heeftGeboortedatum = n.geboortedatum != nil
        if let datum = n.geboortedatum { geboortedatum = datum }
        telefoon = n.telefoon ?? ""
        straat = n.straat ?? ""
        postcode = n.postcode ?? ""
        plaats = n.plaats ?? ""
        huisartsNaam = n.huisartsNaam ?? ""
        huisartsTelefoon = n.huisartsTelefoon ?? ""
        zorgverzekeraar = n.zorgverzekeraar ?? ""
        polisnummer = n.polisnummer ?? ""
        verzekeraarTelefoon = n.verzekeraarTelefoon ?? ""
        medicatieNotitie = n.medicatieNotitie ?? ""
        notities = n.notities ?? ""
    }

    func pasToe(op n: Naaste) {
        n.naam = naam.nietLeeg
        n.geboortedatum = heeftGeboortedatum ? geboortedatum : nil
        n.telefoon = telefoon.nietLeeg
        n.straat = straat.nietLeeg
        n.postcode = postcode.nietLeeg?.uppercased()
        n.plaats = plaats.nietLeeg
        n.huisartsNaam = huisartsNaam.nietLeeg
        n.huisartsTelefoon = huisartsTelefoon.nietLeeg
        n.zorgverzekeraar = zorgverzekeraar.nietLeeg
        n.polisnummer = polisnummer.nietLeeg
        n.verzekeraarTelefoon = verzekeraarTelefoon.nietLeeg
        n.medicatieNotitie = medicatieNotitie.nietLeeg
        n.notities = notities.nietLeeg
        n.gewijzigd = Date()
    }
}
