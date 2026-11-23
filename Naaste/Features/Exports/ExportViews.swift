import NaasteKit
import SwiftUI

/// Een gemaakte PDF bekijken en delen (Berichten, Mail, AirDrop, afdrukken, opslaan in Bestanden).
struct PDFVoorbeeldView: View {
    let titel: String
    let data: Data
    let bestandsnaam: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFWeergave(data: data)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(titel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Sluit") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: PDFExport(data: data, bestandsnaam: bestandsnaam), preview: SharePreview(titel)) {
                            Label("Deel of druk af", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

/// Kies wat er in het overdrachtsoverzicht komt en maak de PDF. Altijd gratis.
struct OverdrachtView: View {
    @ObservedObject var naaste: Naaste
    @Environment(\.dismiss) private var dismiss
    @AppStorage("overdrachtMedicatie") private var medicatie = true
    @State private var opties = OverdrachtOpties()
    @State private var pdf: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Een overzicht op papier of als PDF voor wie het even overneemt: een broer of zus, de buurvrouw of de casemanager.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Wat komt erin") {
                    Toggle("Gegevens, huisarts en verzekering", isOn: $opties.profiel)
                    Toggle("Medicatie", isOn: $medicatie)
                    Toggle("Contactpersonen", isOn: $opties.contacten)
                    Toggle("Familie en wie wat doet", isOn: $opties.familie)
                    Toggle("Lopende zaken", isOn: $opties.zaken)
                    Toggle("Afspraken en deadlines (3 maanden)", isOn: $opties.herinneringen)
                    Toggle("Open taken", isOn: $opties.taken)
                    Toggle("Lijst van documenten", isOn: $opties.documenten)
                }

                Section {
                    Button {
                        opties.medicatie = medicatie
                        pdf = Exports.overdracht(naaste, opties: opties)
                    } label: {
                        Label("Maak overzicht", systemImage: "doc.richtext")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } footer: {
                    Text("Het overzicht wordt op je iPhone gemaakt. Jij kiest met wie je het deelt.")
                }
            }
            .navigationTitle("Overdrachtsoverzicht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluit") { dismiss() }
                }
            }
            .sheet(isPresented: Binding(get: { pdf != nil }, set: { if !$0 { pdf = nil } })) {
                if let pdf {
                    PDFVoorbeeldView(
                        titel: String(localized: "Overdracht \(naaste.weergaveNaam)"),
                        data: pdf,
                        bestandsnaam: DocumentNamen.bestandsnaam(voorTitel: String(localized: "Overdracht \(naaste.weergaveNaam) \(Date.now.formatted(.dateTime.day().month(.twoDigits).year()))"))
                    )
                }
            }
        }
    }
}
