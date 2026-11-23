import CoreData
import NaasteKit
import SwiftUI

struct ContactBewerkenView: View {
    let naaste: Naaste
    let contact: Contactpersoon?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var rol: ContactRol = .thuiszorg
    @State private var naam = ""
    @State private var organisatie = ""
    @State private var telefoon = ""
    @State private var email = ""
    @State private var notitie = ""
    @State private var geladen = false
    @State private var bevestigVerwijderen = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Rol", selection: $rol) {
                        ForEach(ContactRol.allCases) { rol in
                            Label(rol.titel, systemImage: rol.symbool).tag(rol)
                        }
                    }
                    TextField("Naam", text: $naam)
                        .textContentType(.name)
                    TextField("Organisatie", text: $organisatie)
                        .textContentType(.organizationName)
                }

                Section {
                    TextField("Telefoon", text: $telefoon)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    TextField("E-mail", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    if !email.isEmpty && ContactLinks.mailURL(email) == nil {
                        Text("Dit e-mailadres lijkt niet volledig.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Notitie") {
                    TextField("Bijvoorbeeld bereikbaar op werkdagen 9–12 uur", text: $notitie, axis: .vertical)
                        .lineLimit(2...6)
                }

                if contact != nil {
                    Section {
                        Button("Contactpersoon verwijderen", role: .destructive) {
                            bevestigVerwijderen = true
                        }
                    }
                }
            }
            .navigationTitle(contact == nil ? "Nieuwe contactpersoon" : "Wijzig contactpersoon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar", action: bewaar)
                        .disabled(naam.nietLeeg == nil && organisatie.nietLeeg == nil)
                }
            }
            .confirmationDialog("Contactpersoon verwijderen?", isPresented: $bevestigVerwijderen, titleVisibility: .visible) {
                Button("Verwijder", role: .destructive) {
                    if let contact {
                        app.context.delete(contact)
                        if app.bewaar() { dismiss() }
                    }
                }
                Button("Annuleer", role: .cancel) {}
            }
            .onAppear(perform: laad)
        }
    }

    private func laad() {
        guard !geladen else { return }
        geladen = true
        guard let contact else { return }
        rol = contact.rolWaarde
        naam = contact.naam ?? ""
        organisatie = contact.organisatie ?? ""
        telefoon = contact.telefoon ?? ""
        email = contact.email ?? ""
        notitie = contact.notitie ?? ""
    }

    private func bewaar() {
        let doel = contact ?? app.context.maak(Contactpersoon.self, bij: naaste)
        doel.naaste = naaste
        doel.rolWaarde = rol
        doel.naam = naam.nietLeeg
        doel.organisatie = organisatie.nietLeeg
        doel.telefoon = telefoon.nietLeeg
        doel.email = email.nietLeeg
        doel.notitie = notitie.nietLeeg
        doel.gewijzigd = Date()
        if app.bewaar() { dismiss() }
    }
}
