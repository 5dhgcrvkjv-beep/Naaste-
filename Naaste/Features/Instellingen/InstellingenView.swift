import CoreData
import NaasteKit
import StoreKit
import SwiftUI

struct InstellingenView: View {
    @Environment(AppModel.self) private var app
    @FetchRequest(fetchRequest: Naaste.alle()) private var naasten: FetchedResults<Naaste>
    @State private var beheerAbonnement = false
    @State private var herstellen = false
    @State private var melding: String?
    @State private var bevestigWissen = false
    @State private var bevestigWissenNogmaals = false
    @State private var wissen = false

    var body: some View {
        NavigationStack {
            List {
                abonnementSectie

                Section {
                    NavigationLink {
                        MetGeselecteerdeNaaste { naaste in
                            FamilieView(naaste: naaste)
                        }
                    } label: {
                        Label("Familieleden", systemImage: "person.3")
                    }
                    NavigationLink {
                        MetGeselecteerdeNaaste { naaste in
                            DelenView(naaste: naaste)
                        }
                    } label: {
                        Label("Delen met familie", systemImage: "person.2.badge.plus")
                    }
                } header: {
                    Text("Familie")
                } footer: {
                    Text("Familieleden zijn naamkaartjes voor taken en uren; daarvoor is geen account nodig. Wil je echt samenwerken, deel dan de zorgmap: iedereen ziet dan dezelfde gegevens op de eigen iPhone.")
                }

                BeveiligingSectie()

                Section {
                    if naasten.contains(where: \.isVoorbeeld) {
                        Button("Voorbeeld-naaste verwijderen", role: .destructive) {
                            app.verwijderVoorbeeld()
                        }
                    } else {
                        Button("Voorbeeld-naaste tonen") {
                            app.laadVoorbeeld()
                        }
                    }
                } header: {
                    Text("Voorbeeld")
                } footer: {
                    Text("Een voorbeeld met verzonnen gegevens om alle functies te bekijken. Telt niet mee voor de gratis limieten.")
                }

                Section {
                    Link(destination: AppLinks.privacybeleid) {
                        Label("Privacybeleid", systemImage: "hand.raised")
                    }
                    Link(destination: AppLinks.gebruiksvoorwaarden) {
                        Label("Gebruiksvoorwaarden", systemImage: "doc.plaintext")
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Je gegevens staan alleen op je iPhone en in je eigen iCloud, en bij familieleden met wie je deelt. Naaste heeft geen eigen server, verzamelt geen gegevens en gebruikt geen tracking.")
                }

                ReservekopieSectie()

                Section {
                    Button(role: .destructive) {
                        bevestigWissen = true
                    } label: {
                        HStack {
                            Label("Alle gegevens wissen", systemImage: "trash")
                            if wissen {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(wissen)
                } header: {
                    Text("Gegevens")
                } footer: {
                    Text("Verwijdert al je naasten met documenten, zaken, taken en uren van deze iPhone en uit je iCloud. Zorgmappen die je deelt, verdwijnen ook bij je familie. Zorgmappen van anderen verlaat je; die blijven bij hen bewaard. Je abonnement loopt via Apple en blijft bestaan.")
                }

                Section("Over Naaste") {
                    LabeledContent("Versie", value: Self.versie)
                    Link(destination: AppLinks.ondersteuning) {
                        Label("Hulp en contact", systemImage: "questionmark.circle")
                    }
                }
            }
            .navigationTitle("Instellingen")
            .manageSubscriptionsSheet(isPresented: $beheerAbonnement)
            .confirmationDialog("Alle gegevens wissen?", isPresented: $bevestigWissen, titleVisibility: .visible) {
                Button("Ga verder", role: .destructive) { bevestigWissenNogmaals = true }
            } message: {
                Text("Dit kan niet ongedaan worden gemaakt.")
            }
            .alert("Weet je het zeker?", isPresented: $bevestigWissenNogmaals) {
                Button("Annuleer", role: .cancel) {}
                Button("Wis alles", role: .destructive) {
                    Task {
                        wissen = true
                        let gelukt = await app.wisAlleGegevens()
                        wissen = false
                        melding = gelukt
                            ? String(localized: "Al je gegevens zijn gewist.")
                            : String(localized: "Niet alles kon worden gewist, bijvoorbeeld omdat er geen internet was. Probeer het opnieuw als je verbinding hebt.")
                    }
                }
            } message: {
                Text("Al je naasten, documenten, zaken, taken en uren worden verwijderd, ook uit iCloud en bij familie met wie je deelt.")
            }
            .alert("Naaste", isPresented: Binding(get: { melding != nil }, set: { if !$0 { melding = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(melding ?? "")
            }
        }
    }

    private var abonnementSectie: some View {
        Section {
            switch app.entitlements.status {
            case .gratis:
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gratis versie")
                        .font(.headline)
                    Text("1 naaste, \(LimitPolicy.gratisMaxDocumenten) documenten, delen met 1 persoon en het overdrachtsoverzicht.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                Button {
                    app.paywall = .handmatig
                } label: {
                    Label("Bekijk Naaste Plus", systemImage: "sparkles")
                }
            case let .plus(_, verlooptOp, viaGezin):
                VStack(alignment: .leading, spacing: 4) {
                    Text("Naaste Plus is actief")
                        .font(.headline)
                    if viaGezin {
                        Text("Via Gezinsdeling.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let verlooptOp {
                        Text("Loopt tot \(verlooptOp.formatted(date: .long, time: .omitted)) en wordt automatisch verlengd, tenzij je opzegt.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }

            Button {
                beheerAbonnement = true
            } label: {
                Label("Abonnement beheren of opzeggen", systemImage: "creditcard")
            }

            Button {
                Task { await herstel() }
            } label: {
                HStack {
                    Label("Aankopen herstellen", systemImage: "arrow.clockwise")
                    if herstellen {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(herstellen)
        } header: {
            Text("Abonnement")
        }
    }

    private func herstel() async {
        herstellen = true
        defer { herstellen = false }
        do {
            try await app.entitlements.herstel()
            melding = app.isPlus
                ? String(localized: "Je abonnement is hersteld. Naaste Plus is actief.")
                : String(localized: "Er is geen actief abonnement gevonden voor deze Apple ID.")
        } catch {
            melding = String(localized: "Herstellen is niet gelukt. Controleer je internetverbinding en probeer het opnieuw.")
        }
    }

    private static var versie: String {
        let info = Bundle.main.infoDictionary
        let versie = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(versie) (\(build))"
    }
}

/// Vergrendelen met Face ID, Touch ID of toegangscode.
private struct BeveiligingSectie: View {
    @Environment(AppModel.self) private var app
    @State private var vergrendeling = Vergrendeling.shared

    var body: some View {
        let methode = vergrendeling.methode
        Section {
            Toggle(isOn: Binding(
                get: { vergrendeling.aan },
                set: { nieuw in
                    Task {
                        await vergrendeling.zet(aan: nieuw)
                        app.werkSpotlightBij()
                    }
                }
            )) {
                Label("Vergrendel met \(vergrendeling.methodeNaam)", systemImage: vergrendeling.methodeSymbool)
            }
            .disabled(methode == .geen || vergrendeling.bezig)
        } header: {
            Text("Beveiliging")
        } footer: {
            if methode == .geen {
                Text("Stel eerst een toegangscode in op je iPhone (Instellingen → Face ID en toegangscode).")
            } else {
                Text("Naaste vraagt om \(vergrendeling.methodeNaam) als je de app opent. In de app-kiezer is de inhoud verborgen en je gegevens verschijnen niet in Spotlight.")
            }
        }
    }
}

/// Reservekopie maken en terugzetten via Bestanden.
private struct ReservekopieSectie: View {
    @Environment(AppModel.self) private var app
    @State private var maken = false
    @State private var bestand: ReservekopieBestand?
    @State private var exporteren = false
    @State private var importeren = false
    /// Gekozen kopie die nog een wachtwoord nodig heeft.
    @State private var teOntsleutelen: Data?
    @State private var wachtwoord = ""
    @State private var melding: String?

    var body: some View {
        Section {
            Button {
                maken = true
            } label: {
                Label("Reservekopie maken", systemImage: "square.and.arrow.up")
            }
            Button {
                importeren = true
            } label: {
                Label("Reservekopie terugzetten", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Reservekopie")
        } footer: {
            Text(PersistenceController.zonderICloud
                ? "Deze testversie bewaart alles alleen op deze iPhone. Maak af en toe een reservekopie in Bestanden, dan raak je niets kwijt als je de app verwijdert."
                : "Een kopie van je eigen naasten met documenten, zaken, taken en uren, als één bestand in Bestanden. Terugzetten voegt alleen toe wat ontbreekt.")
        }
        .sheet(isPresented: $maken, onDismiss: {
            // De bewaarplek pas kiezen als het formulier weg is.
            if bestand != nil { exporteren = true }
        }) {
            ReservekopieMakenView { wachtwoord in
                if let kopie = app.maakReservekopie(wachtwoord: wachtwoord) {
                    bestand = ReservekopieBestand(data: kopie.data)
                }
            }
        }
        .fileExporter(
            isPresented: $exporteren,
            document: bestand,
            contentType: .naasteReservekopie,
            defaultFilename: Reservekopie.bestandsnaam()
        ) { resultaat in
            bestand = nil
            if case .success = resultaat {
                melding = String(localized: "De reservekopie is bewaard.")
            }
        }
        .fileImporter(isPresented: $importeren, allowedContentTypes: [.naasteReservekopie, .data]) { resultaat in
            guard case let .success(url) = resultaat else { return }
            lees(url)
        }
        .alert("Wachtwoord", isPresented: Binding(get: { teOntsleutelen != nil }, set: { if !$0 { teOntsleutelen = nil } })) {
            SecureField("Wachtwoord", text: $wachtwoord)
            Button("Annuleer", role: .cancel) { wachtwoord = "" }
            Button("Zet terug") {
                if let data = teOntsleutelen { zetTerug(data, wachtwoord: wachtwoord) }
                wachtwoord = ""
            }
        } message: {
            Text("Deze reservekopie is beveiligd. Vul het wachtwoord in dat je bij het maken koos.")
        }
        .alert("Reservekopie", isPresented: Binding(get: { melding != nil }, set: { if !$0 { melding = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(melding ?? "")
        }
    }

    private func lees(_ url: URL) {
        let toegang = url.startAccessingSecurityScopedResource()
        defer { if toegang { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            melding = String(localized: "Het bestand kon niet worden gelezen.")
            return
        }
        if Reservekopie.isVersleuteld(data) {
            teOntsleutelen = data
        } else {
            zetTerug(data, wachtwoord: nil)
        }
    }

    private func zetTerug(_ data: Data, wachtwoord: String?) {
        do {
            let s = try app.zetReservekopieTerug(data, wachtwoord: wachtwoord)
            if s.naasten + s.documenten + s.overig == 0 {
                melding = String(localized: "Alles uit deze reservekopie stond al op deze iPhone. Er is niets veranderd.")
            } else {
                let naasten = s.naasten == 1 ? String(localized: "1 naaste") : String(localized: "\(s.naasten) naasten")
                let documenten = s.documenten == 1 ? String(localized: "1 document") : String(localized: "\(s.documenten) documenten")
                melding = String(localized: "Teruggezet: \(naasten) en \(documenten), met hun zaken, taken en uren.")
            }
        } catch let fout as Reservekopie.Fout {
            melding = fout.localizedDescription
        } catch {
            melding = String(localized: "De reservekopie kon niet worden teruggezet. Probeer het opnieuw.")
        }
    }
}

/// Wachtwoord kiezen voor een nieuwe reservekopie.
private struct ReservekopieMakenView: View {
    let maak: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var wachtwoord = ""
    @State private var herhaling = ""
    @State private var bezig = false

    static let minimaleLengte = 8

    private var zonderWachtwoord: Bool { wachtwoord.isEmpty && herhaling.isEmpty }
    private var geldig: Bool {
        zonderWachtwoord || (wachtwoord.count >= Self.minimaleLengte && wachtwoord == herhaling)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Wachtwoord", text: $wachtwoord)
                        .textContentType(.newPassword)
                    SecureField("Herhaal wachtwoord", text: $herhaling)
                        .textContentType(.newPassword)
                } footer: {
                    if zonderWachtwoord {
                        Label("Zonder wachtwoord kan iedereen die het bestand krijgt je documenten lezen.", systemImage: "exclamationmark.triangle")
                    } else if wachtwoord.count < Self.minimaleLengte {
                        Text("Minstens \(Self.minimaleLengte) tekens.")
                    } else if !herhaling.isEmpty && wachtwoord != herhaling {
                        Text("De wachtwoorden zijn niet hetzelfde.")
                    } else {
                        Text("Bewaar het wachtwoord goed, bijvoorbeeld in de app Wachtwoorden. Ben je het kwijt, dan kan niemand de kopie meer openen, ook Naaste niet.")
                    }
                }
                Section {
                    Text("De kopie bevat je eigen naasten met documenten, zaken, taken en uren. Na het maken kies je waar je hem bewaart, bijvoorbeeld in iCloud Drive of op een USB-stick.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Reservekopie maken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if bezig {
                        ProgressView()
                    } else {
                        Button(zonderWachtwoord ? "Maak zonder wachtwoord" : "Maak") {
                            bezig = true
                            // Even wachten zodat de voortgang zichtbaar is; het versleutelen duurt kort.
                            Task {
                                try? await Task.sleep(for: .milliseconds(50))
                                maak(zonderWachtwoord ? nil : wachtwoord)
                                dismiss()
                            }
                        }
                        .disabled(!geldig)
                    }
                }
            }
        }
    }
}
