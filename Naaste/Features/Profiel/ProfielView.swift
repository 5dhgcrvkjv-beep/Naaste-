import CoreData
import NaasteKit
import SwiftUI

struct ProfielView: View {
    @ObservedObject var naaste: Naaste
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @FetchRequest private var contacten: FetchedResults<Contactpersoon>

    @State private var bewerken = false
    @State private var nieuwContact = false
    @State private var contactBewerken: Contactpersoon?

    init(naaste: Naaste) {
        self.naaste = naaste
        _contacten = FetchRequest(fetchRequest: Contactpersoon.alle(voor: naaste))
    }

    var body: some View {
        List {
            Section("Persoonlijk") {
                Veld(label: "Naam", waarde: naaste.weergaveNaam)
                if let geboortedatum = naaste.geboortedatum {
                    Veld(label: "Geboortedatum", waarde: geboortedatum.formatted(date: .long, time: .omitted))
                }
                if let adres = naaste.adresRegel {
                    Veld(label: "Adres", waarde: adres, url: kaartURL(adres), actieSymbool: "map", actieLabel: String(localized: "Open in Kaarten"))
                }
                if let telefoon = naaste.telefoon?.nietLeeg {
                    Veld(label: "Telefoon", waarde: telefoon, url: ContactLinks.belURL(telefoon), actieSymbool: "phone.fill", actieLabel: String(localized: "Bel \(naaste.weergaveNaam)"))
                }
            }

            Section("Huisarts") {
                if naaste.huisartsNaam?.nietLeeg == nil && naaste.huisartsTelefoon?.nietLeeg == nil {
                    LegeRij(tekst: "Nog niet ingevuld.")
                }
                if let naam = naaste.huisartsNaam?.nietLeeg {
                    Veld(label: "Praktijk", waarde: naam)
                }
                if let telefoon = naaste.huisartsTelefoon?.nietLeeg {
                    Veld(label: "Telefoon", waarde: telefoon, url: ContactLinks.belURL(telefoon), actieSymbool: "phone.fill", actieLabel: String(localized: "Bel de huisarts"))
                }
            }

            Section("Zorgverzekering") {
                if naaste.zorgverzekeraar?.nietLeeg == nil && naaste.polisnummer?.nietLeeg == nil {
                    LegeRij(tekst: "Nog niet ingevuld.")
                }
                if let verzekeraar = naaste.zorgverzekeraar?.nietLeeg {
                    Veld(label: "Verzekeraar", waarde: verzekeraar)
                }
                if let polis = naaste.polisnummer?.nietLeeg {
                    Veld(label: "Polisnummer", waarde: polis, kopieerbaar: true)
                }
                if let telefoon = naaste.verzekeraarTelefoon?.nietLeeg {
                    Veld(label: "Telefoon", waarde: telefoon, url: ContactLinks.belURL(telefoon), actieSymbool: "phone.fill", actieLabel: String(localized: "Bel de zorgverzekeraar"))
                }
            }

            Section {
                ForEach(contacten.sorted(by: Contactpersoon.sorteer)) { contact in
                    ContactRij(contact: contact) {
                        contactBewerken = contact
                    }
                }
                .onDelete(perform: verwijderContacten)

                Button {
                    nieuwContact = true
                } label: {
                    Label("Contactpersoon toevoegen", systemImage: "plus.circle")
                }
            } header: {
                Text("Contactpersonen")
            } footer: {
                Text("Bijvoorbeeld thuiszorg, wijkverpleging, casemanager, het Wmo-loket van de gemeente, de notaris of de bank.")
            }

            if let medicatie = naaste.medicatieNotitie?.nietLeeg {
                Section {
                    Text(medicatie)
                        .textSelection(.enabled)
                } header: {
                    Text("Medicatie (notitie)")
                } footer: {
                    Text("Alleen een notitie voor de familie. Naaste geeft geen medisch advies.")
                }
            }

            if let notities = naaste.notities?.nietLeeg {
                Section("Notities") {
                    Text(notities)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Profiel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Wijzig") { bewerken = true }
            }
        }
        .sheet(isPresented: $bewerken) {
            NaasteBewerkenView(modus: .bewerk(naaste), naVerwijderen: { dismiss() })
        }
        .sheet(isPresented: $nieuwContact) {
            ContactBewerkenView(naaste: naaste, contact: nil)
        }
        .sheet(item: $contactBewerken) { contact in
            ContactBewerkenView(naaste: naaste, contact: contact)
        }
    }

    private func verwijderContacten(_ offsets: IndexSet) {
        let gesorteerd = contacten.sorted(by: Contactpersoon.sorteer)
        for index in offsets {
            app.context.delete(gesorteerd[index])
        }
        app.bewaar()
    }

    private func kaartURL(_ adres: String) -> URL? {
        var componenten = URLComponents(string: "https://maps.apple.com/")
        componenten?.queryItems = [URLQueryItem(name: "address", value: adres)]
        return componenten?.url
    }
}

/// Label + waarde, met optioneel een actieknop (bellen, kaart) of kopiëren.
private struct Veld: View {
    let label: LocalizedStringKey
    let waarde: String
    var url: URL? = nil
    var actieSymbool: String = "phone.fill"
    var actieLabel: String = ""
    var kopieerbaar = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(waarde)
                    .textSelection(.enabled)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            if let url {
                RondeActie(symbool: actieSymbool, label: actieLabel, url: url)
            }
            if kopieerbaar {
                Button {
                    UIPasteboard.general.string = waarde
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Kopieer \(Text(label))"))
            }
        }
    }
}

struct ContactRij: View {
    @ObservedObject var contact: Contactpersoon
    let bewerk: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: bewerk) {
                HStack(spacing: 12) {
                    Image(systemName: contact.rolWaarde.symbool)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.weergaveNaam)
                            .foregroundStyle(.primary)
                        Text(contact.ondertitel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let notitie = contact.notitie?.nietLeeg {
                            Text(notitie)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Tik om te wijzigen.")

            if let mail = ContactLinks.mailURL(contact.email) {
                RondeActie(symbool: "envelope.fill", label: String(localized: "Mail \(contact.weergaveNaam)"), url: mail)
            }
            if let bel = ContactLinks.belURL(contact.telefoon) {
                RondeActie(symbool: "phone.fill", label: String(localized: "Bel \(contact.weergaveNaam)"), url: bel)
            }
        }
        .padding(.vertical, 2)
    }
}
